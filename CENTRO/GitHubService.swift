//
//  GitHubService.swift
//  CENTRO
//
//  Integración con GitHub mediante el CLI `gh`.
//

import Foundation

nonisolated struct GitHubRepo: Identifiable, Hashable, Decodable {
    var name: String
    var nameWithOwner: String
    var description: String?
    var isPrivate: Bool
    var url: String
    var updatedAt: String?
    var primaryLanguage: Lang?
    struct Lang: Hashable, Decodable { var name: String }

    var id: String { nameWithOwner }
    var language: String? { primaryLanguage?.name }
}

nonisolated struct GitHubError: Error { let message: String }

nonisolated enum GitHubService {

    enum Connection: Equatable {
        case notInstalled
        case notAuthenticated
        case connected(user: String)
    }

    // MARK: Estado

    static func connection() async -> Connection {
        await Task.detached(priority: .userInitiated) {
            guard run(["gh", "--version"]).status == 0 else { return .notInstalled }
            let user = run(["gh", "api", "user", "-q", ".login"])
            if user.status == 0 {
                let login = user.out.trimmingCharacters(in: .whitespacesAndNewlines)
                if !login.isEmpty { return .connected(user: login) }
            }
            return .notAuthenticated
        }.value
    }

    // MARK: Repos

    static func listRepos(limit: Int = 200) async -> [GitHubRepo] {
        await Task.detached(priority: .userInitiated) {
            let r = run(["gh", "repo", "list", "--limit", "\(limit)", "--json",
                         "name,nameWithOwner,description,isPrivate,url,updatedAt,primaryLanguage"])
            guard r.status == 0, let data = r.out.data(using: .utf8),
                  let repos = try? JSONDecoder().decode([GitHubRepo].self, from: data) else { return [] }
            return repos.sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") }
        }.value
    }

    // MARK: Acciones

    /// Clona un repo en la ruta destino exacta. Devuelve la ruta o un error.
    static func clone(_ nameWithOwner: String, toPath dest: String) async -> Result<String, GitHubError> {
        await Task.detached(priority: .userInitiated) {
            let r = run(["gh", "repo", "clone", nameWithOwner, dest])
            return r.status == 0 ? .success(dest) : .failure(GitHubError(message: combined(r)))
        }.value
    }

    /// Crea un repo en GitHub a partir de una carpeta local y hace push.
    static func createRepo(name: String, isPrivate: Bool, fromPath path: String) async -> Result<String, GitHubError> {
        await Task.detached(priority: .userInitiated) {
            // Asegurar repo git con al menos un commit.
            if !FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent(".git")) {
                _ = git(path, ["init"])
                _ = git(path, ["add", "-A"])
                _ = git(path, ["commit", "-m", "Initial commit"])
            } else if git(path, ["rev-parse", "HEAD"]).status != 0 {
                _ = git(path, ["add", "-A"])
                _ = git(path, ["commit", "-m", "Initial commit"])
            }
            let vis = isPrivate ? "--private" : "--public"
            let r = run(["gh", "repo", "create", name, vis, "--source", path, "--remote", "origin", "--push"])
            return r.status == 0 ? .success(combined(r)) : .failure(GitHubError(message: combined(r)))
        }.value
    }

    /// Cambia la visibilidad de un repo.
    static func setVisibility(_ nameWithOwner: String, isPrivate: Bool) async -> Result<Void, GitHubError> {
        await Task.detached(priority: .userInitiated) {
            let r = run(["gh", "repo", "edit", nameWithOwner, "--visibility", isPrivate ? "private" : "public",
                         "--accept-visibility-change-consequences"])
            return r.status == 0 ? .success(()) : .failure(GitHubError(message: combined(r)))
        }.value
    }

    // MARK: Device flow (login en el navegador, sin Terminal)

    /// Client ID público del GitHub CLI (device flow no usa secret).
    private static let clientID = "178c6fc778ccc68e1d6a"

    struct DeviceLogin { let deviceCode: String; let userCode: String; let verificationUri: String; let interval: Int }

    static func startDeviceFlow() async -> Result<DeviceLogin, GitHubError> {
        var req = URLRequest(url: URL(string: "https://github.com/login/device/code")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "client_id=\(clientID)&scope=repo%20read:org%20gist%20workflow".data(using: .utf8)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dc = j["device_code"] as? String,
                  let uc = j["user_code"] as? String,
                  let vu = j["verification_uri"] as? String else {
                return .failure(GitHubError(message: String(localized: "Respuesta inesperada de GitHub.")))
            }
            return .success(DeviceLogin(deviceCode: dc, userCode: uc, verificationUri: vu,
                                        interval: j["interval"] as? Int ?? 5))
        } catch { return .failure(GitHubError(message: error.localizedDescription)) }
    }

    /// Espera la autorización del usuario y devuelve el token.
    static func pollDeviceToken(_ login: DeviceLogin) async -> Result<String, GitHubError> {
        var interval = UInt64(max(login.interval, 5))
        for _ in 0..<60 {
            try? await Task.sleep(nanoseconds: interval * 1_000_000_000)
            var req = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            req.httpBody = "client_id=\(clientID)&device_code=\(login.deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code".data(using: .utf8)
            guard let (data, _) = try? await URLSession.shared.data(for: req),
                  let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let token = j["access_token"] as? String { return .success(token) }
            if let err = j["error"] as? String {
                switch err {
                case "authorization_pending": continue
                case "slow_down": interval += 5
                case "expired_token": return .failure(GitHubError(message: String(localized: "El código expiró, probá de nuevo.")))
                case "access_denied": return .failure(GitHubError(message: String(localized: "Autorización cancelada.")))
                default: continue
                }
            }
        }
        return .failure(GitHubError(message: String(localized: "Se agotó el tiempo de espera.")))
    }

    /// Login con un token classic (PAT). Se pasa por stdin a `gh auth login --with-token`.
    static func loginWithToken(_ token: String) async -> Result<Void, GitHubError> {
        await Task.detached(priority: .userInitiated) {
            let r = run(["gh", "auth", "login", "--hostname", "github.com",
                         "--git-protocol", "https", "--with-token"],
                        stdin: token.trimmingCharacters(in: .whitespacesAndNewlines) + "\n")
            return r.status == 0 ? .success(()) : .failure(GitHubError(message: combined(r)))
        }.value
    }

    // MARK: Procesos

    private static func combined(_ r: (status: Int32, out: String, err: String)) -> String {
        (r.out + r.err).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func git(_ cwd: String, _ args: [String]) -> (status: Int32, out: String, err: String) {
        run(["git", "-C", cwd] + args)
    }

    private static func run(_ args: [String], stdin: String? = nil) -> (status: Int32, out: String, err: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "/usr/bin:/bin")
        p.environment = env
        let out = Pipe(); let err = Pipe()
        p.standardOutput = out; p.standardError = err
        if let stdin {
            let inPipe = Pipe()
            p.standardInput = inPipe
            do { try p.run() } catch { return (127, "", String(localized: "no se pudo ejecutar")) }
            inPipe.fileHandleForWriting.write(stdin.data(using: .utf8) ?? Data())
            inPipe.fileHandleForWriting.closeFile()
            let o = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            p.waitUntilExit()
            return (p.terminationStatus, o, e)
        }
        do { try p.run() } catch { return (127, "", String(localized: "no se pudo ejecutar")) }
        let o = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()
        return (p.terminationStatus, o, e)
    }
}
