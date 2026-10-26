//
//  PortDetector.swift
//  CENTRO
//
//  Detecta en qué puerto(s) local(es) está corriendo un proyecto (vía lsof).
//

import Foundation

nonisolated enum PortDetector {

    /// Devuelve un mapa rutaDeProyecto -> [puertos] de procesos en escucha
    /// cuyo directorio de trabajo está dentro de ese proyecto.
    static func runningPorts(forProjectPaths paths: [String]) async -> [String: [Int]] {
        await Task.detached(priority: .utility) {
            // 1) Puertos en escucha + PID
            guard let listen = run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpn"]) else { return [:] }
            var portsByPid: [String: Set<Int>] = [:]
            var pid = ""
            for line in listen.split(separator: "\n") {
                let s = String(line)
                if s.hasPrefix("p") { pid = String(s.dropFirst()) }
                else if s.hasPrefix("n"), let port = portFromName(String(s.dropFirst())) {
                    portsByPid[pid, default: []].insert(port)
                }
            }
            guard !portsByPid.isEmpty else { return [:] }

            // 2) Directorio de trabajo de esos PIDs
            let pids = Array(portsByPid.keys)
            guard let cwdOut = run("/usr/sbin/lsof", ["-a", "-d", "cwd", "-p", pids.joined(separator: ","), "-Fn"]) else { return [:] }
            var cwdByPid: [String: String] = [:]
            var cur = ""
            for line in cwdOut.split(separator: "\n") {
                let s = String(line)
                if s.hasPrefix("p") { cur = String(s.dropFirst()) }
                else if s.hasPrefix("n") { cwdByPid[cur] = String(s.dropFirst()) }
            }

            // 3) Asociar puertos al proyecto cuyo path contiene el cwd
            var result: [String: Set<Int>] = [:]
            for (pid, ports) in portsByPid {
                guard let cwd = cwdByPid[pid] else { continue }
                // proyecto más específico (path más largo) que sea ancestro del cwd
                let match = paths
                    .filter { cwd == $0 || cwd.hasPrefix($0 + "/") }
                    .max(by: { $0.count < $1.count })
                if let match { result[match, default: []].formUnion(ports) }
            }
            return result.mapValues { $0.sorted() }
        }.value
    }

    private static func portFromName(_ name: String) -> Int? {
        // formatos: *:3000  127.0.0.1:5173  [::1]:3000
        guard let idx = name.lastIndex(of: ":") else { return nil }
        return Int(name[name.index(after: idx)...])
    }

    private static func run(_ launch: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launch)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
