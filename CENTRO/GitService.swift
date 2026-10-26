//
//  GitService.swift
//  CENTRO
//
//  Operaciones de git para el panel: estado, ramas, commit, push, pull.
//

import Foundation

nonisolated enum GitService {

    struct FileChange: Identifiable, Hashable {
        var path: String
        var staged: Bool
        var code: String          // XY de git status --porcelain
        var id: String { path }
        var label: String {
            switch code.trimmingCharacters(in: .whitespaces).prefix(1) {
            case "M": return String(localized: "Modificado")
            case "A": return String(localized: "Agregado")
            case "D": return String(localized: "Borrado")
            case "R": return String(localized: "Renombrado")
            case "?": return String(localized: "Nuevo")
            default:  return String(localized: "Cambiado")
            }
        }
        var symbol: String {
            switch code.trimmingCharacters(in: .whitespaces).prefix(1) {
            case "M": return "pencil"
            case "A": return "plus"
            case "D": return "minus"
            case "?": return "questionmark"
            default:  return "circle"
            }
        }
    }

    struct Status {
        var branch: String = ""
        var ahead: Int = 0
        var behind: Int = 0
        var changes: [FileChange] = []
        var branches: [String] = []
        var remoteUrl: String = ""
        var hasRemote: Bool { !remoteUrl.isEmpty }
    }

    static func status(at path: String) async -> Status {
        await Task.detached(priority: .userInitiated) {
            var st = Status()
            st.branch = git(path, ["rev-parse", "--abbrev-ref", "HEAD"])?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if let counts = git(path, ["rev-list", "--left-right", "--count", "HEAD...@{u}"]) {
                let parts = counts.split(whereSeparator: { $0 == "\t" || $0 == " " })
                if parts.count == 2 { st.ahead = Int(parts[0]) ?? 0; st.behind = Int(parts[1]) ?? 0 }
            }

            if let porcelain = git(path, ["status", "--porcelain"]) {
                st.changes = porcelain.split(separator: "\n").compactMap { line in
                    let s = String(line)
                    guard s.count > 3 else { return nil }
                    let code = String(s.prefix(2))
                    let file = String(s.dropFirst(3))
                    let staged = code.first != " " && code.first != "?"
                    return FileChange(path: file, staged: staged, code: code)
                }
            }

            if let branches = git(path, ["branch", "--format=%(refname:short)"]) {
                st.branches = branches.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
            }
            st.remoteUrl = git(path, ["remote", "get-url", "origin"])?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return st
        }.value
    }

    @discardableResult
    static func commitAll(at path: String, message: String) async -> String? {
        _ = git(path, ["add", "-A"])
        return run(path, ["commit", "-m", message])
    }

    @discardableResult
    static func push(at path: String) async -> String? { run(path, ["push"]) }
    @discardableResult
    static func pull(at path: String) async -> String? { run(path, ["pull"]) }
    @discardableResult
    static func checkout(at path: String, branch: String) async -> String? { run(path, ["checkout", branch]) }

    /// URL del remoto `origin` (o nil si no hay / no es git).
    static func remoteURL(at path: String) async -> String? {
        await Task.detached(priority: .utility) {
            let r = exec(path, ["remote", "get-url", "origin"])
            let s = r.status == 0 ? r.out.trimmingCharacters(in: .whitespacesAndNewlines) : ""
            return s.isEmpty ? nil : s
        }.value
    }

    /// Convierte una URL de git en URL web de GitHub.
    static func webURL(from remote: String) -> String {
        var s = remote
        if s.hasPrefix("git@github.com:") { s = "https://github.com/" + s.dropFirst("git@github.com:".count) }
        if s.hasSuffix(".git") { s = String(s.dropLast(4)) }
        return s
    }

    // MARK: Procesos

    private static func git(_ cwd: String, _ args: [String]) -> String? {
        let r = exec(cwd, args)
        return r.status == 0 ? r.out : nil
    }
    /// Devuelve stdout+stderr (para mostrar resultado de push/pull/commit).
    private static func run(_ cwd: String, _ args: [String]) -> String? {
        let r = exec(cwd, args)
        let combined = (r.out + r.err).trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? nil : combined
    }

    private static func exec(_ cwd: String, _ args: [String]) -> (status: Int32, out: String, err: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = ["-C", cwd] + args
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "/usr/bin:/bin")
        p.environment = env
        let out = Pipe(); let err = Pipe()
        p.standardOutput = out; p.standardError = err
        do { try p.run() } catch { return (1, "", "") }
        let o = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()
        return (p.terminationStatus, o, e)
    }
}
