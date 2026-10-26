//
//  GitInspector.swift
//  CENTRO
//
//  Lee el estado de git de un proyecto. Port de server/src/lib/git-info.ts
//

import Foundation

nonisolated enum GitInspector {

    static func inspect(at path: String) -> GitInfo {
        var info = GitInfo()
        let gitDir = (path as NSString).appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir) else { return info }
        info.isGit = true

        // Rama actual
        if let branch = git(path, ["rev-parse", "--abbrev-ref", "HEAD"])?
            .trimmingCharacters(in: .whitespacesAndNewlines), !branch.isEmpty {
            info.branch = branch
        }

        // Cambios sin commitear
        if let status = git(path, ["status", "--porcelain"]) {
            info.dirty = !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        // Ahead / behind respecto al upstream
        if let counts = git(path, ["rev-list", "--left-right", "--count", "HEAD...@{u}"]) {
            let parts = counts.split(whereSeparator: { $0 == "\t" || $0 == " " })
            if parts.count == 2 {
                info.ahead = Int(parts[0]) ?? 0
                info.behind = Int(parts[1]) ?? 0
            }
        }

        // Último commit
        if let subject = git(path, ["log", "-1", "--pretty=%s"])?
            .trimmingCharacters(in: .whitespacesAndNewlines), !subject.isEmpty {
            info.lastCommitSubject = subject
        }
        if let rel = git(path, ["log", "-1", "--pretty=%cr"])?
            .trimmingCharacters(in: .whitespacesAndNewlines), !rel.isEmpty {
            info.lastCommitRelative = rel
        }

        return info
    }

    private static func git(_ cwd: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = ["-C", cwd] + args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
