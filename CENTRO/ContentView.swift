//
//  ContentView.swift
//  CENTRO
//
//  Vista raíz: sidebar de ancho fijo + contenido ruteado por navegación.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: ProjectStore
    @State private var sidebarCollapsed = false

    // Alta de proyecto individual
    @State private var showNameDialog = false
    @State private var pendingPath: String = ""
    @State private var pendingName: String = ""
    @State private var pendingCategory: UUID? = nil
    @State private var showNewProject = false

    // Drag & drop
    @State private var isDropTargeted = false
    @State private var droppedFiles: [URL] = []
    @State private var showDropSheet = false

    // Subcategoría
    @State private var showNewSubcategory = false
    @State private var subcategoryParent: UUID? = nil

    // Command Palette
    @State private var showPalette = false

    var body: some View {
        ZStack {
            Theme.background
            HStack(spacing: 0) {
                SidebarView(store: store, collapsed: $sidebarCollapsed)
                    .frame(width: sidebarCollapsed ? 64 : 240)
                Divider().overlay(.white.opacity(0.06))
                VStack(spacing: 0) {
                    TopBar(store: store, onNew: { showNewProject = true },
                           onAddFolder: addFolder, onAddSingle: startAddSingle,
                           onNewSubcategory: startNewSubcategory)
                    content
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background {
            Button("") { showPalette.toggle() }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
        }
        .overlay {
            if showPalette {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                        .onTapGesture { showPalette = false }
                    CommandPalette(store: store, isPresented: $showPalette,
                                   onNewProject: { showPalette = false; showNewProject = true })
                        .padding(.top, 80)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .transition(.opacity)
                .zIndex(1000)
            }
        }
        .animation(.snappy, value: showPalette)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .overlay {
            if isDropTargeted { dropOverlay }
        }
        .sheet(isPresented: $showDropSheet) {
            DropSheet(store: store, files: droppedFiles)
        }
        .alert(nameDialogTitle, isPresented: $showNameDialog) {
            TextField("Nombre", text: $pendingName)
            Button("Guardar") {
                store.addSingleProject(path: pendingPath, name: pendingName, categoryID: pendingCategory)
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text(nameDialogMessage)
        }
        .sheet(isPresented: $showNewProject) {
            NewProjectSheet(store: store, presetCategory: store.currentCategoryID)
        }
        .sheet(isPresented: $showNewSubcategory) {
            CategoryEditorSheet(store: store, parentID: subcategoryParent)
        }
    }

    private func startNewSubcategory() {
        subcategoryParent = store.currentCategoryID
        showNewSubcategory = true
    }

    private var dropOverlay: some View {
        ZStack {
            Theme.lilac.opacity(0.12).ignoresSafeArea()
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Theme.lilac, style: StrokeStyle(lineWidth: 3, dash: [12, 8]))
                .padding(20)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(Theme.lilacGlow)
                    .shadow(color: Theme.lilac.opacity(0.8), radius: 24)
                Text("Soltá tus archivos acá")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                Text("Elegí después a qué proyecto copiarlos o moverlos.")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let lock = NSLock()
        let group = DispatchGroup()
        let fileType = UTType.fileURL.identifier
        for p in providers where p.hasItemConformingToTypeIdentifier(fileType) {
            group.enter()
            p.loadItem(forTypeIdentifier: fileType, options: nil) { item, _ in
                var url: URL?
                if let u = item as? URL { url = u }
                else if let d = item as? Data { url = URL(dataRepresentation: d, relativeTo: nil) }
                else if let s = item as? String { url = URL(string: s) }
                if let u = url, u.isFileURL { lock.lock(); urls.append(u); lock.unlock() }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            guard !urls.isEmpty else { return }
            droppedFiles = urls
            showDropSheet = true
        }
        return true
    }

    private var nameDialogTitle: String {
        if let id = pendingCategory, let cat = store.folders.first(where: { $0.id == id }) {
            return String(localized: "Agregar a «\(cat.name)»")
        }
        return String(localized: "Nombre del proyecto")
    }
    private var nameDialogMessage: String {
        String(localized: "Por defecto es el nombre de la carpeta. Podés cambiarlo antes de guardar.")
    }

    // MARK: Contenido ruteado

    @ViewBuilder
    private var content: some View {
        if !store.hasSource {
            WelcomeView(onNew: { showNewProject = true }, onAddFolder: addFolder, onAddSingle: startAddSingle)
                .transition(.opacity)
        } else if let id = store.selectedProjectID, !store.isSearching,
                  let project = store.projects.first(where: { $0.id == id }) {
            ProjectDetailView(project: project, store: store)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity))
                .id(id)
        } else if store.isSearching {
            ProjectGridView(store: store).transition(.opacity)   // resultados de búsqueda
        } else {
            section.transition(.opacity).id(navID)
        }
    }

    @ViewBuilder
    private var section: some View {
        switch store.nav {
        case .home:          HomeView(store: store)
        case .settings:      SettingsView(store: store)
        case .activity:      ActivityView(store: store)
        case .dailyDigest:   DigestView(store: store)
        case .timeTracking:  TimeTrackingView(store: store)
        case .tasks:         TasksView(store: store)
        case .inbox:         InboxView(store: store)
        case .depsOutdated:  DepsView(store: store)
        case .github:        GitHubView(store: store)
        default:             ProjectGridView(store: store)   // all, favorites, recents, missing, uncategorized, category
        }
    }

    private var navID: String { "\(store.nav)" }

    // MARK: Acciones de alta

    private func addFolder() { store.addProjectsFolder(categoryID: store.currentCategoryID) }

    private func startAddSingle() {
        // Si estoy dentro de una categoría, el proyecto se agrega a esa categoría.
        let category = store.currentCategoryID
        if let path = store.pickSingleProjectFolder() {
            pendingPath = path
            pendingName = (path as NSString).lastPathComponent
            pendingCategory = category
            showNameDialog = true
        }
    }
}

// MARK: - Barra superior

struct TopBar: View {
    @Bindable var store: ProjectStore
    var onNew: () -> Void
    var onAddFolder: () -> Void
    var onAddSingle: () -> Void
    var onNewSubcategory: () -> Void
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .contentTransition(.numericText())

            Spacer()

            // Buscador
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(searchFocused ? AnyShapeStyle(Theme.lilac) : AnyShapeStyle(.white.opacity(0.7)))
                TextField("Buscar proyectos…", text: $store.searchText)
                    .textFieldStyle(.plain).font(.system(size: 13))
                    .focused($searchFocused).frame(width: 200)
                if !store.searchText.isEmpty {
                    Button { store.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .liquidGlass(cornerRadius: 10, interactive: true)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(searchFocused ? Theme.lilac.opacity(0.7) : .clear, lineWidth: 1))

            if store.isScanning { ProgressView().controlSize(.small) }

            // Botón prominente de nuevo proyecto
            Button { onNew() } label: {
                Label("Nuevo proyecto", systemImage: "sparkles")
            }
            .buttonStyle(.glassy(tint: Theme.accent, prominent: true))

            // Menú agregar (otras opciones, se abre con click)
            AddMenu(store: store, onNew: onNew, onAddSingle: onAddSingle,
                    onAddFolder: onAddFolder, onNewSubcategory: onNewSubcategory)
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
    }

    private var title: String {
        if store.selectedProjectID != nil { return String(localized: "Proyecto") }
        switch store.nav {
        case .home:          return String(localized: "Inicio")
        case .all:           return String(localized: "Todos los proyectos")
        case .favorites:     return String(localized: "Favoritos")
        case .recents:       return String(localized: "Recientes")
        case .activity:      return String(localized: "Actividad")
        case .dailyDigest:   return String(localized: "Daily digest")
        case .timeTracking:  return String(localized: "Time tracking")
        case .tasks:         return String(localized: "Tareas")
        case .inbox:         return String(localized: "Inbox")
        case .depsOutdated:  return String(localized: "Deps desactualizadas")
        case .missing:       return String(localized: "Perdidos")
        case .uncategorized: return String(localized: "Sin categoría")
        case .github:        return String(localized: "GitHub")
        case .settings:      return String(localized: "Configuración")
        case .category(let id): return store.folders.first { $0.id == id }?.name ?? String(localized: "Categoría")
        }
    }
}

#Preview {
    ContentView(store: ProjectStore())
}
