//
//  GitPanel.swift
//  CENTRO
//
//  Panel de git dentro del detalle del proyecto.
//

import SwiftUI

struct GitPanel: View {
    let path: String
    @State private var status = GitService.Status()
    @State private var loading = true
    @State private var commitMessage = ""
    @State private var busy = false
    @State private var result: String? = nil
    @State private var showPublish = false
    @State private var pubName = ""
    @State private var pubPrivate = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if showPublish { publishBox }
            if loading {
                loadingRow(String(localized: "Leyendo estado de git…"))
            } else {
                if status.changes.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        Text("Sin cambios sin commitear").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    changesList
                    commitBox
                }
                if let result {
                    Text(result).font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary).lineLimit(3)
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.3), in: .rect(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 14)
        .task(id: path) { await reload() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            // Selector de rama
            Menu {
                ForEach(status.branches, id: \.self) { b in
                    Button { Task { await op { await GitService.checkout(at: path, branch: b) } } } label: {
                        Label(b, systemImage: b == status.branch ? "checkmark" : "arrow.triangle.branch")
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.branch").font(.system(size: 10))
                    Text(status.branch.isEmpty ? "—" : status.branch)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 8))
                }
                .foregroundStyle(Theme.accentSoft)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Theme.accent.opacity(0.14), in: .capsule)
            }
            .menuStyle(.button).buttonStyle(.plain).fixedSize()

            if status.ahead > 0 { tag("↑\(status.ahead)", .green) }
            if status.behind > 0 { tag("↓\(status.behind)", .orange) }

            Spacer()

            if status.hasRemote {
                Button { Task { await op { await GitService.pull(at: path) } } } label: {
                    Label("Pull", systemImage: "arrow.down")
                }.buttonStyle(.glassy).disabled(busy)
                Button { Task { await op { await GitService.push(at: path) } } } label: {
                    Label("Push", systemImage: "arrow.up")
                }.buttonStyle(.glassy(tint: Theme.accent, prominent: status.ahead > 0)).disabled(busy)
            } else {
                Button {
                    pubName = (path as NSString).lastPathComponent
                    showPublish = true
                } label: { Label("Publicar en GitHub", systemImage: "cloud.fill") }
                    .buttonStyle(.glassy(tint: Theme.accent, prominent: true)).disabled(busy)
            }
            if busy { ProgressView().controlSize(.small) }
        }
    }

    private var publishBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Crear repositorio en GitHub").font(.system(size: 12, weight: .bold))
            HStack(spacing: 8) {
                TextField("Nombre del repo", text: $pubName)
                    .textFieldStyle(.plain).font(.system(size: 12))
                    .padding(.horizontal, 10).padding(.vertical, 7).liquidGlass(cornerRadius: 9)
                Toggle(isOn: $pubPrivate) {
                    Label("Privado", systemImage: pubPrivate ? "lock.fill" : "globe").font(.system(size: 11))
                }.toggleStyle(.button).buttonStyle(.glassy)
                Button {
                    let name = pubName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    showPublish = false
                    Task { await op { (try? await GitHubService.createRepo(name: name, isPrivate: pubPrivate, fromPath: path).get()).map { $0 } ?? String(localized: "✗ No se pudo crear el repo") } }
                } label: { Label("Crear y subir", systemImage: "checkmark") }
                    .buttonStyle(.glassy(tint: Theme.accent, prominent: true))
                Button { showPublish = false } label: { Image(systemName: "xmark") }.buttonStyle(.glassy)
            }
        }
        .padding(12).background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: 11))
    }

    private var changesList: some View {
        VStack(spacing: 3) {
            ForEach(status.changes.prefix(8)) { change in
                HStack(spacing: 8) {
                    Image(systemName: change.symbol).font(.system(size: 10, weight: .bold))
                        .foregroundStyle(change.staged ? AnyShapeStyle(.green) : AnyShapeStyle(Theme.lilacGlow))
                        .frame(width: 14)
                    Text(change.path).font(.system(size: 11.5, design: .monospaced)).lineLimit(1)
                    Spacer()
                    Text(change.label).font(.system(size: 9.5)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
            }
            if status.changes.count > 8 {
                Text("+\(status.changes.count - 8) más").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
    }

    private var commitBox: some View {
        HStack(spacing: 8) {
            TextField("Mensaje del commit…", text: $commitMessage)
                .textFieldStyle(.plain).font(.system(size: 12))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .liquidGlass(cornerRadius: 9)
                .onSubmit { doCommit() }
            Button { doCommit() } label: {
                Label("Commit", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.glassy(tint: Theme.accent, prominent: true))
            .disabled(busy || commitMessage.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func tag(_ t: String, _ c: Color) -> some View {
        Text(t).font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(c).padding(.horizontal, 6).padding(.vertical, 3)
            .background(c.opacity(0.18), in: .capsule)
    }

    private func doCommit() {
        let msg = commitMessage.trimmingCharacters(in: .whitespaces)
        guard !msg.isEmpty else { return }
        Task { await op { await GitService.commitAll(at: path, message: msg) }; commitMessage = "" }
    }

    private func op(_ action: @escaping () async -> String?) async {
        busy = true
        let r = await action()
        result = r
        await reload()
        busy = false
    }

    private func reload() async {
        loading = status.branch.isEmpty
        status = await GitService.status(at: path)
        loading = false
    }
}
