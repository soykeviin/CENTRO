//
//  QuickSearchMenu.swift
//  CENTRO
//
//  Lupa en la barra de menú: buscar un proyecto por nombre y abrirlo con un
//  clic en el logo de la herramienta (Claude Code, carpeta, CENTRO…). Las
//  opciones se eligen en Configuración → Lupa de la barra de menú.
//

import SwiftUI

struct QuickSearchMenu: View {
    @Bindable var store: ProjectStore
    @Environment(\.openWindow) private var openWindow
    @State private var query = ""
    @State private var highlighted = 0
    @State private var hovered: Project.ID? = nil
    @FocusState private var focused: Bool
    @State private var selection: TextSelection? = nil

    private let autofocus: Bool

    init(store: ProjectStore, initialQuery: String = "", autofocus: Bool = true) {
        self.store = store
        self.autofocus = autofocus
        _query = State(initialValue: initialQuery)
    }

    private let rowHeight: CGFloat = 54
    private let maxRows = 7

    private var actions: [LaunchAction] {
        LaunchAction.resolve(AppPrefs.shared.quickSearchActions, custom: store.customActions)
    }

    var body: some View {
        let all = store.searchProjects(query)
        let list = Array(all.prefix(30))
        VStack(alignment: .leading, spacing: 0) {
            searchField(list)
                .padding(12)

            HStack {
                Text(query.isEmpty ? String(localized: "RECIENTES")
                     : (all.count == 1 ? String(localized: "1 RESULTADO") : String(localized: "\(all.count) RESULTADOS")))
                    .font(.system(size: 9.5, weight: .bold)).tracking(0.8)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.bottom, 6)

            if list.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "questionmark.folder")
                        .font(.system(size: 22, weight: .light)).foregroundStyle(.tertiary)
                    Text(store.projects.isEmpty ? "Cargando proyectos…" : "Ningún proyecto coincide.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).frame(height: rowHeight * 2)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(list.enumerated()), id: \.element.id) { idx, p in
                                row(p, isHighlighted: idx == highlighted).id(idx)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .scrollIndicators(.never)
                    // Alto explícito: dentro de la barra de menú un ScrollView sin alto colapsa.
                    .frame(height: CGFloat(min(list.count, maxRows)) * (rowHeight + 2))
                    .onChange(of: highlighted) { proxy.scrollTo(highlighted) }
                }
            }

            footer
        }
        .frame(width: 440)
        .background(Color(hex: "#141418") ?? .black)
        .onAppear {
            focused = autofocus; highlighted = 0
            selection = TextSelection(insertionPoint: query.endIndex)   // cursor al final, sin seleccionar todo
        }
        .onChange(of: query) { highlighted = 0 }
        .onKeyPress(.downArrow) { highlighted = min(highlighted + 1, max(list.count - 1, 0)); return .handled }
        .onKeyPress(.upArrow) { highlighted = max(highlighted - 1, 0); return .handled }
    }

    // MARK: Buscador

    private func searchField(_ list: [Project]) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.lilac)
            TextField("Buscar proyecto…", text: $query, selection: $selection)
                .textFieldStyle(.plain).font(.system(size: 16, weight: .medium))
                .focused($focused)
                .onSubmit {
                    // Enter: abre el proyecto resaltado con la primera opción
                    if list.indices.contains(highlighted), let first = actions.first { run(first, on: list[highlighted]) }
                }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundStyle(.tertiary)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.lilac.opacity(focused ? 0.55 : 0.15), lineWidth: 1))
    }

    // MARK: Fila

    private func row(_ p: Project, isHighlighted: Bool) -> some View {
        let active = isHighlighted || hovered == p.id
        return HStack(spacing: 11) {
            ProjectAvatar(project: p, size: 32, corner: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(p.displayName)
                    .font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                Text(p.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.head)
            }
            Spacer(minLength: 6)
            HStack(spacing: 5) {
                ForEach(actions) { a in
                    ActionIconButton(action: a) { run(a, on: p) }
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: rowHeight)
        .background {
            RoundedRectangle(cornerRadius: 11)
                .fill(active ? Theme.lilac.opacity(0.13) : .clear)
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(active ? Theme.lilac.opacity(0.3) : .clear, lineWidth: 0.5))
        }
        .contentShape(.rect)
        .onHover { h in hovered = h ? p.id : (hovered == p.id ? nil : hovered) }
        .onTapGesture { if let first = actions.first { run(first, on: p) } }
        .animation(.snappy, value: active)
    }

    // MARK: Pie

    private var footer: some View {
        HStack(spacing: 14) {
            Button { openCentro() } label: {
                Label("Abrir CENTRO", systemImage: "macwindow")
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            Spacer()
            if let first = actions.first {
                HStack(spacing: 4) {
                    Text(verbatim: "↵").font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.white.opacity(0.1), in: .rect(cornerRadius: 4))
                    Text(first.name)
                }
                .foregroundStyle(.tertiary)
            }
            Button("Salir") { NSApp.terminate(nil) }
                .buttonStyle(.plain).foregroundStyle(.tertiary)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 18).padding(.vertical, 11)
        .background(.white.opacity(0.03))
        .overlay(alignment: .top) { Divider().opacity(0.5) }
        .padding(.top, 8)
    }

    // MARK: Acciones

    private func run(_ a: LaunchAction, on p: Project) {
        closeMenu()
        store.perform(a, on: p, openInCentro: openCentro)
        query = ""
    }

    private func closeMenu() {
        NSApp.keyWindow?.orderOut(nil)
    }

    /// Trae la ventana principal de CENTRO (o la vuelve a abrir si se cerró).
    private func openCentro() {
        closeMenu()
        NSApp.activate(ignoringOtherApps: true)
        if let win = NSApp.windows.first(where: { $0.identifier?.rawValue.contains("AppWindow") == true }) {
            win.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
    }
}

/// Botón cuadrado con el logo de la herramienta y su nombre al pasar el cursor.
private struct ActionIconButton: View {
    let action: LaunchAction
    let perform: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: perform) {
            AppGlyph(symbol: action.symbol, asset: action.asset,
                     size: action.asset != nil ? 19 : 13, tint: hover ? .white : .white.opacity(0.8))
                .frame(width: 30, height: 30)
                .background(hover ? Theme.lilac.opacity(0.35) : .white.opacity(0.07), in: .rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(hover ? 0.25 : 0.08), lineWidth: 0.5))
                .scaleEffect(hover ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .help(action.name)
        .onHover { h in withAnimation(.snappy) { hover = h } }
    }
}
