//
//  AddMenu.swift
//  CENTRO
//
//  Menú "+" que se abre al pasar el cursor, con info por opción.
//

import SwiftUI

struct AddMenu: View {
    @Bindable var store: ProjectStore
    var onNew: () -> Void
    var onAddSingle: () -> Void
    var onAddFolder: () -> Void
    var onNewSubcategory: () -> Void

    @State private var open = false
    @State private var hoverButton = false
    @State private var expandedInfo: String? = nil

    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(hoverButton || open ? Theme.lilac : .white)
            .frame(width: 34, height: 34)
            .liquidGlass(cornerRadius: 10, interactive: true)
            .scaleEffect(hoverButton ? 1.06 : 1)
            .animation(.snappy, value: hoverButton)
            .onHover { h in hoverButton = h }
            .onTapGesture { open = true }            // se abre solo con click
            .popover(isPresented: $open, arrowEdge: .bottom) { panel }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let id = store.currentCategoryID, let cat = store.folders.first(where: { $0.id == id }) {
                Text("Se agregará a «\(cat.name)»")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.accentSoft)
                    .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 2)

                option(
                    id: "subcat", icon: "folder.badge.plus", title: "Crear subcategoría",
                    info: "Crea una subcategoría dentro de «\(cat.name)». Después podés agregar proyectos dentro de ella, igual que en una categoría.",
                    action: onNewSubcategory
                )
                Divider().padding(.vertical, 4)
            }

            option(
                id: "existing", icon: "folder.badge.plus", title: "Agregar proyecto existente",
                info: "Elegís una carpeta que ya existe en tu Mac. Se agrega como un solo proyecto sin mover ni copiar archivos — CENTRO solo guarda la ruta.",
                action: onAddSingle
            )
            option(
                id: "folder", icon: "folder.fill.badge.plus", title: "Cargar carpeta de proyectos",
                info: "Elegís una carpeta que contiene varios proyectos. Cada subcarpeta se agrega como un proyecto. Si estás dentro de una categoría, todos van a esa categoría.",
                action: onAddFolder
            )

            if store.excludedCount > 0 {
                Divider().padding(.vertical, 4)
                Button {
                    store.restoreExcluded(); open = false
                } label: {
                    Label(store.excludedCount == 1 ? String(localized: "Restaurar \(store.excludedCount) quitado") : String(localized: "Restaurar \(store.excludedCount) quitados"),
                          systemImage: "arrow.uturn.left")
                        .font(.system(size: 12.5, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .frame(width: 330)
    }

    @ViewBuilder
    private func option(id: String, icon: String, title: LocalizedStringKey, info: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    action(); open = false
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.accent).frame(width: 20)
                        Text(title).font(.system(size: 12.5, weight: .medium))
                        Spacer(minLength: 4)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.snappy) { expandedInfo = (expandedInfo == id) ? nil : id }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(expandedInfo == id ? AnyShapeStyle(Theme.lilac) : AnyShapeStyle(.secondary))
                }
                .buttonStyle(.plain)
                .help("Qué hace esta opción")
            }
            .padding(.horizontal, 12).padding(.vertical, 9)

            if expandedInfo == id {
                Text(info)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12).padding(.bottom, 10).padding(.top, -2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(expandedInfo == id ? AnyShapeStyle(Theme.accent.opacity(0.06)) : AnyShapeStyle(.clear))
    }
}
