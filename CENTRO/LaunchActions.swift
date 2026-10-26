//
//  LaunchActions.swift
//  CENTRO
//
//  Acciones para abrir un proyecto (Finder, Terminal, Claude Code, editores…)
//  y las preferencias de qué acciones aparecen en las tarjetas y en la lupa
//  de la barra de menú. Se guardan en prefs.json, aparte de los datos de proyectos.
//

import SwiftUI

// MARK: - Acción

/// Identificador estable de una acción. Las integradas usan su nombre;
/// las personalizadas usan "custom:<uuid>" (ver Configuración → Acciones personalizadas).
struct LaunchAction: Identifiable, Hashable {
    let id: String
    let name: String
    var subtitle: String? = nil
    var symbol: String? = nil
    var asset: String? = nil

    static let finder      = LaunchAction(id: "finder", name: String(localized: "Abrir carpeta"), subtitle: String(localized: "Mostrar en Finder"), symbol: "folder.fill")
    static let terminal    = LaunchAction(id: "terminal", name: "Terminal", subtitle: String(localized: "Terminal en la carpeta"), symbol: "terminal.fill")
    static let claudeCode  = LaunchAction(id: "claudeCode", name: "Claude Code", subtitle: String(localized: "Terminal con Claude iniciado"), asset: "Icon_claude")
    static let centro      = LaunchAction(id: "centro", name: String(localized: "Abrir en CENTRO"), subtitle: String(localized: "Ver el proyecto en CENTRO"), symbol: "square.grid.2x2.fill")
    static let cursor      = LaunchAction(id: "cursor", name: "Cursor", asset: "Icon_cursor")
    static let vscode      = LaunchAction(id: "vscode", name: "VS Code", asset: "Icon_vscode")
    static let antigravity = LaunchAction(id: "antigravity", name: "Antigravity", asset: "Icon_antigravity")
    static let claudeApp   = LaunchAction(id: "claudeApp", name: String(localized: "App de Claude"), subtitle: String(localized: "Abrir la app de Claude"), asset: "Icon_claude")

    static let builtIn: [LaunchAction] = [.finder, .terminal, .claudeCode, .centro, .cursor, .vscode, .antigravity, .claudeApp]

    /// Todas las acciones disponibles (integradas + personalizadas del usuario).
    static func all(custom: [CustomAction]) -> [LaunchAction] {
        builtIn + custom.map {
            LaunchAction(id: "custom:\($0.id.uuidString)", name: $0.label, subtitle: $0.command, symbol: $0.symbol)
        }
    }

    static func resolve(_ ids: [String], custom: [CustomAction]) -> [LaunchAction] {
        let all = all(custom: custom)
        return ids.compactMap { id in all.first { $0.id == id } }
    }
}

extension ProjectStore {
    /// Ejecuta una acción sobre un proyecto. `openInCentro` se encarga de traer la ventana.
    func perform(_ action: LaunchAction, on project: Project, openInCentro: (() -> Void)? = nil) {
        let path = project.path
        switch action.id {
        case "finder":      SystemActions.revealInFinder(path)
        case "terminal":    SystemActions.runInTerminal(cwd: path, command: "")
        case "claudeCode":  SystemActions.openInClaude(path)
        case "cursor":      SystemActions.openInCursor(path)
        case "vscode":      SystemActions.openInVSCode(path)
        case "antigravity": SystemActions.openInAntigravity(path)
        case "claudeApp":   SystemActions.openClaudeApp(path)
        case "centro":
            selectedProjectID = project.id
            openInCentro?()
        default:
            if action.id.hasPrefix("custom:"),
               let a = customActions.first(where: { "custom:\($0.id.uuidString)" == action.id }) {
                runCustomAction(a, in: path)
            }
        }
        if action.id != "finder" { markOpened(project.id) }
    }
}

// MARK: - Preferencias

@Observable
final class AppPrefs {
    static let shared = AppPrefs()
    static let defaultClaudeCommand = "claude --dangerously-skip-permissions"

    /// Botones que aparecen al pasar el cursor por una tarjeta.
    var cardActions: [String] = ["finder", "terminal", "cursor", "claudeCode"] { didSet { save() } }
    /// Opciones al elegir un proyecto en la lupa de la barra de menú.
    var quickSearchActions: [String] = ["claudeCode", "finder", "centro"] { didSet { save() } }
    /// Comando que corre "Claude Code" en la Terminal.
    var claudeCommand: String = AppPrefs.defaultClaudeCommand { didSet { save() } }
    /// App de terminal donde se abren los proyectos.
    var terminalApp: TerminalApp = .terminal { didSet { save() } }
    /// Ya se mostró la bienvenida (idioma + preferencias) del primer arranque.
    var onboardingDone = false { didSet { save() } }

    @ObservationIgnored private var loading = false
    private struct Stored: Codable {
        var cardActions: [String]?
        var quickSearchActions: [String]?
        var claudeCommand: String?
        var terminalApp: TerminalApp?
        var onboardingDone: Bool?
    }

    private var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CENTRO/prefs.json")
    }

    private init() {
        loading = true
        if let data = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(Stored.self, from: data) {
            if let v = s.cardActions { cardActions = v }
            if let v = s.quickSearchActions { quickSearchActions = v }
            if let v = s.claudeCommand { claudeCommand = v }
            if let v = s.terminalApp { terminalApp = v }
            if let v = s.onboardingDone { onboardingDone = v }
        }
        // Quien ya usaba CENTRO (tiene proyectos cargados) no ve la bienvenida.
        if !onboardingDone,
           FileManager.default.fileExists(atPath: url.deletingLastPathComponent().appendingPathComponent("config.json").path) {
            onboardingDone = true
        }
        loading = false
        if onboardingDone && !FileManager.default.fileExists(atPath: url.path) { save() }
    }

    private func save() {
        guard !loading else { return }
        let s = Stored(cardActions: cardActions, quickSearchActions: quickSearchActions, claudeCommand: claudeCommand,
                       terminalApp: terminalApp, onboardingDone: onboardingDone)
        if let data = try? JSONEncoder().encode(s) { try? data.write(to: url, options: .atomic) }
    }
}

// MARK: - Terminal

enum TerminalApp: String, Codable, CaseIterable, Identifiable {
    case terminal, iterm
    var id: String { rawValue }
    var name: String {
        switch self {
        case .terminal: return "Terminal"
        case .iterm:    return "iTerm2"
        }
    }
}

// MARK: - Idioma

/// Idioma de la interfaz. Se guarda como `AppleLanguages` solo para esta app
/// y se aplica al reiniciar (macOS elige el idioma al arrancar).
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, es, en
    var id: String { rawValue }

    var name: String {
        switch self {
        case .system: return String(localized: "Idioma del sistema")
        case .es:     return "Español"
        case .en:     return "English"
        }
    }

    /// Lo elegido en esta app (no el idioma global del Mac).
    static var current: AppLanguage {
        let domain = Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0) }
        let code = (domain?["AppleLanguages"] as? [String])?.first ?? ""
        if code.hasPrefix("es") { return .es }
        if code.hasPrefix("en") { return .en }
        return .system
    }

    /// Idioma con el que arrancó la app (para saber si hace falta reiniciar).
    static let atLaunch = AppLanguage.current

    /// Locale para previsualizar textos antes de reiniciar.
    var locale: Locale {
        switch self {
        case .system: return .autoupdatingCurrent
        case .es, .en: return Locale(identifier: rawValue)
        }
    }

    func apply() {
        if self == .system { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }
        else { UserDefaults.standard.set([rawValue], forKey: "AppleLanguages") }
    }

    /// Cierra y vuelve a abrir CENTRO para aplicar el idioma.
    static func relaunch() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? p.run()
        NSApp.terminate(nil)
    }
}

// MARK: - Info de la app

enum AppInfo {
    static let repoURL = "https://github.com/soykeviin/CENTRO"
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
