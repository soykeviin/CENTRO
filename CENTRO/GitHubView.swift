//
//  GitHubView.swift
//  CENTRO
//
//  Conectar GitHub, ver repos y clonarlos como proyectos.
//

import SwiftUI

struct GitHubView: View {
    @Bindable var store: ProjectStore
    @State private var connection: GitHubService.Connection? = nil
    @State private var repos: [GitHubRepo] = []
    @State private var loading = true
    @State private var search = ""
    @State private var cloneTarget: GitHubRepo? = nil
    @State private var banner: String? = nil
    @State private var showToken = false
    @State private var token = ""
    @State private var tokenBusy = false
    @State private var device: GitHubService.DeviceLogin? = nil
    @State private var deviceBusy = false
    @State private var copied = false

    private var filtered: [GitHubRepo] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return repos }
        return repos.filter { $0.nameWithOwner.lowercased().contains(q) || ($0.description ?? "").lowercased().contains(q) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch connection {
                case .none:
                    loadingRow(String(localized: "Verificando GitHub…"))
                case .notInstalled:
                    notInstalled
                case .notAuthenticated:
                    notAuthenticated
                case .connected(let user):
                    connectedHeader(user)
                    if let banner { Text(banner).font(.system(size: 11)).foregroundStyle(Theme.accentSoft) }
                    if loading { loadingRow(String(localized: "Cargando repositorios…")) }
                    else if filtered.isEmpty {
                        Text("Sin repositorios.").font(.system(size: 12)).foregroundStyle(.tertiary)
                    } else {
                        ForEach(filtered) { repo in repoRow(repo) }
                    }
                }
                Spacer(minLength: 20)
            }
            .padding(28).frame(maxWidth: 820, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .task { await reload() }
        .sheet(item: $cloneTarget) { repo in
            CloneRepoSheet(store: store, repo: repo)
        }
    }

    // MARK: Estados de conexión

    private var notInstalled: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("GitHub CLI no está instalado", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.lilacGlow)
            Text("CENTRO usa el CLI oficial de GitHub (`gh`). Instalalo y volvé a entrar:")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Text("brew install gh").font(.system(size: 12, design: .monospaced))
                .padding(10).background(.black.opacity(0.4), in: .rect(cornerRadius: 8)).textSelection(.enabled)
            Button { Task { await reload() } } label: { Label("Reintentar", systemImage: "arrow.clockwise") }
                .buttonStyle(.glassy)
        }
        .padding(18).liquidGlass(cornerRadius: 16)
    }

    private var notAuthenticated: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Conectá tu cuenta de GitHub", systemImage: "person.crop.circle.badge.plus")
                .font(.system(size: 15, weight: .bold))

            HStack(spacing: 10) {
                Button { Task { await startBrowserLogin() } } label: {
                    Label("Con el navegador", systemImage: "safari.fill")
                }.buttonStyle(.glassy(tint: Theme.accent, prominent: true)).disabled(deviceBusy)

                Button { withAnimation(.snappy) { showToken.toggle() } } label: {
                    Label("Con token classic", systemImage: "key.fill")
                }.buttonStyle(.glassy)
            }

            if let device { deviceCodePanel(device) }

            if showToken {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pegá un token classic con scope **repo** (y read:org).")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        SecureField("ghp_…", text: $token)
                            .textFieldStyle(.plain).font(.system(size: 12, design: .monospaced))
                            .padding(.horizontal, 10).padding(.vertical, 8).liquidGlass(cornerRadius: 9)
                        if tokenBusy { ProgressView().controlSize(.small) }
                        Button { Task { await connectToken() } } label: { Label("Conectar", systemImage: "arrow.right") }
                            .buttonStyle(.glassy(tint: Theme.accent, prominent: true))
                            .disabled(tokenBusy || token.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Button { SystemActions.openURL("https://github.com/settings/tokens/new?scopes=repo,read:org&description=CENTRO") } label: {
                        Label("Crear un token classic en GitHub", systemImage: "arrow.up.forward")
                            .font(.system(size: 11)).foregroundStyle(Theme.accentSoft)
                    }.buttonStyle(.plain)
                }
                .padding(12).background(Theme.accent.opacity(0.06), in: .rect(cornerRadius: 11))
            }

            if let banner { Text(banner).font(.system(size: 11)).foregroundStyle(Theme.lilacGlow) }
        }
        .padding(18).liquidGlass(cornerRadius: 16)
    }

    private func deviceCodePanel(_ d: GitHubService.DeviceLogin) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Se abrió una pestaña del navegador. Pegá este código y autorizá:")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Text(d.userCode)
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Theme.accent)
                Button {
                    SystemActions.copyToClipboard(d.userCode)
                    withAnimation(.snappy) { copied = true }
                } label: {
                    Label(copied ? String(localized: "Copiado") : String(localized: "Copiar"), systemImage: copied ? "checkmark" : "doc.on.doc")
                }.buttonStyle(.glassy)
                Button { SystemActions.openURL(d.verificationUri) } label: {
                    Label("Abrir de nuevo", systemImage: "safari")
                }.buttonStyle(.glassy)
                Spacer()
                ProgressView().controlSize(.small)
                Text("Esperando…").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
        .padding(14).background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: 12))
    }

    @MainActor
    private func startBrowserLogin() async {
        deviceBusy = true; banner = nil; copied = false
        let start = await GitHubService.startDeviceFlow()
        switch start {
        case .failure(let e):
            deviceBusy = false; banner = "✗ \(e.message)"
        case .success(let d):
            device = d
            SystemActions.copyToClipboard(d.userCode)   // lo dejo listo para pegar
            SystemActions.openURL(d.verificationUri)     // abre la pestaña del navegador
            let tokenResult = await GitHubService.pollDeviceToken(d)
            switch tokenResult {
            case .failure(let e):
                banner = "✗ \(e.message)"; device = nil; deviceBusy = false
            case .success(let token):
                _ = await GitHubService.loginWithToken(token)   // deja gh autenticado
                device = nil; deviceBusy = false
                await reload()
            }
        }
    }

    @MainActor
    private func connectToken() async {
        tokenBusy = true
        let result = await GitHubService.loginWithToken(token)
        tokenBusy = false
        switch result {
        case .success:
            token = ""; banner = nil
            await reload()
        case .failure(let e):
            banner = "✗ \(e.message)"
        }
    }

    private func connectedHeader(_ user: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text("Conectado como ").font(.system(size: 13)).foregroundStyle(.secondary)
                + Text("@\(user)").font(.system(size: 13, weight: .bold))
                Spacer()
                Button { Task { await reload() } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.glassy)
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.secondary)
                TextField("Buscar repositorios…", text: $search).textFieldStyle(.plain).font(.system(size: 13))
            }
            .padding(.horizontal, 12).padding(.vertical, 9).liquidGlass(cornerRadius: 11)
        }
    }

    // MARK: Repo

    private func repoRow(_ repo: GitHubRepo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: repo.isPrivate ? "lock.fill" : "globe")
                .font(.system(size: 13)).foregroundStyle(repo.isPrivate ? AnyShapeStyle(Theme.lilacGlow) : AnyShapeStyle(.secondary))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(repo.name).font(.system(size: 13.5, weight: .semibold))
                    Text(repo.isPrivate ? String(localized: "privado") : String(localized: "público")).font(.system(size: 9))
                        .foregroundStyle(.tertiary).padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.white.opacity(0.06), in: .capsule)
                    if let lang = repo.language {
                        Text(lang).font(.system(size: 9)).foregroundStyle(Theme.accentSoft)
                    }
                }
                if let d = repo.description, !d.isEmpty {
                    Text(d).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Button { cloneTarget = repo } label: {
                Label("Clonar", systemImage: "arrow.down.circle")
            }.buttonStyle(.glassy)
            Button { SystemActions.openURL(repo.url) } label: {
                Image(systemName: "arrow.up.forward").font(.system(size: 11)).foregroundStyle(.tertiary)
            }.buttonStyle(.plain).help("Abrir en GitHub")
        }
        .padding(.horizontal, 14).padding(.vertical, 11).liquidGlass(cornerRadius: 12)
    }

    // MARK: Acciones

    private func reload() async {
        connection = await GitHubService.connection()
        if case .connected = connection {
            loading = true
            repos = await GitHubService.listRepos()
            loading = false
        }
    }

}
