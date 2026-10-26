//
//  Insights.swift
//  CENTRO
//
//  Cálculos para Actividad, Daily digest y Deps desactualizadas (git / npm).
//

import Foundation

nonisolated enum Insights {

    // MARK: - Actividad (commits por proyecto, último año)

    static func activity(for projects: [Project]) async -> [ProjectActivity] {
        let out = await bounded(projects.filter { $0.exists && $0.git.isGit }) { activityOne($0) }
        return out.compactMap { $0 }.sorted { $0.totalCommits > $1.totalCommits }
    }

    private static func activityOne(_ p: Project) -> ProjectActivity? {
        let dates = git(p.path, ["log", "--since=1.year", "--format=%ad", "--date=short"])?
            .split(separator: "\n").map(String.init) ?? []
        guard !dates.isEmpty else { return nil }
        var byDay: [String: Int] = [:]
        for d in dates { byDay[d, default: 0] += 1 }

        let recentRaw = git(p.path, ["log", "--since=30.days.ago", "--format=%ad\u{1f}%s", "--date=short", "-n", "8"]) ?? ""
        let recent = recentRaw.split(separator: "\n").compactMap { line -> (String, String)? in
            let parts = line.components(separatedBy: "\u{1f}")
            guard parts.count == 2 else { return nil }
            return (parts[0], parts[1])
        }
        return ProjectActivity(projectPath: p.path, projectName: p.displayName,
                               totalCommits: dates.count, byDay: byDay, recent: recent)
    }

    // MARK: - Daily digest (commits de hoy con stats)

    struct DigestCommit: Identifiable, Hashable {
        var id = UUID()
        var projectName: String
        var subject: String
        var files: Int
        var insertions: Int
        var deletions: Int
    }

    static func digestToday(for projects: [Project]) async -> [DigestCommit] {
        await bounded(projects.filter { $0.exists && $0.git.isGit }) { digestOne($0) }.flatMap { $0 }
    }

    private static func digestOne(_ p: Project) -> [DigestCommit] {
        guard let raw = git(p.path, ["log", "--since=midnight", "--format=%h\u{1f}%s", "--shortstat"]) else { return [] }
        var commits: [DigestCommit] = []
        var pending: DigestCommit?
        for line in raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.contains("\u{1f}") {
                if let c = pending { commits.append(c) }
                let parts = line.components(separatedBy: "\u{1f}")
                pending = DigestCommit(projectName: p.displayName,
                                       subject: parts.count > 1 ? parts[1] : "",
                                       files: 0, insertions: 0, deletions: 0)
            } else if line.contains("changed"), pending != nil {
                pending?.files = firstInt(in: line, suffix: "file")
                pending?.insertions = firstInt(in: line, suffix: "insertion")
                pending?.deletions = firstInt(in: line, suffix: "deletion")
            }
        }
        if let c = pending { commits.append(c) }
        return commits
    }

    private static func firstInt(in line: String, suffix: String) -> Int {
        // busca "<n> <suffix>"
        let tokens = line.split(whereSeparator: { $0 == " " || $0 == "," })
        for (i, t) in tokens.enumerated() where t.hasPrefix(suffix) {
            if i > 0, let n = Int(tokens[i - 1]) { return n }
        }
        return 0
    }

    // MARK: - Deps desactualizadas (npm outdated)

    static func outdated(for projects: [Project]) async -> [(project: Project, deps: [OutdatedDep])] {
        let out = await bounded(projects.filter { $0.exists && hasPackageJSON($0.path) }, limit: 3) {
            (project: $0, deps: npmOutdated($0.path))
        }
        return out.filter { !$0.deps.isEmpty }.sorted { $0.deps.count > $1.deps.count }
    }

    private static func hasPackageJSON(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent("package.json"))
    }

    private static func npmOutdated(_ path: String) -> [OutdatedDep] {
        // npm outdated sale con código 1 cuando hay desactualizadas; igual leemos stdout.
        guard let out = run("/usr/bin/env", ["npm", "outdated", "--json"], cwd: path),
              let data = out.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return json.compactMap { name, value in
            guard let info = value as? [String: Any] else { return nil }
            return OutdatedDep(
                name: name,
                current: info["current"] as? String ?? "—",
                wanted: info["wanted"] as? String ?? "—",
                latest: info["latest"] as? String ?? "—"
            )
        }
        .sorted { $0.name < $1.name }
    }

    // MARK: - Helpers de proceso

    /// Corre `work` sobre cada elemento con como mucho `limit` procesos a la vez.
    /// Antes se lanzaban ~200 git en paralelo: ocupaban todos los hilos y la app
    /// se trababa al cambiar de módulo. Si la vista se cierra, deja de lanzar más.
    private static func bounded<T, R>(_ items: [T], limit: Int = 4,
                                      _ work: @escaping @Sendable (T) -> R) async -> [R] {
        await withTaskGroup(of: R?.self) { group in
            var out: [R] = []
            var it = items.makeIterator()
            func next() -> Bool {
                guard !Task.isCancelled, let item = it.next() else { return false }
                group.addTask { Task.isCancelled ? nil : work(item) }
                return true
            }
            for _ in 0..<limit { if !next() { break } }
            for await r in group {
                if let r { out.append(r) }
                _ = next()
            }
            return out
        }
    }

    private static func git(_ cwd: String, _ args: [String]) -> String? {
        run("/usr/bin/git", ["-C", cwd] + args)
    }

    private static func run(_ launch: String, _ args: [String], cwd: String? = nil) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launch)
        p.arguments = args
        if let cwd { p.currentDirectoryURL = URL(fileURLWithPath: cwd) }
        // PATH ampliado para alcanzar npm cuando se lanza desde Finder
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "/usr/bin:/bin")
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
