//
//  SystemActions.swift
//  CENTRO
//
//  Acciones nativas de macOS: abrir Finder, Terminal, VS Code, ejecutar comandos.
//  Port de server/src/lib/osascript.ts (NSWorkspace + osascript).
//

import AppKit

enum SystemActions {

    /// Abre la carpeta en Finder.
    static func revealInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    /// Abre la carpeta (o archivo) con la app por defecto.
    static func open(_ path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    /// Abre una URL en el navegador por defecto.
    static func openURL(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }

    /// Previsualiza un archivo con Quick Look.
    static func quickLook(_ path: String) {
        runProcess("/usr/bin/qlmanage", ["-p", path])
    }

    /// Copia texto al portapapeles.
    static func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Abre el proyecto en VS Code si está instalado.
    static func openInVSCode(_ path: String) {
        runProcess("/usr/bin/env", ["sh", "-c", "code \"\(path)\" || open -a \"Visual Studio Code\" \"\(path)\""])
    }

    /// Abre el proyecto en Cursor.
    static func openInCursor(_ path: String) {
        runProcess("/usr/bin/env", ["sh", "-c", "cursor \"\(path)\" || open -a \"Cursor\" \"\(path)\""])
    }

    /// Abre el proyecto en Antigravity.
    static func openInAntigravity(_ path: String) {
        runProcess("/usr/bin/env", ["sh", "-c", "antigravity \"\(path)\" || open -a \"Antigravity\" \"\(path)\""])
    }

    /// Abre la app de Claude.
    static func openClaudeApp(_ path: String) {
        runProcess("/usr/bin/env", ["sh", "-c", "open -a \"Claude\" \"\(path)\" || open -a \"Claude\""])
    }

    /// Abre Claude Code en una Terminal dentro de la carpeta del proyecto
    /// (con el comando de Configuración, por defecto `claude --dangerously-skip-permissions`).
    static func openInClaude(_ path: String) {
        let cmd = AppPrefs.shared.claudeCommand.trimmingCharacters(in: .whitespaces)
        runInTerminal(cwd: path, command: cmd.isEmpty ? AppPrefs.defaultClaudeCommand : cmd)
    }

    /// Abre Terminal.app en la carpeta y ejecuta el comando.
    static func runInTerminal(cwd: String, command: String) {
        let cmd = command.trimmingCharacters(in: .whitespaces)
        // Comando de shell con comillas reales alrededor de la ruta…
        let shell = cmd.isEmpty ? "cd \"\(cwd)\"" : "cd \"\(cwd)\" && \(cmd)"
        // …y luego se escapa TODO para embeberlo en el string de AppleScript.
        let script: String
        switch AppPrefs.shared.terminalApp {
        case .terminal:
            script = """
            tell application "Terminal"
                activate
                do script "\(esc(shell))"
            end tell
            """
        case .iterm:
            script = """
            tell application "iTerm"
                activate
                set w to (create window with default profile)
                tell current session of w to write text "\(esc(shell))"
            end tell
            """
        }
        runOSAScript(script)
    }

    /// Ejecuta un comando en background, sin ventana.
    static func runInBackground(cwd: String, command: String) {
        runProcess("/bin/zsh", ["-lc", "cd \"\(cwd)\" && \(command)"])
    }

    /// Muestra un NSOpenPanel para elegir una carpeta. Devuelve la ruta o nil.
    @MainActor
    static func pickFolder(prompt: String = String(localized: "Elegí la carpeta")) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Elegir")
        panel.message = prompt
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    // MARK: - Internos

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func runOSAScript(_ source: String) {
        runProcess("/usr/bin/osascript", ["-e", source])
    }

    private static func runProcess(_ launchPath: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        try? p.run()
    }
}
