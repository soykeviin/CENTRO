//
//  DevServerManager.swift
//  CENTRO
//
//  Arranca/detiene el dev server de un proyecto dentro de la app y captura su log.
//

import Foundation
import Observation

@Observable
final class DevServerManager {
    struct Info { var running = false; var log = "" }
    var info: [String: Info] = [:]
    @ObservationIgnored private var processes: [String: Process] = [:]

    func isRunning(_ path: String) -> Bool { info[path]?.running ?? false }
    func log(_ path: String) -> String { info[path]?.log ?? "" }

    func toggle(path: String, command: String) {
        if isRunning(path) { stop(path: path) } else { start(path: path, command: command) }
    }

    func start(path: String, command: String) {
        stop(path: path)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-lc", "cd \"\(path)\" && \(command)"]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "/usr/bin:/bin")
        env["FORCE_COLOR"] = "0"
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe

        info[path] = Info(running: true, log: "$ \(command)\n")

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.append(path, s) }
        }
        p.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.info[path]?.running = false
                self?.append(path, "\n" + String(localized: "— proceso finalizado —") + "\n")
                self?.processes[path] = nil
            }
        }
        do { try p.run(); processes[path] = p }
        catch { info[path]?.running = false; append(path, String(localized: "✗ No se pudo iniciar") + "\n") }
    }

    func stop(path: String) {
        if let p = processes[path], p.isRunning {
            // terminar el árbol de procesos (npm suele crear hijos)
            kill(-p.processIdentifier, SIGTERM)
            p.terminate()
        }
        processes[path] = nil
        info[path]?.running = false
    }

    func clearLog(_ path: String) { info[path]?.log = "" }

    private func append(_ path: String, _ s: String) {
        var i = info[path] ?? Info()
        i.log += s
        if i.log.count > 24_000 { i.log = "…\n" + String(i.log.suffix(20_000)) }
        info[path] = i
    }
}
