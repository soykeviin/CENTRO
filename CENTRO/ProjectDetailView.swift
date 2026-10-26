//
//  ProjectDetailView.swift
//  CENTRO
//
//  Detalle de un proyecto: info, acciones inteligentes, git y notas.
//

import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @Bindable var store: ProjectStore
    @State private var notes: String = ""
    @State private var smartActions: [SmartAction] = []
    @State private var showRename = false
    @State private var renameText = ""
    @State private var readme: String? = nil
    @State private var tab: DetailTab = .readme
    @State private var runningPorts: [Int] = []
    @State private var remoteURL: String? = nil
    @State private var showPublish = false

    enum DetailTab { case readme, files }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header.appear(index: 0)
                if project.exists {
                    actionsBar.appear(index: 1).zIndex(50)
                    if let dev = devAction {
                        DevServerView(store: store, path: project.path, command: dev.command, label: dev.label)
                            .appear(index: 2)
                    }
                    if !smartActions.isEmpty { smartActionsSection.appear(index: 2) }
                    if !store.customActions.isEmpty { customActionsSection.appear(index: 2) }
                    if project.git.isGit { gitSection.appear(index: 3) }
                    contentTabs.appear(index: 4)
                    notesSection.appear(index: 5)
                } else {
                    missingNotice.appear(index: 1)
                    notesSection.appear(index: 2)
                }
                Spacer(minLength: 40)
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .onAppear {
            notes = project.notes
            smartActions = StackDetector.smartActions(at: project.path)
            readme = Self.loadReadme(at: project.path)
            tab = readme != nil ? .readme : .files
        }
        .alert("Renombrar proyecto", isPresented: $showRename) {
            TextField("Nombre", text: $renameText)
            Button("Guardar") { store.rename(project.id, to: renameText) }
            Button("Cancelar", role: .cancel) { }
        }
        .task(id: project.id) { await loadPorts() }
        .task(id: project.id) { remoteURL = await GitService.remoteURL(at: project.path) }
        .sheet(isPresented: $showPublish, onDismiss: {
            Task { remoteURL = await GitService.remoteURL(at: project.path) }
        }) {
            PublishSheet(store: store, project: project)
        }
    }

    // MARK: Categoría (mover proyecto)

    private var categoryMenu: some View {
        Menu {
            Button { store.setCategory(project.id, nil) } label: {
                Label("Sin categoría", systemImage: project.folderID == nil ? "checkmark" : "minus")
            }
            ForEach(store.topCategories) { cat in
                categoryMenuItem(cat)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "folder.fill").font(.system(size: 9))
                Text(store.categoryName(project.folderID) ?? String(localized: "Sin categoría"))
                    .font(.system(size: 10.5, weight: .medium)).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 8))
            }
            .foregroundStyle(currentCategoryColor)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(currentCategoryColor.opacity(0.15), in: .capsule)
        }
        .menuStyle(.button).buttonStyle(.plain).fixedSize()
    }

    private func categoryMenuItem(_ cat: VirtualFolder) -> AnyView {
        let subs = store.subcategories(of: cat.id)
        if subs.isEmpty {
            return AnyView(
                Button { store.setCategory(project.id, cat.id) } label: {
                    Label(cat.name, systemImage: project.folderID == cat.id ? "checkmark" : cat.symbol)
                }
            )
        } else {
            return AnyView(
                Menu(cat.name) {
                    Button { store.setCategory(project.id, cat.id) } label: {
                        Label("\(cat.name) (esta)", systemImage: project.folderID == cat.id ? "checkmark" : "folder")
                    }
                    ForEach(subs) { sub in categoryMenuItem(sub) }
                }
            )
        }
    }

    private var currentCategoryColor: Color {
        if let id = project.folderID, let c = store.folders.first(where: { $0.id == id }) { return c.color }
        return .secondary
    }

    // MARK: Puerto en ejecución

    private var runningBadge: some View {
        HStack(spacing: 6) {
            Circle().fill(.green).frame(width: 6, height: 6)
                .shadow(color: .green, radius: 3)
            ForEach(runningPorts, id: \.self) { port in
                Button { SystemActions.openURL("http://localhost:\(port)") } label: {
                    Text("localhost:\(port)")
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .help("Abrir en el navegador")
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(.green.opacity(0.14), in: .capsule)
        .overlay(Capsule().stroke(.green.opacity(0.3), lineWidth: 0.5))
    }

    private func loadPorts() async {
        guard project.exists else { return }
        let map = await PortDetector.runningPorts(forProjectPaths: [project.path])
        runningPorts = map[project.path] ?? []
    }

    // MARK: README + Archivos (pestañas)

    private var contentTabs: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                tabButton("README", "doc.text", .readme, enabled: readme != nil)
                tabButton("Archivos", "folder", .files, enabled: true)
                Spacer()
            }
            Group {
                if tab == .readme, let r = readme {
                    ScrollView {
                        MarkdownView(markdown: r)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 460)
                    .liquidGlass(cornerRadius: 14)
                } else {
                    FileBrowserView(rootPath: project.path)
                }
            }
        }
    }

    private func tabButton(_ title: LocalizedStringKey, _ symbol: String, _ value: DetailTab, enabled: Bool) -> some View {
        let selected = tab == value
        return Button {
            withAnimation(.snappy) { tab = value }
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 9).fill(Theme.accent.opacity(0.22))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    /// Busca y lee el README del proyecto.
    private static func loadReadme(at path: String) -> String? {
        let names = ["README.md", "readme.md", "Readme.md", "README.markdown", "README.txt", "README"]
        for n in names {
            let p = (path as NSString).appendingPathComponent(n)
            if let s = try? String(contentsOfFile: p, encoding: .utf8), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return s
            }
        }
        return nil
    }

    // MARK: Aviso de proyecto perdido

    private var missingNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18)).foregroundStyle(Theme.lilacGlow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Carpeta no encontrada").font(.system(size: 14, weight: .semibold))
                Text("La carpeta de este proyecto fue movida o eliminada del disco.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 14)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.snappy) { store.selectedProjectID = nil }
            } label: {
                Label("Volver", systemImage: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            HStack(alignment: .top, spacing: 16) {
                ProjectAvatar(project: project, size: 64, corner: 16)
                    .shadow(color: Theme.accent.opacity(0.4), radius: 12, y: 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(project.displayName).font(.system(size: 26, weight: .bold, design: .rounded))
                        Button {
                            renameText = project.displayName
                            showRename = true
                        } label: {
                            Image(systemName: "pencil").font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain).help("Renombrar")
                    }
                    Text(project.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                    if let opened = project.lastOpenedAt {
                        Text("Abierto \(opened.formatted(.relative(presentation: .named)))")
                            .font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                    if !runningPorts.isEmpty {
                        runningBadge.padding(.top, 3)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    Button { store.toggleFavorite(project.id) } label: {
                        Image(systemName: project.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 20))
                            .foregroundStyle(project.isFavorite ? AnyShapeStyle(Theme.accentSoft) : AnyShapeStyle(.secondary))
                    }
                    .buttonStyle(.plain)
                    categoryMenu
                }
            }

            if !project.detectedStack.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(project.detectedStack) { StackBadgeView(badge: $0) }
                    }
                }
            }
        }
    }

    // MARK: Acciones principales

    private var actionsBar: some View {
        HStack(spacing: 10) {
            if let dev = devAction {
                let running = store.devServers.isRunning(project.path)
                Button {
                    store.devServers.toggle(path: project.path, command: dev.command)
                } label: { Label(running ? String(localized: "Detener") : dev.label, systemImage: running ? "stop.fill" : "play.fill") }
                    .buttonStyle(.glassy(tint: running ? .red : Theme.accent, prominent: true))
            }
            actionButton("Finder", symbol: "folder.fill") { SystemActions.revealInFinder(project.path) }
            actionButton("Terminal", symbol: "terminal.fill") {
                SystemActions.runInTerminal(cwd: project.path, command: ""); store.markOpened(project.id)
            }
            EditMenu(project: project, store: store)
            if let remote = remoteURL {
                actionButton("GitHub", symbol: "cloud.fill") { SystemActions.openURL(GitService.webURL(from: remote)) }
            } else {
                actionButton("Subir a GitHub", symbol: "cloud.fill") { showPublish = true }
            }
            Spacer()
        }
    }

    private var devAction: SmartAction? {
        smartActions.first { $0.id == "npm-dev" || $0.id == "npm-start" }
    }

    private func actionButton(_ title: LocalizedStringKey, symbol: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                AppGlyph(symbol: symbol, size: 13, tint: .primary)
                Text(title)
            }
        }
        .buttonStyle(.glassy(tint: Theme.accent))
    }

    // MARK: Acciones inteligentes

    private var smartActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Acciones inteligentes", "wand.and.stars")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                ForEach(smartActions) { action in
                    Button {
                        run(action)
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: action.systemImage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 22)
                            Text(action.label)
                                .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .liquidGlass(cornerRadius: 11, interactive: true)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Acciones personalizadas

    private var customActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Acciones personalizadas", "bolt.fill")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                ForEach(store.customActions) { action in
                    Button {
                        store.runCustomAction(action, in: project.path); store.markOpened(project.id)
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: action.symbol).font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.accent).frame(width: 22)
                            Text(action.label).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .liquidGlass(cornerRadius: 11, interactive: true)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) { store.removeCustomAction(action.id) } label: {
                            Label("Eliminar acción", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: Git

    private var gitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Git", "arrow.triangle.branch")
            GitPanel(path: project.path)
        }
    }

    // MARK: Notas

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Notas", "note.text")
            TextEditor(text: $notes)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(12)
                .liquidGlass(cornerRadius: 14)
                .onChange(of: notes) { _, new in store.setNotes(project.id, new) }
        }
    }

    // MARK: Helpers

    private func sectionTitle(_ text: LocalizedStringKey, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.secondary)
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.18), in: .capsule)
            .foregroundStyle(color)
    }

    private func run(_ action: SmartAction) {
        switch action.opensIn {
        case .terminal:   SystemActions.runInTerminal(cwd: project.path, command: action.command)
        case .background: SystemActions.open(action.command)
        case .app:        SystemActions.open(action.command)
        }
        store.markOpened(project.id)
    }
}
