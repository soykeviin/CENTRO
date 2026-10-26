//
//  ProjectGridView.swift
//  CENTRO
//
//  Grilla de proyectos con stagger de entrada y estado vacío.
//

import SwiftUI

struct ProjectGridView: View {
    @Bindable var store: ProjectStore
    @State private var areaTargeted = false

    private let columns = [GridItem(.adaptive(minimum: 250, maximum: 360), spacing: 16)]

    private var categoryID: UUID? {
        if case .category(let id) = store.nav { return id }
        return nil
    }
    private var subcats: [VirtualFolder] {
        categoryID.map { store.subcategories(of: $0) } ?? []
    }
    private var parentCategoryID: UUID? {
        guard let id = categoryID else { return nil }
        return store.folders.first { $0.id == id }?.parentID
    }

    var body: some View {
        // Se calcula una sola vez por redibujado (antes se filtraba/ordenaba 3 veces).
        let visible = store.visibleProjects
        Group {
            if visible.isEmpty && subcats.isEmpty {
                emptyState
            } else {
                grid(visible)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .overlay {
            if areaTargeted, let id = categoryID, let cat = store.folders.first(where: { $0.id == id }) {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cat.color, style: StrokeStyle(lineWidth: 2.5, dash: [10, 6]))
                    .padding(8)
                    .overlay(alignment: .top) {
                        Text("Soltar en «\(cat.name)»")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(cat.color.opacity(0.9), in: .capsule)
                            .foregroundStyle(.white)
                            .padding(.top, 14)
                    }
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .dropDestination(for: String.self) { paths, _ in
            guard let id = categoryID else { return false }   // solo dentro de una categoría
            for p in paths { store.setCategory(p, id) }
            return !paths.isEmpty
        } isTargeted: { t in
            withAnimation(.snappy) { areaTargeted = t }
        }
    }

    private func grid(_ visible: [Project]) -> some View {
        ScrollView {
            if let parent = parentCategoryID {
                HStack {
                    CategoryBackButton(store: store, parentID: parent)
                    Spacer()
                }
                .padding(.horizontal, 24).padding(.top, 18)
            }

            if !subcats.isEmpty {
                subcategoriesSection.padding(.horizontal, 24).padding(.top, parentCategoryID == nil ? 20 : 12)
            }

            if visible.isEmpty {
                Text("No hay proyectos directamente en esta categoría.")
                    .font(.system(size: 12)).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24).padding(.top, 16)
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { idx, project in
                    ProjectCardView(project: project, store: store)
                        .appear(index: idx)
                }
            }
            .padding(24)

            if store.hiddenCount > 0 {
                Button {
                    store.restoreAllHidden()
                } label: {
                    Label(store.hiddenCount == 1 ? String(localized: "Restaurar \(store.hiddenCount) oculto") : String(localized: "Restaurar \(store.hiddenCount) ocultos"),
                          systemImage: "eye")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: Subcategorías (carpetas) dentro de una categoría

    private var subcategoriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Subcategorías", systemImage: "folder.fill")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 240), spacing: 12)], spacing: 12) {
                ForEach(subcats) { sub in
                    SubcategoryTile(sub: sub, store: store)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(emptyTitle, systemImage: emptySymbol)
        } description: {
            Text(emptyMessage)
        }
        .appear(index: 0)
    }

    private var emptyTitle: String {
        if !store.searchText.isEmpty { return String(localized: "Sin resultados") }
        switch store.nav {
        case .favorites:     return String(localized: "Sin favoritos")
        case .recents:       return String(localized: "Nada reciente")
        case .missing:       return String(localized: "Nada perdido")
        case .uncategorized: return String(localized: "Todo categorizado")
        case .category:      return String(localized: "Categoría vacía")
        default:             return String(localized: "Sin proyectos")
        }
    }

    private var emptySymbol: String {
        switch store.nav {
        case .favorites: return "star"
        case .recents:   return "clock"
        case .missing:   return "checkmark.circle"
        default:         return "tray"
        }
    }

    private var emptyMessage: String {
        if !store.searchText.isEmpty {
            return String(localized: "Ningún proyecto coincide con «\(store.searchText)».")
        }
        switch store.nav {
        case .favorites:     return String(localized: "Marcá proyectos con la estrella para verlos acá.")
        case .recents:       return String(localized: "Los proyectos que abras aparecerán acá.")
        case .missing:       return String(localized: "No hay proyectos cuya carpeta haya desaparecido.")
        case .uncategorized: return String(localized: "Asigná categorías desde el menú de cada proyecto.")
        case .category:      return String(localized: "Movés proyectos a esta categoría desde su menú.")
        default:             return String(localized: "Cargá proyectos con el botón +.")
        }
    }
}
