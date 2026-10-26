//
//  ProjectStore.swift
//  CENTRO
//
//  Núcleo de datos: escanea carpetas raíz y/o proyectos individuales,
//  detecta stack/git y persiste metadata (favoritos, categorías, nombres, notas).
//

import SwiftUI
import Observation

@Observable
final class ProjectStore {

    // Estado observable
    var projects: [Project] = []
    var folders: [VirtualFolder] = []          // categorías
    var rootPath: String? { didSet { persistConfig() } }   // carpeta contenedora (escanea subcarpetas)
    var manualProjectPaths: [String] = []      // proyectos individuales (1 carpeta = 1 proyecto)
    var isScanning = false
    var searchText = ""

    // Tareas / Inbox / Tiempo
    var todos: [TodoItem] = []
    var inboxItems: [InboxItem] = []
    var timeSessions: [TimeSession] = []
    var activeSession: TimeSession? { timeSessions.first { $0.isActive } }
    var tick: Int = 0     // se incrementa cada segundo mientras hay timer activo (refresca vistas)
    @ObservationIgnored private var ticker: Timer?

    // Destinos recientes de drag & drop (rutas de carpetas)
    var recentDropDestinations: [String] = []

    // Acciones personalizadas (globales, corren en la carpeta del proyecto)
    var customActions: [CustomAction] = []

    // Dev servers corriendo dentro de la app
    let devServers = DevServerManager()

    // Navegación (cambiar de módulo o abrir un proyecto limpia el buscador)
    var nav: NavItem = .home { didSet { clearSearch() } }
    var selectedProjectID: Project.ID? = nil { didSet { if selectedProjectID != nil { clearSearch() } } }

    private func clearSearch() { if !searchText.isEmpty { searchText = "" } }

    // Persistencia
    private var metadata: [String: ProjectMetadata] = [:]
    private var excludedPaths: Set<String> = []
    private let support: URL
    /// Archivos que existían pero no se pudieron leer: NUNCA se sobrescriben,
    /// para no pisar los datos del usuario con una lista vacía.
    @ObservationIgnored private var unreadable: Set<URL> = []

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CENTRO", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        support = base
        backupDataFiles()
        loadConfig()
        if activeSession != nil { startTicker() }
        if rootPath != nil || !manualProjectPaths.isEmpty {
            nav = .all
            Task { await scan() }
        }
    }

    // MARK: - Derivados

    var hasSource: Bool { rootPath != nil || !manualProjectPaths.isEmpty }
    var hiddenCount: Int { projects.filter { $0.isHidden }.count }
    var excludedCount: Int { excludedPaths.count }
    var favorites: [Project] { projects.filter { $0.isFavorite } }

    /// Lista de proyectos para una sección de navegación (sin búsqueda).
    func projects(for nav: NavItem) -> [Project] {
        let base = projects.filter { !$0.isHidden }
        switch nav {
        case .all:           return base.filter { $0.exists }
        case .favorites:     return base.filter { $0.isFavorite && $0.exists }
        case .recents:       return base.filter { $0.lastOpenedAt != nil }
                                  .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
        case .missing:       return base.filter { !$0.exists }
        case .uncategorized: return base.filter { $0.folderID == nil && $0.exists }
        case .category(let id): return base.filter { $0.folderID == id }
        case .github:        return []
        default:             return base.filter { $0.exists }
        }
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Proyectos de la sección actual + filtro de búsqueda, ordenados.
    /// Cuando hay búsqueda activa, busca en TODOS los proyectos (no solo la sección).
    var visibleProjects: [Project] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        var list = q.isEmpty ? projects(for: nav) : projects.filter { !$0.isHidden && $0.exists }
        if !q.isEmpty {
            list = list.filter {
                $0.displayName.lowercased().contains(q)
                || $0.path.lowercased().contains(q)
                || $0.detectedStack.contains { $0.label.lowercased().contains(q) }
            }
        }
        if case .recents = nav { return list }   // ya ordenado por fecha de apertura
        return list.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
            return $0.modifiedAt > $1.modifiedAt
        }
    }

    /// Búsqueda global (para el Command Palette): todos los proyectos existentes.
    func searchProjects(_ query: String) -> [Project] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let base = projects.filter { !$0.isHidden && $0.exists }
        if q.isEmpty { return base.sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) } }
        return base.filter {
            $0.displayName.lowercased().contains(q)
            || $0.path.lowercased().contains(q)
            || $0.detectedStack.contains { $0.label.lowercased().contains(q) }
        }
    }

    func count(for nav: NavItem) -> Int { projects(for: nav).count }

    // MARK: - Agregar proyectos

    /// Opción 1: elegir una carpeta contenedora; cada subcarpeta es un proyecto.
    /// Si se está dentro de una categoría, todas las subcarpetas se agregan a esa categoría.
    @MainActor
    func addProjectsFolder(categoryID: UUID? = nil) {
        guard let path = SystemActions.pickFolder(prompt: String(localized: "Elegí la carpeta que contiene tus proyectos")) else { return }
        let subs = Self.subfolders(of: path)
        guard !subs.isEmpty else { return }

        if let categoryID {
            // Agregar cada subcarpeta como proyecto asignado a la categoría.
            for sub in subs {
                if !manualProjectPaths.contains(sub) { manualProjectPaths.append(sub) }
                excludedPaths.remove(sub)
                var m = metadata[sub] ?? ProjectMetadata()
                m.folderID = categoryID
                metadata[sub] = m
            }
            persistMetadata()
            persistConfig()
            nav = .category(categoryID)
        } else {
            // Biblioteca general: carpeta raíz observada (autodescubre nuevas subcarpetas).
            rootPath = path
            nav = .all
        }
        Task { await scan() }
    }

    private static func subfolders(of path: String) -> [String] {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles])) ?? []
        return urls.compactMap { url in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            return isDir ? url.path : nil
        }
    }

    /// Opción 2: elegir una sola carpeta = un proyecto. Devuelve la ruta elegida (para pedir nombre).
    @MainActor
    func pickSingleProjectFolder() -> String? {
        SystemActions.pickFolder(prompt: String(localized: "Elegí la carpeta del proyecto"))
    }

    /// Agrega un proyecto individual con nombre y, opcionalmente, una categoría.
    /// Si se pasa categoría, queda asignado y la navegación permanece en esa categoría.
    func addSingleProject(path: String, name: String, categoryID: UUID? = nil) {
        if !manualProjectPaths.contains(path) { manualProjectPaths.append(path) }
        excludedPaths.remove(path)
        let folderName = (path as NSString).lastPathComponent
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        var m = metadata[path] ?? ProjectMetadata()
        m.customName = (trimmed.isEmpty || trimmed == folderName) ? nil : trimmed
        if let categoryID { m.folderID = categoryID }
        metadata[path] = m
        persistMetadata()
        persistConfig()
        nav = categoryID != nil ? .category(categoryID!) : .all
        Task { await scan() }
    }

    /// Categoría actualmente seleccionada (si la navegación está en una).
    var currentCategoryID: UUID? {
        if case .category(let id) = nav { return id }
        return nil
    }

    /// Crea físicamente una carpeta nueva y la agrega como proyecto.
    /// Devuelve nil si todo ok, o un mensaje de error.
    @discardableResult
    func createNewProject(name: String, parentPath: String, categoryID: UUID?) -> String? {
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return String(localized: "Poné un nombre.") }
        guard !parentPath.isEmpty else { return String(localized: "Elegí una ubicación.") }
        let path = (parentPath as NSString).appendingPathComponent(clean)
        let fm = FileManager.default
        if fm.fileExists(atPath: path) { return String(localized: "Ya existe una carpeta «\(clean)» en esa ubicación.") }
        do {
            try fm.createDirectory(atPath: path, withIntermediateDirectories: false)
        } catch {
            return String(localized: "No se pudo crear la carpeta: \(error.localizedDescription)")
        }
        addSingleProject(path: path, name: clean, categoryID: categoryID)
        SystemActions.revealInFinder(path)
        return nil
    }

    // MARK: - Escaneo

    func scan() async {
        guard hasSource else { return }
        await MainActor.run { isScanning = true }
        let root = rootPath
        let manual = manualProjectPaths
        let excluded = excludedPaths

        let found: [Project] = await Task.detached(priority: .userInitiated) {
            Self.buildProjects(root: root, manual: manual, excluded: excluded)
        }.value

        await MainActor.run {
            projects = found.map(applyMetadata)
            isScanning = false
        }
    }

    /// Construye la lista de proyectos a partir de la raíz + individuales. (fuera del actor)
    private nonisolated static func buildProjects(root: String?, manual: [String], excluded: Set<String>) -> [Project] {
        let fm = FileManager.default
        var result: [Project] = []
        var seen = Set<String>()

        func make(path: String, isManual: Bool) -> Project? {
            guard !excluded.contains(path), !seen.contains(path) else { return nil }
            seen.insert(path)
            var isDir: ObjCBool = false
            let exists = fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
            let modDate = (try? fm.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? nil
            func has(_ rel: String) -> Bool { fm.fileExists(atPath: (path as NSString).appendingPathComponent(rel)) }
            let needsInstall = exists && has("package.json") && !has("node_modules")
            let missingEnv = exists && (has(".env.example") || has(".env.sample")) && !has(".env")
            return Project(
                name: (path as NSString).lastPathComponent,
                path: path,
                isManual: isManual,
                detectedStack: exists ? StackDetector.detect(at: path) : [],
                git: exists ? GitInspector.inspect(at: path) : GitInfo(),
                modifiedAt: modDate ?? .distantPast,
                exists: exists,
                isPinned: false,
                iconPath: exists ? StackDetector.findIcon(at: path) : nil,
                needsInstall: needsInstall,
                missingEnv: missingEnv
            )
        }

        // Carpeta contenedora → subcarpetas
        if let root,
           let contents = try? fm.contentsOfDirectory(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]) {
            for url in contents {
                let vals = try? url.resourceValues(forKeys: [.isDirectoryKey])
                guard vals?.isDirectory == true else { continue }
                if let p = make(path: url.path, isManual: false) { result.append(p) }
            }
        }

        // Proyectos individuales (se listan aunque falten, para "Perdidos")
        for path in manual {
            if let p = make(path: path, isManual: true) { result.append(p) }
        }

        return result
    }

    private func applyMetadata(_ p: Project) -> Project {
        var p = p
        if let m = metadata[p.path] {
            p.isFavorite = m.isFavorite
            p.status = ProjectStatus(rawValue: m.status) ?? .active
            p.folderID = m.folderID
            p.notes = m.notes
            p.lastOpenedAt = m.lastOpenedAt
            p.isHidden = m.isHidden
            p.customName = m.customName
            p.isPinned = m.isPinned
        }
        return p
    }

    // MARK: - Mutaciones

    private func mutate(_ id: Project.ID, _ change: (inout Project) -> Void) {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.snappy) { change(&projects[idx]) }
        let p = projects[idx]
        metadata[p.path] = ProjectMetadata(
            isFavorite: p.isFavorite, status: p.status.rawValue,
            folderID: p.folderID, notes: p.notes, lastOpenedAt: p.lastOpenedAt,
            isHidden: p.isHidden, customName: p.customName, isPinned: p.isPinned
        )
        persistMetadata()
    }

    func toggleFavorite(_ id: Project.ID) { mutate(id) { $0.isFavorite.toggle() } }
    func togglePin(_ id: Project.ID) { mutate(id) { $0.isPinned.toggle() } }
    func setCategory(_ id: Project.ID, _ categoryID: UUID?) { mutate(id) { $0.folderID = categoryID } }
    func setNotes(_ id: Project.ID, _ notes: String) { mutate(id) { $0.notes = notes } }
    func markOpened(_ id: Project.ID) { mutate(id) { $0.lastOpenedAt = Date() } }

    func rename(_ id: Project.ID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        mutate(id) { p in p.customName = (trimmed.isEmpty || trimmed == p.name) ? nil : trimmed }
    }

    func hideProject(_ id: Project.ID) {
        if selectedProjectID == id { selectedProjectID = nil }
        mutate(id) { $0.isHidden = true }
    }

    func restoreAllHidden() {
        for p in projects where p.isHidden { mutate(p.id) { $0.isHidden = false } }
    }

    /// Quita por completo de la app (no toca archivos). También saca proyectos individuales.
    func removeProject(_ id: Project.ID) {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        let path = projects[idx].path
        if selectedProjectID == id { selectedProjectID = nil }
        excludedPaths.insert(path)
        manualProjectPaths.removeAll { $0 == path }
        metadata[path] = nil
        withAnimation(.snappy) { _ = projects.remove(at: idx) }
        persistMetadata()
        persistConfig()
    }

    func restoreExcluded() {
        excludedPaths.removeAll()
        persistConfig()
        Task { await scan() }
    }

    // MARK: - Acciones personalizadas

    func addCustomAction(_ a: CustomAction) {
        withAnimation(.snappy) { customActions.append(a) }
        persistConfig()
    }
    func removeCustomAction(_ id: UUID) {
        withAnimation(.snappy) { customActions.removeAll { $0.id == id } }
        persistConfig()
    }
    func runCustomAction(_ a: CustomAction, in path: String) {
        if a.runsInTerminal { SystemActions.runInTerminal(cwd: path, command: a.command) }
        else { SystemActions.runInBackground(cwd: path, command: a.command) }
    }

    // MARK: - Categorías

    func addCategory(name: String, symbol: String = "square.stack", colorHex: String = "#B14EFF", parentID: UUID? = nil) {
        withAnimation(.snappy) {
            folders.append(VirtualFolder(name: name, symbol: symbol, colorHex: colorHex,
                                         position: folders.count, parentID: parentID))
        }
        persistConfig()
    }

    /// Subcategorías directas de una categoría (ordenadas).
    func subcategories(of id: UUID) -> [VirtualFolder] {
        folders.filter { $0.parentID == id }.sorted { $0.position < $1.position }
    }
    /// Categorías de nivel superior.
    var topCategories: [VirtualFolder] {
        folders.filter { $0.parentID == nil }.sorted { $0.position < $1.position }
    }
    /// Todos los descendientes (recursivo) de una categoría, incluyéndola.
    func categoryAndDescendants(_ id: UUID) -> [UUID] {
        var result = [id]
        for sub in folders where sub.parentID == id {
            result.append(contentsOf: categoryAndDescendants(sub.id))
        }
        return result
    }
    func categoryName(_ id: UUID?) -> String? {
        guard let id else { return nil }
        return folders.first { $0.id == id }?.name
    }

    func updateCategory(_ id: UUID, name: String, colorHex: String, symbol: String? = nil) {
        guard let i = folders.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.snappy) {
            folders[i].name = name
            folders[i].colorHex = colorHex
            if let symbol { folders[i].symbol = symbol }
        }
        persistConfig()
    }

    func removeCategory(_ id: UUID) {
        let ids = Set(categoryAndDescendants(id))
        withAnimation(.snappy) {
            folders.removeAll { ids.contains($0.id) }
            for p in projects where p.folderID != nil && ids.contains(p.folderID!) { setCategory(p.id, nil) }
            if case .category(let sel) = nav, ids.contains(sel) { nav = .all }
        }
        persistConfig()
    }

    // MARK: - Tareas

    func addTodo(_ text: String, projectPath: String? = nil) {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        withAnimation(.snappy) { todos.insert(TodoItem(text: t, projectPath: projectPath), at: 0) }
        persistTodos()
    }
    func toggleTodo(_ id: UUID) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.snappy) { todos[i].done.toggle() }
        persistTodos()
    }
    func removeTodo(_ id: UUID) {
        withAnimation(.snappy) { todos.removeAll { $0.id == id } }
        persistTodos()
    }

    // MARK: - Inbox

    func addInbox(_ text: String, projectPath: String? = nil) {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        withAnimation(.snappy) { inboxItems.insert(InboxItem(text: t, projectPath: projectPath), at: 0) }
        persistInbox()
    }
    func removeInbox(_ id: UUID) {
        withAnimation(.snappy) { inboxItems.removeAll { $0.id == id } }
        persistInbox()
    }
    /// Convierte un item de inbox en tarea.
    func inboxToTodo(_ id: UUID) {
        guard let item = inboxItems.first(where: { $0.id == id }) else { return }
        addTodo(item.text, projectPath: item.projectPath)
        removeInbox(id)
    }

    // MARK: - Time tracking

    func startTimer(projectPath: String) {
        stopTimer()   // cierra cualquier sesión activa
        withAnimation(.snappy) { timeSessions.insert(TimeSession(projectPath: projectPath), at: 0) }
        persistTime()
        startTicker()
    }
    func stopTimer() {
        guard let i = timeSessions.firstIndex(where: { $0.isActive }) else { return }
        withAnimation(.snappy) { timeSessions[i].endedAt = Date() }
        persistTime()
        if activeSession == nil { stopTicker() }
    }

    private func startTicker() {
        guard ticker == nil else { return }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick &+= 1
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }
    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
    func totalSeconds(forProject path: String) -> Int {
        timeSessions.filter { $0.projectPath == path }.reduce(0) { $0 + $1.seconds }
    }
    func lastSessionDate(forProject path: String) -> Date {
        timeSessions.filter { $0.projectPath == path }
            .map { $0.endedAt ?? $0.startedAt }.max() ?? .distantPast
    }
    /// Segundos registrados por día en los últimos `days` días (incluye hoy).
    func secondsPerDay(lastDays days: Int) -> [(date: Date, seconds: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var buckets: [Date: Int] = [:]
        for d in 0..<days { buckets[cal.date(byAdding: .day, value: -d, to: today)!] = 0 }
        for s in timeSessions {
            let day = cal.startOfDay(for: s.startedAt)
            if buckets[day] != nil { buckets[day]! += s.seconds }
        }
        return buckets.keys.sorted().map { ($0, buckets[$0] ?? 0) }
    }
    func projectName(forPath path: String) -> String {
        projects.first { $0.path == path }?.displayName ?? (path as NSString).lastPathComponent
    }

    // MARK: - Drag & drop (copiar / mover archivos a una carpeta)

    /// Copia o mueve los archivos al destino. Devuelve nil si ok, o un mensaje de error.
    @discardableResult
    func dropFiles(_ urls: [URL], to destPath: String, move: Bool) -> String? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: destPath, isDirectory: &isDir), isDir.boolValue else {
            return String(localized: "La carpeta destino no existe.")
        }
        guard !urls.isEmpty else { return String(localized: "No se recibió ningún archivo.") }
        var failures: [String] = []
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let target = uniqueDestination(for: url.lastPathComponent, in: destPath)
            do {
                if move { try fm.moveItem(at: url, to: URL(fileURLWithPath: target)) }
                else    { try fm.copyItem(at: url, to: URL(fileURLWithPath: target)) }
            } catch {
                failures.append("\(url.lastPathComponent) (\(error.localizedDescription))")
            }
        }
        recordDropDestination(destPath)
        if !failures.isEmpty {
            let list = failures.joined(separator: ", ")
            return move ? String(localized: "No se pudieron mover: \(list)") : String(localized: "No se pudieron copiar: \(list)")
        }
        return nil
    }

    private func uniqueDestination(for name: String, in dir: String) -> String {
        let fm = FileManager.default
        var candidate = (dir as NSString).appendingPathComponent(name)
        guard fm.fileExists(atPath: candidate) else { return candidate }
        let ext = (name as NSString).pathExtension
        let base = (name as NSString).deletingPathExtension
        var i = 2
        repeat {
            let newName = ext.isEmpty ? "\(base) \(i)" : "\(base) \(i).\(ext)"
            candidate = (dir as NSString).appendingPathComponent(newName)
            i += 1
        } while fm.fileExists(atPath: candidate)
        return candidate
    }

    private func recordDropDestination(_ path: String) {
        recentDropDestinations.removeAll { $0 == path }
        recentDropDestinations.insert(path, at: 0)
        if recentDropDestinations.count > 12 { recentDropDestinations = Array(recentDropDestinations.prefix(12)) }
        persistConfig()
    }

    // MARK: - Persistencia

    private var metadataURL: URL { support.appendingPathComponent("metadata.json") }
    private var configURL: URL { support.appendingPathComponent("config.json") }
    private var todosURL: URL { support.appendingPathComponent("todos.json") }
    private var inboxURL: URL { support.appendingPathComponent("inbox.json") }
    private var timeURL: URL { support.appendingPathComponent("time.json") }

    private func persistTodos() { write(todos, to: todosURL) }
    private func persistInbox() { write(inboxItems, to: inboxURL) }
    private func persistTime() { write(timeSessions, to: timeURL) }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        guard !unreadable.contains(url) else { return }
        // .atomic: se escribe a un temporal y se reemplaza; un corte a mitad no deja el archivo roto.
        if let data = try? JSONEncoder().encode(value) { try? data.write(to: url, options: .atomic) }
    }

    /// Lee un JSON. Si el archivo existe pero no se puede decodificar, se guarda una
    /// copia aparte y se bloquea su escritura (los datos originales quedan intactos).
    private func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else {
            if FileManager.default.fileExists(atPath: url.path) { unreadable.insert(url) }
            return nil
        }
        if let v = try? JSONDecoder().decode(type, from: data) { return v }
        unreadable.insert(url)
        let copy = url.deletingPathExtension().appendingPathExtension("ilegible-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.copyItem(at: url, to: copy)
        return nil
    }

    /// Copia de seguridad de todos los datos en cada arranque (se guardan las últimas 30).
    private func backupDataFiles() {
        let fm = FileManager.default
        let dir = support.appendingPathComponent("respaldos", isDirectory: true)
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dest = dir.appendingPathComponent(f.string(from: Date()), isDirectory: true)
        let files = ["metadata.json", "config.json", "todos.json", "inbox.json", "time.json", "prefs.json"]
            .map { support.appendingPathComponent($0) }
            .filter { fm.fileExists(atPath: $0.path) }
        guard !files.isEmpty, (try? fm.createDirectory(at: dest, withIntermediateDirectories: true)) != nil else { return }
        for file in files { try? fm.copyItem(at: file, to: dest.appendingPathComponent(file.lastPathComponent)) }
        let old = ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).sorted()
        for name in old.dropLast(30) { try? fm.removeItem(at: dir.appendingPathComponent(name)) }
    }

    private struct Config: Codable {
        var rootPath: String?
        var folders: [VirtualFolder]
        var excludedPaths: [String]? = nil
        var manualProjectPaths: [String]? = nil
        var recentDropDestinations: [String]? = nil
        var customActions: [CustomAction]? = nil
    }

    private func persistMetadata() { write(metadata, to: metadataURL) }
    private func persistConfig() {
        let cfg = Config(rootPath: rootPath, folders: folders,
                         excludedPaths: Array(excludedPaths),
                         manualProjectPaths: manualProjectPaths,
                         recentDropDestinations: recentDropDestinations,
                         customActions: customActions)
        write(cfg, to: configURL)
    }
    private func loadConfig() {
        if let m = read([String: ProjectMetadata].self, from: metadataURL) {
            metadata = m
        }
        if let cfg = read(Config.self, from: configURL) {
            folders = cfg.folders
            excludedPaths = Set(cfg.excludedPaths ?? [])
            manualProjectPaths = cfg.manualProjectPaths ?? []
            recentDropDestinations = cfg.recentDropDestinations ?? []
            customActions = cfg.customActions ?? []
            rootPath = cfg.rootPath
        }
        if let v = read([TodoItem].self, from: todosURL) { todos = v }
        if let v = read([InboxItem].self, from: inboxURL) { inboxItems = v }
        if let v = read([TimeSession].self, from: timeURL) { timeSessions = v }
    }
}

// MARK: - Navegación de la barra lateral

enum NavItem: Hashable {
    case home
    case all
    case favorites
    case recents
    case activity
    case dailyDigest
    case timeTracking
    case tasks
    case inbox
    case depsOutdated
    case missing          // "Perdidos" (carpeta ya no existe)
    case uncategorized    // "Sin categoría"
    case github           // repos de GitHub
    case category(UUID)
    case settings

    /// Si la sección muestra la grilla de proyectos.
    var isGrid: Bool {
        switch self {
        case .all, .favorites, .recents, .missing, .uncategorized, .category: return true
        default: return false
        }
    }
}
