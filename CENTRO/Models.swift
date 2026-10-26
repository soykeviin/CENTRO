//
//  Models.swift
//  CENTRO
//
//  Modelos de dominio — equivalente nativo de web/src/types/index.ts
//

import SwiftUI

// MARK: - Stack badge

nonisolated enum StackCategory: String, Codable, Hashable {
    case language, framework, runtime, tool

    @MainActor var tint: Color {
        switch self {
        case .language:  return Theme.accent             // azul eléctrico
        case .framework: return Theme.accentSoft         // azul claro
        case .runtime:   return Color.white.opacity(0.85) // blanco
        case .tool:      return Color.white.opacity(0.5)  // gris
        }
    }
}

nonisolated struct StackBadge: Identifiable, Hashable, Codable {
    var label: String
    var category: StackCategory
    var id: String { label }
}

// MARK: - Status

nonisolated enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case active, paused, completed, archived
    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:    return String(localized: "Activo")
        case .paused:    return String(localized: "En pausa")
        case .completed: return String(localized: "Completado")
        case .archived:  return String(localized: "Archivado")
        }
    }

    @MainActor var color: Color {
        switch self {
        case .active:    return Theme.accent              // azul eléctrico
        case .paused:    return Color.white.opacity(0.75) // blanco
        case .completed: return Theme.accentSoft          // azul claro
        case .archived:  return Color.white.opacity(0.35) // gris
        }
    }
}

// MARK: - Git

nonisolated struct GitInfo: Hashable {
    var isGit: Bool = false
    var branch: String? = nil
    var dirty: Bool = false
    var ahead: Int = 0
    var behind: Int = 0
    var lastCommitSubject: String? = nil
    var lastCommitRelative: String? = nil
}

// MARK: - Smart action

nonisolated struct SmartAction: Identifiable, Hashable {
    enum OpensIn { case terminal, app, background }

    var id: String
    var label: String
    var systemImage: String
    var command: String
    var opensIn: OpensIn
}

// MARK: - Project

nonisolated struct Project: Identifiable, Hashable {
    var id: String { path }          // la ruta absoluta es el identificador estable
    var name: String                 // nombre de la carpeta
    var customName: String? = nil    // nombre personalizado (override)
    var path: String

    /// Nombre a mostrar: el personalizado si existe, si no el de la carpeta.
    var displayName: String { customName?.isEmpty == false ? customName! : name }
    var isManual: Bool = false       // agregado individualmente (una carpeta = un proyecto)
    var detectedStack: [StackBadge] = []
    var git: GitInfo = GitInfo()
    var modifiedAt: Date
    var exists: Bool = true

    // Metadata editable y persistida (ver ProjectMetadata)
    var isFavorite: Bool = false
    var status: ProjectStatus = .active
    var folderID: UUID? = nil
    var notes: String = ""
    var lastOpenedAt: Date? = nil
    var isHidden: Bool = false        // oculto de la app (no borra archivos)
    var isPinned: Bool = false        // fijado arriba de todo
    var iconPath: String? = nil       // .ico/.icns/png hallado en la carpeta

    // Salud del proyecto (chequeos baratos en disco)
    var needsInstall: Bool = false    // tiene package.json pero no node_modules
    var missingEnv: Bool = false      // hay .env.example pero falta .env

    var hasHealthIssues: Bool { needsInstall || missingEnv || git.dirty }

    var folderURL: URL { URL(fileURLWithPath: path) }
}

// MARK: - Tareas / Inbox / Tiempo

struct TodoItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var text: String
    var done: Bool = false
    var projectPath: String? = nil
    var createdAt: Date = Date()
}

struct InboxItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var text: String
    var projectPath: String? = nil
    var createdAt: Date = Date()
}

struct TimeSession: Identifiable, Codable, Hashable {
    var id = UUID()
    var projectPath: String
    var startedAt: Date = Date()
    var endedAt: Date? = nil

    var seconds: Int { Int((endedAt ?? Date()).timeIntervalSince(startedAt)) }
    var isActive: Bool { endedAt == nil }
}

// MARK: - Deps / Actividad

struct CustomAction: Identifiable, Codable, Hashable {
    var id = UUID()
    var label: String
    var command: String
    var symbol: String = "bolt.fill"
    var runsInTerminal: Bool = true
}

nonisolated struct OutdatedDep: Identifiable, Hashable {
    var name: String
    var current: String
    var wanted: String
    var latest: String
    var id: String { name }
}

nonisolated struct ProjectActivity: Identifiable, Hashable {
    var projectPath: String
    var projectName: String
    var totalCommits: Int
    var byDay: [String: Int]          // "yyyy-MM-dd" -> count
    var recent: [(date: String, subject: String)]

    var id: String { projectPath }
    static func == (l: ProjectActivity, r: ProjectActivity) -> Bool { l.projectPath == r.projectPath }
    func hash(into h: inout Hasher) { h.combine(projectPath) }
}

// MARK: - Virtual folder (sidebar)

struct VirtualFolder: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    var symbol: String = "folder"
    var colorHex: String = "#7C7CFF"
    var position: Int = 0
    var parentID: UUID? = nil        // categoría padre (nil = nivel superior)

    var color: Color { Color(hex: colorHex) ?? .accentColor }
}

// MARK: - Persisted metadata (un registro por ruta de proyecto)

struct ProjectMetadata: Codable {
    var isFavorite: Bool = false
    var status: String = ProjectStatus.active.rawValue
    var folderID: UUID? = nil
    var notes: String = ""
    var lastOpenedAt: Date? = nil
    var isHidden: Bool = false
    var customName: String? = nil
    var isPinned: Bool = false
}
