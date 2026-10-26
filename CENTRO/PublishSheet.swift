//
//  PublishSheet.swift
//  CENTRO
//
//  Crear un repo nuevo en GitHub y subir todos los archivos del proyecto.
//

import SwiftUI

struct PublishSheet: View {
    @Bindable var store: ProjectStore
    let project: Project
    @Environment(\.dismiss) private var dismiss

    @State private var repoName = ""
    @State private var isPrivate = true
    @State private var busy = false
    @State private var error: String? = nil
    @State private var connected: Bool? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "cloud.fill").font(.system(size: 18)).foregroundStyle(Theme.accent)
                Text("Subir a GitHub").font(.system(size: 18, weight: .bold, design: .rounded))
            }

            if connected == false {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Primero conectá tu cuenta de GitHub.").font(.system(size: 12)).foregroundStyle(.secondary)
                    Button {
                        store.nav = .github; store.selectedProjectID = nil; dismiss()
                    } label: { Label("Ir a GitHub", systemImage: "arrow.up.forward") }
                        .buttonStyle(.glassy(tint: Theme.accent, prominent: true))
                }
            } else {
                Text("Se crea un repo nuevo y se sube todo el contenido de la carpeta.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)

                field(String(localized: "Nombre del repositorio")) {
                    TextField(project.name, text: $repoName)
                        .textFieldStyle(.plain).font(.system(size: 13))
                        .padding(.horizontal, 12).padding(.vertical, 9).liquidGlass(cornerRadius: 10)
                        .disabled(busy)
                }

                field(String(localized: "Visibilidad")) {
                    HStack(spacing: 10) {
                        visButton(title: "Privado", symbol: "lock.fill", selected: isPrivate) { isPrivate = true }
                        visButton(title: "Público", symbol: "globe", selected: !isPrivate) { isPrivate = false }
                        Spacer()
                    }
                }

                if let error {
                    Text(error).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.lilacGlow)
                        .lineLimit(3).textSelection(.enabled)
                }

                HStack(spacing: 10) {
                    if busy {
                        ProgressView().controlSize(.small)
                        Text("Creando repo y subiendo…").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Cancelar") { dismiss() }.buttonStyle(.glassy).disabled(busy)
                    Button { Task { await publish() } } label: {
                        Label("Crear y subir", systemImage: "arrow.up")
                    }
                    .buttonStyle(.glassy(tint: Theme.accent, prominent: true))
                    .disabled(busy || repoName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding(24).frame(width: 460).background(Theme.background)
        .task {
            repoName = project.name
            if case .connected = await GitHubService.connection() { connected = true } else { connected = false }
        }
    }

    private func visButton(title: LocalizedStringKey, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(selected ? Theme.accent.opacity(0.9) : .white.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Theme.accent : .white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain).disabled(busy)
    }

    @MainActor
    private func publish() async {
        busy = true; error = nil
        let name = repoName.trimmingCharacters(in: .whitespaces)
        let result = await GitHubService.createRepo(name: name, isPrivate: isPrivate, fromPath: project.path)
        busy = false
        switch result {
        case .success:
            dismiss()
        case .failure(let e):
            error = e.message
        }
    }

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary).tracking(0.6)
            content()
        }
    }
}
