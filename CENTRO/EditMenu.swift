//
//  EditMenu.swift
//  CENTRO
//
//  Botón "Editar" que despliega los editores al pasar el cursor
//  y se cierra al sacar el cursor.
//

import SwiftUI

struct EditMenu: View {
    let project: Project
    @Bindable var store: ProjectStore

    @State private var hoverButton = false
    @State private var hoverMenu = false

    private var open: Bool { hoverButton || hoverMenu }
    private let logos = ["Icon_vscode", "Icon_cursor", "Icon_antigravity", "Icon_claude"]

    var body: some View {
        trigger
            .overlay(alignment: .top) {
                if open {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 6).contentShape(.rect)   // puente de hover
                        panel
                    }
                    .offset(y: 34)
                    .onHover { h in hoverMenu = h }
                    .zIndex(100)
                    .transition(.scale(scale: 0.95, anchor: .top).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: open)
    }

    private var trigger: some View {
        HStack(spacing: 9) {
            Image(systemName: "pencil").font(.system(size: 12.5, weight: .semibold))
            Text("Editar").font(.system(size: 12.5, weight: .semibold)).lineLimit(1).fixedSize()
            HStack(spacing: -5) {
                ForEach(logos, id: \.self) { logo in
                    Image(logo).resizable().interpolation(.high)
                        .aspectRatio(contentMode: .fit).frame(width: 16, height: 16)
                        .background(Circle().fill(.black.opacity(0.4)))
                        .overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 0.5))
                }
            }
            Image(systemName: open ? "chevron.up" : "chevron.down")
                .font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
        }
        .fixedSize()
        .padding(.horizontal, 14).padding(.vertical, 9)
        .liquidGlass(cornerRadius: 11, interactive: true)
        .contentShape(.rect)
        .onHover { h in hoverButton = h }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 2) {
            option(asset: "Icon_vscode", name: "VS Code", subtitle: nil) {
                SystemActions.openInVSCode(project.path)
            }
            option(asset: "Icon_cursor", name: "Cursor", subtitle: nil) {
                SystemActions.openInCursor(project.path)
            }
            option(asset: "Icon_antigravity", name: "Antigravity", subtitle: nil) {
                SystemActions.openInAntigravity(project.path)
            }
            option(asset: "Icon_claude", name: "Claude", subtitle: String(localized: "Abrir la app de Claude")) {
                SystemActions.openClaudeApp(project.path)
            }
            Divider().padding(.vertical, 3)
            option(asset: "Icon_claude", name: "Claude Code", subtitle: String(localized: "Terminal con claude iniciado")) {
                SystemActions.openInClaude(project.path)
            }
        }
        .padding(6)
        .frame(width: 270)
        .background(Color(hex: "#1A1A20") ?? .black, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.55), radius: 24, y: 12)
    }

    private func option(asset: String, name: String, subtitle: String?, action: @escaping () -> Void) -> some View {
        Button {
            action()
            store.markOpened(project.id)
            hoverButton = false; hoverMenu = false
        } label: {
            HStack(spacing: 11) {
                Image(asset).resizable().interpolation(.high)
                    .aspectRatio(contentMode: .fit).frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.system(size: 13, weight: .medium))
                    if let subtitle {
                        Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
