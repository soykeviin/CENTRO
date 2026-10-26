//
//  CommandPalette.swift
//  CENTRO
//
//  Buscador universal (⌘K): saltar a proyectos, secciones y acciones.
//

import SwiftUI

struct CommandPalette: View {
    @Bindable var store: ProjectStore
    @Binding var isPresented: Bool
    var onNewProject: () -> Void

    @State private var query = ""
    @State private var selection = 0
    @FocusState private var focused: Bool

    enum Item: Identifiable {
        case project(Project)
        case section(NavItem, String, String)
        case action(String, String, String, () -> Void)   // id, title, symbol, action

        var id: String {
            switch self {
            case .project(let p): return "p:\(p.path)"
            case .section(_, let t, _): return "s:\(t)"
            case .action(let i, _, _, _): return "a:\(i)"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Buscador
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 15)).foregroundStyle(Theme.accent)
                TextField("Buscar proyectos, secciones, acciones…", text: $query)
                    .textFieldStyle(.plain).font(.system(size: 16))
                    .focused($focused)
                    .onSubmit { activate() }
                    .onChange(of: query) { _, _ in selection = 0 }
                Text("esc").font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 5))
            }
            .padding(16)
            Divider().overlay(.white.opacity(0.08))

            // Resultados
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                            row(item, selected: idx == selection)
                                .id(idx)
                                .onTapGesture { selection = idx; activate() }
                        }
                        if items.isEmpty {
                            Text("Sin resultados").font(.system(size: 12)).foregroundStyle(.tertiary).padding(.vertical, 20)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 360)
                .onChange(of: selection) { _, s in withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(s) } }
            }
        }
        .frame(width: 600)
        .background(Color(hex: "#16161C") ?? .black, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
        .onAppear { focused = true }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onKeyPress(.escape) { isPresented = false; return .handled }
    }

    // MARK: Items

    private var items: [Item] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        var result: [Item] = []

        // Proyectos
        let projects = store.searchProjects(query).prefix(q.isEmpty ? 6 : 8)
        result.append(contentsOf: projects.map { Item.project($0) })

        // Secciones
        let sections: [(NavItem, String, String)] = [
            (.home, String(localized: "Inicio"), "house.fill"),
            (.all, String(localized: "Todos los proyectos"), "square.grid.2x2.fill"),
            (.favorites, String(localized: "Favoritos"), "star.fill"),
            (.recents, String(localized: "Recientes"), "clock.fill"),
            (.activity, String(localized: "Actividad"), "waveform.path.ecg"),
            (.timeTracking, String(localized: "Time tracking"), "timer"),
            (.tasks, String(localized: "Tareas"), "checklist"),
            (.depsOutdated, String(localized: "Deps desactualizadas"), "shippingbox.fill"),
            (.missing, String(localized: "Perdidos"), "exclamationmark.triangle.fill"),
            (.settings, String(localized: "Configuración"), "gearshape.fill"),
        ]
        let matchedSections = sections.filter { q.isEmpty || $0.1.lowercased().contains(q) }
        result.append(contentsOf: matchedSections.prefix(q.isEmpty ? 3 : 6).map { Item.section($0.0, $0.1, $0.2) })

        // Acciones
        let actions: [Item] = [
            .action("new", String(localized: "Crear nuevo proyecto"), "sparkles", { onNewProject() })
        ]
        result.append(contentsOf: actions.filter { _ in q.isEmpty || String(localized: "Crear nuevo proyecto").lowercased().contains(q) })

        return result
    }

    @ViewBuilder
    private func row(_ item: Item, selected: Bool) -> some View {
        HStack(spacing: 11) {
            switch item {
            case .project(let p):
                ProjectAvatar(project: p, size: 26, corner: 7)
                VStack(alignment: .leading, spacing: 1) {
                    Text(p.displayName).font(.system(size: 13.5, weight: .medium))
                    Text(p.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary).lineLimit(1)
                }
                Spacer()
                Text("Proyecto").font(.system(size: 10)).foregroundStyle(.tertiary)
            case .section(_, let title, let symbol):
                Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(.white).frame(width: 26)
                Text(title).font(.system(size: 13.5, weight: .medium))
                Spacer()
                Text("Sección").font(.system(size: 10)).foregroundStyle(.tertiary)
            case .action(_, let title, let symbol, _):
                Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(Theme.accent).frame(width: 26)
                Text(title).font(.system(size: 13.5, weight: .medium))
                Spacer()
                Text("Acción").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(selected ? AnyShapeStyle(Theme.accent.opacity(0.18)) : AnyShapeStyle(.clear),
                    in: .rect(cornerRadius: 9))
        .contentShape(.rect)
    }

    // MARK: Navegación

    private func move(_ d: Int) {
        guard !items.isEmpty else { return }
        selection = (selection + d + items.count) % items.count
    }

    private func activate() {
        guard selection < items.count else { return }
        switch items[selection] {
        case .project(let p):
            store.searchText = ""
            store.selectedProjectID = p.id
        case .section(let nav, _, _):
            store.searchText = ""
            store.nav = nav
            store.selectedProjectID = nil
        case .action(_, _, _, let run):
            run()
        }
        isPresented = false
    }
}
