//
//  ExtraViews.swift
//  CENTRO
//
//  Pantallas: bienvenida, inicio, configuración y placeholders de herramientas.
//

import SwiftUI

// MARK: - Bienvenida (sin fuentes cargadas)

struct WelcomeView: View {
    let onNew: () -> Void
    let onAddFolder: () -> Void
    let onAddSingle: () -> Void

    var body: some View {
        ZStack {
            RadialGradient(colors: [Theme.lilac.opacity(0.6), Theme.lilacGlow.opacity(0.15), .clear],
                           center: .center, startRadius: 0, endRadius: 460)
                .blur(radius: 50).ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    Circle().fill(Theme.lilacGlow).frame(width: 96, height: 96).blur(radius: 34).opacity(0.9)
                    Circle()
                        .fill(LinearGradient(colors: [Theme.lilacGlow, Theme.lilac],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 96, height: 96)
                        .shadow(color: Theme.lilac.opacity(0.9), radius: 36)
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 40, weight: .bold)).foregroundStyle(.white)
                }
                VStack(spacing: 8) {
                    Text("Bienvenido a CENTRO")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.white, Theme.lilacSoft],
                                                        startPoint: .top, endPoint: .bottom))
                    Text("Cargá tus proyectos para empezar.")
                        .font(.system(size: 13.5)).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Button(action: onNew) {
                        Label("Crear nuevo proyecto", systemImage: "sparkles")
                    }
                    .buttonStyle(.glassy(tint: Theme.lilac, prominent: true))

                    Button(action: onAddSingle) {
                        Label("Agregar existente", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.glassy(tint: Theme.lilac))

                    Button(action: onAddFolder) {
                        Label("Cargar carpeta", systemImage: "folder.fill.badge.plus")
                    }
                    .buttonStyle(.glassy(tint: Theme.lilac))
                }
            }
            .appear(index: 0)
        }
    }
}

// MARK: - Inicio

struct HomeView: View {
    @Bindable var store: ProjectStore
    @State private var ports: [String: [Int]] = [:]
    @State private var loadingPorts = true

    private var dirtyProjects: [Project] {
        store.projects.filter { $0.exists && $0.git.dirty }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }
    private var runningProjects: [Project] {
        ports.keys.compactMap { path in store.projects.first { $0.path == path && $0.exists } }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
    private var pendingTodos: Int { store.todos.filter { !$0.done }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                greeting.appear(index: 0)
                stats.appear(index: 1)
                if store.activeSession != nil { activeTimerCard.appear(index: 2) }
                runningSection.appear(index: 3)
                if !dirtyProjects.isEmpty { changesSection.appear(index: 4) }
                recentsSection.appear(index: 5)
                Spacer(minLength: 20)
            }
            .padding(28)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .task(id: store.projects.count) { await loadPorts() }
        .task {
            // auto-refresh del estado mientras Inicio está visible
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                if Task.isCancelled { break }
                await loadPorts(silent: true)
            }
        }
    }

    // MARK: Saludo

    private var greeting: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(saludo).font(.system(size: 28, weight: .heavy, design: .rounded))
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { Task { await loadPorts() } } label: {
                Image(systemName: loadingPorts ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.glassy).help("Refrescar estado")
        }
    }

    private var saludo: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return String(localized: "Buenos días")
        case 12..<20: return String(localized: "Buenas tardes")
        default:      return String(localized: "Buenas noches")
        }
    }

    // MARK: Stats

    private var stats: some View {
        HStack(spacing: 14) {
            statCard("Proyectos", store.count(for: .all), "square.grid.2x2.fill", .white,
                     action: { store.nav = .all })
            statCard("Corriendo", runningProjects.count, "bolt.fill", .green, action: nil)
            statCard("Favoritos", store.count(for: .favorites), "star.fill", Theme.accentSoft,
                     action: { store.nav = .favorites })
            statCard("Tareas", pendingTodos, "checklist", Theme.accent,
                     action: { store.nav = .tasks })
            statCard("Perdidos", store.count(for: .missing), "exclamationmark.triangle.fill", Theme.lilacGlow,
                     action: store.count(for: .missing) > 0 ? { store.nav = .missing } : nil)
        }
    }

    private func statCard(_ title: LocalizedStringKey, _ value: Int, _ symbol: String, _ color: Color, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(color)
                Text("\(value)").font(.system(size: 26, weight: .heavy, design: .rounded))
                Text(title).font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: 16)
        }
        .buttonStyle(.plain).disabled(action == nil)
    }

    // MARK: Timer activo

    private var activeTimerCard: some View {
        let _ = store.tick
        return Group {
            if let s = store.activeSession {
                HStack(spacing: 12) {
                    Image(systemName: "timer").font(.system(size: 20)).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Registrando tiempo").font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(store.projectName(forPath: s.projectPath)).font(.system(size: 14, weight: .semibold))
                    }
                    Spacer()
                    Text(formatHMS(s.seconds)).font(.system(size: 18, weight: .heavy, design: .monospaced))
                    Button { store.stopTimer() } label: { Image(systemName: "stop.fill") }
                        .buttonStyle(.glassy(tint: Theme.accent))
                }
                .padding(16).liquidGlass(cornerRadius: 16)
            }
        }
    }

    // MARK: Corriendo ahora

    private var runningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(.green).frame(width: 7, height: 7).shadow(color: .green, radius: 3)
                Text("Corriendo ahora").font(.system(size: 15, weight: .bold))
                if loadingPorts { ProgressView().controlSize(.mini) }
            }
            if runningProjects.isEmpty {
                Text(loadingPorts ? String(localized: "Buscando servidores activos…") : String(localized: "Ningún proyecto corriendo en un puerto local."))
                    .font(.system(size: 12)).foregroundStyle(.tertiary)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).liquidGlass(cornerRadius: 12)
            } else {
                ForEach(runningProjects) { p in runningRow(p) }
            }
        }
    }

    private func runningRow(_ p: Project) -> some View {
        HStack(spacing: 12) {
            ProjectAvatar(project: p, size: 32, corner: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(p.displayName).font(.system(size: 13, weight: .semibold))
                if p.git.isGit, let b = p.git.branch {
                    Text(b).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            ForEach(ports[p.path] ?? [], id: \.self) { port in
                Button { SystemActions.openURL("http://localhost:\(port)") } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.forward").font(.system(size: 9, weight: .bold))
                        Text(":\(port)").font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(.green.opacity(0.14), in: .capsule)
                    .overlay(Capsule().stroke(.green.opacity(0.3), lineWidth: 0.5))
                }
                .buttonStyle(.plain).help("Abrir en el navegador")
            }
            Button { store.selectedProjectID = p.id } label: {
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .liquidGlass(cornerRadius: 12)
    }

    // MARK: Cambios sin commitear

    private var changesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Cambios sin commitear", systemImage: "pencil.circle.fill")
                .font(.system(size: 15, weight: .bold)).foregroundStyle(.secondary)
            ForEach(dirtyProjects.prefix(5)) { p in
                Button { store.selectedProjectID = p.id } label: {
                    HStack(spacing: 12) {
                        ProjectAvatar(project: p, size: 28, corner: 7)
                        Text(p.displayName).font(.system(size: 13, weight: .medium))
                        Spacer()
                        if let b = p.git.branch {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.branch").font(.system(size: 9))
                                Text(b).font(.system(size: 10, design: .monospaced))
                            }.foregroundStyle(Theme.lilacGlow)
                        }
                        Circle().fill(Theme.lilacGlow).frame(width: 6, height: 6)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .liquidGlass(cornerRadius: 12).contentShape(.rect)
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: Recientes

    private var recentsSection: some View {
        let recents = Array(store.projects(for: .recents).prefix(6))
        return Group {
            if !recents.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Recientes", systemImage: "clock.fill")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 360), spacing: 16)], spacing: 16) {
                        ForEach(Array(recents.enumerated()), id: \.element.id) { idx, p in
                            ProjectCardView(project: p, store: store).appear(index: idx)
                        }
                    }
                }
            }
        }
    }

    private func loadPorts(silent: Bool = false) async {
        if !silent { loadingPorts = true }
        ports = await PortDetector.runningPorts(forProjectPaths: store.projects.map { $0.path })
        loadingPorts = false
    }
}

// MARK: - Configuración

struct SettingsView: View {
    @Bindable var store: ProjectStore
    @State private var actionLabel = ""
    @State private var actionCommand = ""
    @State private var actionTerminal = true
    @Bindable private var prefs = AppPrefs.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Configuración")
                    .font(.system(size: 24, weight: .bold, design: .rounded)).appear(index: 0)

                settingRow(icon: "doc.on.doc.fill", title: "Proyectos individuales",
                           subtitle: "\(store.manualProjectPaths.count) cargados") { EmptyView() }
                    .appear(index: 1)

                if store.excludedCount > 0 {
                    settingRow(icon: "trash.fill", title: "Proyectos quitados",
                               subtitle: "\(store.excludedCount) excluidos") {
                        Button("Restaurar") { store.restoreExcluded() }.buttonStyle(.glassy)
                    }
                    .appear(index: 2)
                }

                generalSettings.appear(index: 3)
                claudeCommandSetting.appear(index: 3)
                ActionListEditor(store: store, title: "Botones de las tarjetas", symbol: "rectangle.on.rectangle",
                                 note: "Aparecen al pasar el cursor por cada proyecto.",
                                 selection: $prefs.cardActions)
                    .appear(index: 4)
                ActionListEditor(store: store, title: "Lupa de la barra de menú", symbol: "magnifyingglass",
                                 note: "Opciones al elegir un proyecto desde la lupa de arriba.",
                                 selection: $prefs.quickSearchActions)
                    .appear(index: 5)
                customActionsManager.appear(index: 6)
                Spacer(minLength: 20)
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }

    @State private var language = AppLanguage.current

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("General", systemImage: "gearshape.fill")
                .font(.system(size: 14, weight: .bold)).foregroundStyle(.secondary)
            HStack {
                Text("Idioma").font(.system(size: 13, weight: .medium))
                Spacer()
                Picker("", selection: $language) {
                    ForEach(AppLanguage.allCases) { Text($0.name).tag($0) }
                }
                .labelsHidden().fixedSize()
                .onChange(of: language) { language.apply() }
            }
            if language != AppLanguage.atLaunch {
                HStack {
                    Text("El idioma se aplica al reiniciar CENTRO.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Reiniciar ahora") { AppLanguage.relaunch() }
                        .buttonStyle(.glassy(tint: Theme.accent, prominent: true))
                }
            }
            HStack {
                Text("Abrir proyectos en").font(.system(size: 13, weight: .medium))
                Spacer()
                Picker("", selection: $prefs.terminalApp) {
                    ForEach(TerminalApp.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
            }
            HStack {
                Button("Ver la bienvenida otra vez") { prefs.onboardingDone = false }
                    .buttonStyle(.plain).font(.system(size: 11.5)).foregroundStyle(Theme.lilac)
                Spacer()
                Link(destination: URL(string: AppInfo.repoURL)!) {
                    Text("CENTRO \(AppInfo.version) · GitHub").font(.system(size: 11))
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).liquidGlass(cornerRadius: 14)
    }

    private var claudeCommandSetting: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Comando de Claude Code", systemImage: "terminal.fill")
                .font(.system(size: 14, weight: .bold)).foregroundStyle(.secondary)
            Text("Lo que se ejecuta en la Terminal al abrir un proyecto con Claude Code.")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
            HStack(spacing: 8) {
                TextField(AppPrefs.defaultClaudeCommand, text: $prefs.claudeCommand)
                    .textFieldStyle(.plain).font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 10).padding(.vertical, 8).liquidGlass(cornerRadius: 9)
                if prefs.claudeCommand != AppPrefs.defaultClaudeCommand {
                    Button("Restablecer") { prefs.claudeCommand = AppPrefs.defaultClaudeCommand }
                        .buttonStyle(.glassy)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).liquidGlass(cornerRadius: 14)
    }

    private var customActionsManager: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Acciones personalizadas", systemImage: "bolt.fill")
                .font(.system(size: 14, weight: .bold)).foregroundStyle(.secondary)
            Text("Botones con tus comandos, que corren en la carpeta de cada proyecto.")
                .font(.system(size: 11)).foregroundStyle(.tertiary)

            ForEach(store.customActions) { a in
                HStack(spacing: 10) {
                    Image(systemName: a.symbol).foregroundStyle(Theme.accent).frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(a.label).font(.system(size: 13, weight: .medium))
                        Text(a.command).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text(a.runsInTerminal ? "Terminal" : String(localized: "Background"))
                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                    Button { store.removeCustomAction(a.id) } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 12).padding(.vertical, 9).liquidGlass(cornerRadius: 11)
            }

            HStack(spacing: 8) {
                TextField("Nombre", text: $actionLabel)
                    .textFieldStyle(.plain).font(.system(size: 12)).frame(width: 110)
                    .padding(.horizontal, 10).padding(.vertical, 8).liquidGlass(cornerRadius: 9)
                TextField("Comando (ej. npm run lint)", text: $actionCommand)
                    .textFieldStyle(.plain).font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 10).padding(.vertical, 8).liquidGlass(cornerRadius: 9)
                Toggle("Terminal", isOn: $actionTerminal).toggleStyle(.checkbox).font(.system(size: 11))
                Button {
                    let l = actionLabel.trimmingCharacters(in: .whitespaces)
                    let c = actionCommand.trimmingCharacters(in: .whitespaces)
                    if !l.isEmpty && !c.isEmpty {
                        store.addCustomAction(CustomAction(label: l, command: c, runsInTerminal: actionTerminal))
                        actionLabel = ""; actionCommand = ""
                    }
                } label: { Image(systemName: "plus") }
                    .buttonStyle(.glassy(tint: Theme.accent, prominent: true))
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).liquidGlass(cornerRadius: 14)
    }

    private func settingRow<T: View>(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey, @ViewBuilder trailing: () -> T) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(subtitle).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            trailing()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 14)
    }
}

// MARK: - Placeholder de herramientas (próximamente)

struct PlaceholderView: View {
    let title: LocalizedStringKey
    let symbol: String
    var note: LocalizedStringKey = "Esta sección está en camino."

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(Theme.accent.gradient)
                .shadow(color: Theme.accent.opacity(0.4), radius: 16)
            Text(title).font(.system(size: 22, weight: .bold, design: .rounded))
            Text(note).font(.system(size: 13)).foregroundStyle(.secondary)
            Text("Próximamente")
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Theme.accent.opacity(0.18), in: .capsule)
                .foregroundStyle(Theme.accentSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appear(index: 0)
    }
}

// MARK: - Editor de lista de acciones (tarjetas / lupa)

struct ActionListEditor: View {
    @Bindable var store: ProjectStore
    let title: LocalizedStringKey
    let symbol: String
    let note: LocalizedStringKey
    @Binding var selection: [String]

    private var chosen: [LaunchAction] { LaunchAction.resolve(selection, custom: store.customActions) }
    private var available: [LaunchAction] {
        LaunchAction.all(custom: store.customActions).filter { !selection.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.system(size: 14, weight: .bold)).foregroundStyle(.secondary)
            Text(note).font(.system(size: 11)).foregroundStyle(.tertiary)

            if chosen.isEmpty {
                Text("Ninguna elegida.").font(.system(size: 12)).foregroundStyle(.tertiary)
            }
            ForEach(Array(chosen.enumerated()), id: \.element.id) { idx, a in
                HStack(spacing: 10) {
                    AppGlyph(symbol: a.symbol, asset: a.asset, size: a.asset != nil ? 18 : 13, tint: Theme.accent)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(a.name).font(.system(size: 13, weight: .medium))
                        if let s = a.subtitle {
                            Text(s).font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer()
                    Button { move(a.id, by: -1) } label: { Image(systemName: "chevron.up") }
                        .buttonStyle(.plain).disabled(idx == 0).foregroundStyle(.secondary)
                    Button { move(a.id, by: 1) } label: { Image(systemName: "chevron.down") }
                        .buttonStyle(.plain).disabled(idx == chosen.count - 1).foregroundStyle(.secondary)
                    Button { selection.removeAll { $0 == a.id } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 12).padding(.vertical, 9).liquidGlass(cornerRadius: 11)
            }

            if !available.isEmpty {
                Menu {
                    ForEach(available) { a in
                        Button(a.name) { selection.append(a.id) }
                    }
                } label: {
                    Label("Agregar", systemImage: "plus")
                }
                .menuStyle(.button).fixedSize()
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).liquidGlass(cornerRadius: 14)
    }

    private func move(_ id: String, by delta: Int) {
        guard let i = selection.firstIndex(of: id) else { return }
        let j = i + delta
        guard selection.indices.contains(j) else { return }
        selection.swapAt(i, j)
    }
}
