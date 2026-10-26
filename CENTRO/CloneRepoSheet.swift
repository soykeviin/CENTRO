//
//  CloneRepoSheet.swift
//  CENTRO
//
//  Clonar un repo de GitHub eligiendo nombre y ubicación (como crear proyecto).
//

import SwiftUI

struct CloneRepoSheet: View {
    @Bindable var store: ProjectStore
    let repo: GitHubRepo
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var parentPath = ""
    @State private var categoryID: UUID? = nil
    @State private var cloning = false
    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill").font(.system(size: 18)).foregroundStyle(Theme.accent)
                Text("Clonar repositorio").font(.system(size: 18, weight: .bold, design: .rounded))
            }
            Text(repo.nameWithOwner).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)

            field(String(localized: "Nombre de la carpeta")) {
                TextField(repo.name, text: $name)
                    .textFieldStyle(.plain).font(.system(size: 13))
                    .padding(.horizontal, 12).padding(.vertical, 9).liquidGlass(cornerRadius: 10)
                    .disabled(cloning)
            }

            field(String(localized: "Ubicación")) {
                HStack(spacing: 8) {
                    Text(parentPath.isEmpty ? String(localized: "Elegí dónde clonarlo…") :
                            parentPath.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(parentPath.isEmpty ? .tertiary : .primary)
                        .lineLimit(1).truncationMode(.head)
                    Spacer()
                    Button {
                        if let p = SystemActions.pickFolder(prompt: String(localized: "¿Dónde clonar «\(repo.name)»?")) { parentPath = p }
                    } label: { Label("Elegir", systemImage: "folder") }.buttonStyle(.glassy).disabled(cloning)
                }
                .padding(.horizontal, 12).padding(.vertical, 8).liquidGlass(cornerRadius: 10)
            }

            if !store.folders.isEmpty {
                field(String(localized: "Categoría")) {
                    Menu {
                        Button { categoryID = nil } label: {
                            Label("Sin categoría", systemImage: categoryID == nil ? "checkmark" : "minus")
                        }
                        ForEach(store.topCategories) { cat in categoryMenuItem(cat) }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "folder.fill").font(.system(size: 11)).foregroundStyle(currentCategoryColor)
                            Text(store.categoryName(categoryID) ?? String(localized: "Sin categoría")).font(.system(size: 13))
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9).liquidGlass(cornerRadius: 10)
                    }
                    .menuStyle(.button).buttonStyle(.plain)
                }
            }

            if let error {
                Text(error).font(.system(size: 11)).foregroundStyle(Theme.lilacGlow)
            }

            HStack(spacing: 10) {
                if cloning {
                    ProgressView().controlSize(.small)
                    Text("Clonando… puede tardar si el repo es grande")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancelar") { dismiss() }.buttonStyle(.glassy).disabled(cloning)
                Button { Task { await doClone() } } label: {
                    Label("Clonar", systemImage: "arrow.down")
                }
                .buttonStyle(.glassy(tint: Theme.accent, prominent: true))
                .disabled(cloning || parentPath.isEmpty || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24).frame(width: 460).background(Theme.background)
        .onAppear { if name.isEmpty { name = repo.name } }
    }

    @MainActor
    private func doClone() async {
        let folder = name.trimmingCharacters(in: .whitespaces)
        let dest = (parentPath as NSString).appendingPathComponent(folder)
        if FileManager.default.fileExists(atPath: dest) {
            error = String(localized: "Ya existe una carpeta «\(folder)» en esa ubicación.")
            return
        }
        cloning = true; error = nil
        let result = await GitHubService.clone(repo.nameWithOwner, toPath: dest)
        cloning = false
        switch result {
        case .success(let path):
            store.addSingleProject(path: path, name: folder, categoryID: categoryID)
            store.selectedProjectID = path     // abre el proyecto: muestra sus archivos
            dismiss()
        case .failure(let e):
            error = e.message
        }
    }

    private func categoryMenuItem(_ cat: VirtualFolder) -> AnyView {
        let subs = store.subcategories(of: cat.id)
        if subs.isEmpty {
            return AnyView(Button { categoryID = cat.id } label: {
                Label(cat.name, systemImage: categoryID == cat.id ? "checkmark" : cat.symbol)
            })
        } else {
            return AnyView(Menu(cat.name) {
                Button { categoryID = cat.id } label: {
                    Label("\(cat.name) (esta)", systemImage: categoryID == cat.id ? "checkmark" : "folder")
                }
                ForEach(subs) { sub in categoryMenuItem(sub) }
            })
        }
    }

    private var currentCategoryColor: Color {
        if let id = categoryID, let c = store.folders.first(where: { $0.id == id }) { return c.color }
        return .secondary
    }

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary).tracking(0.6)
            content()
        }
    }
}
