//
//  SidebarView.swift
//  CENTRO
//
//  Barra lateral de ancho fijo (no estirable). Colapsable a íconos con tooltips.
//

import SwiftUI

struct SidebarView: View {
    @Bindable var store: ProjectStore
    @Binding var collapsed: Bool

    @State private var showCategoryEditor = false
    @State private var editingCategory: VirtualFolder? = nil
    @State private var expanded: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, collapsed ? 0 : 12)
                .padding(.vertical, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section(title: String(localized: "Principal")) {
                        row(.home, String(localized: "Inicio"), "house.fill", .white)
                        row(.all, String(localized: "Todos los proyectos"), "square.grid.2x2.fill", .white)
                        row(.favorites, String(localized: "Favoritos"), "star.fill", .white)
                        row(.recents, String(localized: "Recientes"), "clock.fill", .white)
                    }

                    section(title: String(localized: "Herramientas")) {
                        row(.activity, String(localized: "Actividad"), "waveform.path.ecg", .white)
                        row(.dailyDigest, String(localized: "Daily digest"), "calendar", .white)
                        row(.timeTracking, String(localized: "Time tracking"), "timer", .white)
                        row(.tasks, String(localized: "Tareas"), "checklist", .white)
                        row(.depsOutdated, String(localized: "Deps desactualizadas"), "shippingbox.fill", .white)
                        row(.github, String(localized: "GitHub"), "cloud.fill", .white)
                        row(.missing, String(localized: "Perdidos"), "exclamationmark.triangle.fill", .white)
                        row(.uncategorized, String(localized: "Sin categoría"), "folder", .white)
                    }

                    section(title: String(localized: "Categorías"), trailing: {
                        if !collapsed {
                            Button { editingCategory = nil; showCategoryEditor = true } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }) {
                        if store.folders.isEmpty && !collapsed {
                            Text("Creá tu primera categoría")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 10)
                        }
                        ForEach(store.topCategories) { cat in
                            categoryTree(cat, depth: 0)
                        }
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, collapsed ? 8 : 12)
                .padding(.bottom, 12)
            }
            .scrollContentBackground(.hidden)

            Divider().overlay(.white.opacity(0.06))
            footer
                .padding(.horizontal, collapsed ? 8 : 12)
                .padding(.vertical, 10)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.black.opacity(0.22))
        .sheet(isPresented: $showCategoryEditor) {
            CategoryEditorSheet(store: store, editing: editingCategory)
        }
    }

    // MARK: Header (marca + colapsar)

    private var header: some View {
        Group {
            if collapsed {
                VStack(spacing: 14) {
                    mark
                    toggleButton(symbol: "chevron.right")
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Image("CentroWordmark")
                            .resizable().renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 24)
                            .foregroundStyle(.white)
                        Text("Dashboard de proyectos")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    toggleButton(symbol: "chevron.left")
                }
            }
        }
    }

    private var mark: some View {
        Image("CentroMark")
            .resizable().aspectRatio(contentMode: .fit)
            .frame(width: 36, height: 36)
            .clipShape(.rect(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func toggleButton(symbol: String) -> some View {
        Button {
            withAnimation(.snappy) { collapsed.toggle() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(.white.opacity(0.06), in: .rect(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help(collapsed ? String(localized: "Expandir barra") : String(localized: "Colapsar barra"))
    }

    // MARK: Footer (configuración)

    private var footer: some View {
        Button {
            withAnimation(.snappy) { store.nav = .settings; store.selectedProjectID = nil }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(store.nav == .settings ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
                    .frame(width: collapsed ? 44 : 18)
                if !collapsed {
                    Text("Configuración")
                        .font(.system(size: 13))
                        .foregroundStyle(store.nav == .settings ? .primary : .secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
            .contentShape(.rect)
            .help(collapsed ? String(localized: "Configuración") : "")
        }
        .buttonStyle(.plain)
    }

    // MARK: Sección

    @ViewBuilder
    private func section<Content: View, Trailing: View>(
        title: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if collapsed {
                Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 6)
            } else {
                HStack {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .tracking(0.8).lineLimit(1)
                    Spacer()
                    trailing()
                }
                .padding(.horizontal, 10).padding(.bottom, 2)
            }
            content()
        }
    }

    // MARK: Árbol de categorías

    private func categoryTree(_ cat: VirtualFolder, depth: Int) -> AnyView {
        let subs = store.subcategories(of: cat.id)
        let isOpen = expanded.contains(cat.id)
        return AnyView(
            VStack(alignment: .leading, spacing: 3) {
                row(.category(cat.id), cat.name, cat.symbol, cat.color, depth: depth,
                    hasChildren: !subs.isEmpty, isOpen: isOpen,
                    toggle: {
                        withAnimation(.snappy) {
                            if isOpen { expanded.remove(cat.id) } else { expanded.insert(cat.id) }
                        }
                    })
                    .contextMenu {
                        Button { editingCategory = cat; showCategoryEditor = true } label: {
                            Label("Editar categoría", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            store.removeCategory(cat.id)
                        } label: { Label("Eliminar categoría", systemImage: "trash") }
                    }
                if isOpen && !collapsed {
                    ForEach(subs) { sub in
                        categoryTree(sub, depth: depth + 1)
                    }
                }
            }
        )
    }

    // MARK: Fila

    @ViewBuilder
    private func row(_ item: NavItem, _ title: String, _ symbol: String, _ color: Color,
                     depth: Int = 0, hasChildren: Bool = false, isOpen: Bool = false,
                     toggle: (() -> Void)? = nil) -> some View {
        let isSelected = store.nav == item && store.selectedProjectID == nil
        Button {
            withAnimation(.snappy) {
                store.nav = item
                store.selectedProjectID = nil
            }
        } label: {
            if collapsed {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? AnyShapeStyle(color) : AnyShapeStyle(.secondary))
                    .frame(width: 44, height: 36)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(color.opacity(0.18))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.3), lineWidth: 0.5))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect)
                    .help(title)
            } else {
                HStack(spacing: 6) {
                    if depth > 0 {
                        Spacer().frame(width: CGFloat(depth) * 14)
                    }
                    if hasChildren {
                        Button { toggle?() } label: {
                            Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary).frame(width: 12)
                        }.buttonStyle(.plain)
                    } else if depth > 0 {
                        Spacer().frame(width: 12)
                    }
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 18)
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 4)
                    let n = store.count(for: item)
                    Text("\(n)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .opacity(n > 0 ? 1 : 0)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(color.opacity(0.16))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(color.opacity(0.25), lineWidth: 0.5))
                    }
                }
                .contentShape(.rect)
            }
        }
        .buttonStyle(.plain)
    }
}
