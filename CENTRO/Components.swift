//
//  Components.swift
//  CENTRO
//
//  Componentes de UI reutilizables: badges, chips de estado, botones glass.
//

import SwiftUI

// MARK: - Stack badge

struct StackBadgeView: View {
    let badge: StackBadge

    var body: some View {
        Text(badge.label)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badge.category.tint.opacity(0.18), in: .capsule)
            .overlay(Capsule().stroke(badge.category.tint.opacity(0.35), lineWidth: 0.5))
            .foregroundStyle(badge.category.tint)
    }
}

// MARK: - Status dot

struct StatusDot: View {
    let status: ProjectStatus
    var showLabel = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status.color)
                .frame(width: 7, height: 7)
                .shadow(color: status.color.opacity(0.8), radius: 3)
            if showLabel {
                Text(status.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Git badge

struct GitBadgeView: View {
    let git: GitInfo

    var body: some View {
        if git.isGit, let branch = git.branch {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 9, weight: .semibold))
                Text(branch)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                if git.dirty {
                    Circle().fill(Theme.electric).frame(width: 5, height: 5)
                }
            }
            .foregroundStyle(git.dirty ? AnyShapeStyle(Theme.electric) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.white.opacity(0.06), in: .capsule)
        }
    }
}

// MARK: - Project avatar (ícono del proyecto o inicial)

struct ProjectAvatar: View {
    let project: Project
    var size: CGFloat = 40
    var corner: CGFloat = 11
    @State private var loaded: NSImage?

    var body: some View {
        content
            .task(id: project.iconPath) {
                guard let path = project.iconPath else { loaded = nil; return }
                loaded = await IconCache.shared.load(path)
            }
    }

    @ViewBuilder private var content: some View {
        if let img = loaded ?? project.iconPath.flatMap({ IconCache.shared.cached($0) }) {
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(.rect(cornerRadius: corner))
                .overlay(RoundedRectangle(cornerRadius: corner).stroke(.white.opacity(0.12), lineWidth: 1))
        } else {
            RoundedRectangle(cornerRadius: corner)
                .fill(LinearGradient(colors: [Theme.accent.opacity(0.9), Theme.accentSoft.opacity(0.7)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
                .overlay(Text(initials)
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(.white))
        }
    }

    private var initials: String {
        let words = project.displayName.split(whereSeparator: { " -_.".contains($0) })
        let first = words.first?.first.map(String.init) ?? "?"
        let second = words.dropFirst().first?.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }
}

// MARK: - Glifo de app (ícono real del asset o SF symbol)

struct AppGlyph: View {
    var symbol: String? = nil
    var asset: String? = nil
    var size: CGFloat = 14
    var tint: Color = .primary

    var body: some View {
        if let asset {
            Image(asset).resizable().interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else if let symbol {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(tint)
        }
    }
}

// MARK: - Botón de acción rápida con tooltip de nombre

struct QuickActionButton: View {
    var symbol: String? = nil
    var asset: String? = nil
    var name: String
    var tint: Color = .primary
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            AppGlyph(symbol: symbol, asset: asset, size: asset != nil ? 22 : 14, tint: tint)
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.08), in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if hovering {
                Text(name)
                    .font(.system(size: 10, weight: .semibold))
                    .fixedSize()
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.black.opacity(0.9), in: .capsule)
                    .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 0.5))
                    .offset(y: -28)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .onHover { h in withAnimation(.snappy) { hovering = h } }
        .help(name)
    }
}

// MARK: - Liquid Glass button style

struct GlassButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if prominent {
                configuration.label
                    .font(.system(size: 12.5, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 11)
                            .fill(LinearGradient(colors: [tint, tint.mix(with: .black, by: 0.28)],
                                                 startPoint: .top, endPoint: .bottom))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(.white.opacity(0.18), lineWidth: 1))
                    .shadow(color: tint.opacity(0.4), radius: 8, y: 2)
            } else {
                configuration.label
                    .font(.system(size: 12.5, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .foregroundStyle(.primary)
                    .liquidGlass(cornerRadius: 11, interactive: true)
            }
        }
        .scaleEffect(configuration.isPressed ? 0.96 : 1)
        .animation(.snappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glassy: GlassButtonStyle { GlassButtonStyle() }
    static func glassy(tint: Color, prominent: Bool = false) -> GlassButtonStyle {
        GlassButtonStyle(tint: tint, prominent: prominent)
    }
}

// MARK: - Icon glass button (cuadrado, para toolbars)

struct GlassIconButton: View {
    let systemImage: String
    var tint: Color = .white
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(hover ? Theme.lilac : tint)
                .frame(width: 34, height: 34)
                .liquidGlass(cornerRadius: 10, interactive: true)
                .scaleEffect(hover ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.snappy) { hover = h } }
    }
}
