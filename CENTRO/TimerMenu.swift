//
//  TimerMenu.swift
//  CENTRO
//
//  Widget de time tracking en la barra de menú (junto al notch).
//

import SwiftUI
import AppKit

// Etiqueta de la barra de menú: logo del proyecto (izq) + tiempo (der).
struct TimerMenuLabel: View {
    @Bindable var store: ProjectStore

    var body: some View {
        let _ = store.tick   // refresca cada segundo
        if let s = store.activeSession {
            HStack(spacing: 4) {
                icon(for: s.projectPath)
                Text(compact(s.seconds))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
        } else {
            Image(systemName: "timer")
        }
    }

    @ViewBuilder
    private func icon(for path: String) -> some View {
        if let img = Self.circularIcon(for: path, store: store) {
            Image(nsImage: img)
        } else {
            Image(systemName: "timer")
        }
    }

    /// Pre-renderiza un ícono circular pequeño para la barra de menú.
    static func circularIcon(for path: String, store: ProjectStore, size: CGFloat = 16) -> NSImage? {
        guard let p = store.projects.first(where: { $0.path == path }),
              let iconPath = p.iconPath,
              // solo desde caché: este label se redibuja cada segundo con el timer activo
              let src = IconCache.shared.cached(iconPath) else { return nil }
        let out = NSImage(size: NSSize(width: size, height: size))
        out.lockFocus()
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        NSBezierPath(ovalIn: rect).addClip()
        src.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        out.unlockFocus()
        out.isTemplate = false
        return out
    }

    private func compact(_ s: Int) -> String {
        s >= 3600 ? String(format: "%d:%02d:%02d", s/3600, (s%3600)/60, s%60)
                  : String(format: "%d:%02d", s/60, s%60)
    }
}

// Contenido (ventana) al hacer click en la barra de menú.
struct TimerMenuView: View {
    @Bindable var store: ProjectStore

    var body: some View {
        let _ = store.tick
        if let s = store.activeSession {
            let project = store.projects.first(where: { $0.path == s.projectPath })
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    if let project { ProjectAvatar(project: project, size: 44, corner: 22) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.projectName(forPath: s.projectPath))
                            .font(.system(size: 15, weight: .bold))
                        HStack(spacing: 5) {
                            Circle().fill(.green).frame(width: 6, height: 6)
                            Text("En curso").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                Text(formatHMS(s.seconds))
                    .font(.system(size: 34, weight: .heavy, design: .monospaced))
                    .contentTransition(.numericText())

                HStack(spacing: 10) {
                    Button {
                        SystemActions.revealInFinder(s.projectPath)
                    } label: { Label("Finder", systemImage: "folder.fill").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered)

                    Button {
                        SystemActions.openInClaude(s.projectPath)
                    } label: { Label("Claude", systemImage: "sparkle").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered)

                    Button {
                        store.stopTimer()
                    } label: { Label("Detener", systemImage: "stop.fill").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).tint(.red)
                }
            }
            .padding(18)
            .frame(width: 300)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "timer").font(.system(size: 28)).foregroundStyle(.secondary)
                Text("Sin temporizador activo").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(24).frame(width: 240)
        }
    }
}
