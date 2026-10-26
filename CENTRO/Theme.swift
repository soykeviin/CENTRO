//
//  Theme.swift
//  CENTRO
//
//  Sistema de diseño: colores, fondo, Liquid Glass y animaciones.
//

import SwiftUI

// MARK: - Color hex helpers

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red:   Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue:  Double(v & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Design tokens

enum Theme {
    // Acento principal: lila fosforescente (neón)
    static let accent      = Color(hex: "#B14EFF")!   // lila neón
    static let accentSoft  = Color(hex: "#C77DFF")!   // lila glow
    static let electric    = Color(hex: "#D08CFF")!   // lila claro

    // Resalte de la pantalla de inicio: lila fosforescente (neón)
    static let lilac       = Color(hex: "#B14EFF")!   // lila neón
    static let lilacSoft   = Color(hex: "#DCA0FF")!
    static let lilacGlow    = Color(hex: "#C77DFF")!

    static let corner: CGFloat = 16
    static let cardCorner: CGFloat = 18

    /// Fondo global monocromo (blanco y negro) con viñeta sutil.
    static var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#0A0A0B")!,
                    Color(hex: "#101012")!,
                    Color(hex: "#08080A")!
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // brillo blanco muy tenue arriba
            RadialGradient(
                colors: [.white.opacity(0.05), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 600
            )
            // chispa eléctrica sutil
            RadialGradient(
                colors: [electric.opacity(0.08), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 650
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Liquid Glass modifier (con fallback)

struct LiquidGlass: ViewModifier {
    var cornerRadius: CGFloat = Theme.corner
    var interactive: Bool = false

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(
                interactive ? .regular.interactive() : .regular,
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            content
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
        }
    }
}

extension View {
    /// Aplica el efecto Liquid Glass de Apple (con fallback a material translúcido).
    func liquidGlass(cornerRadius: CGFloat = Theme.corner, interactive: Bool = false) -> some View {
        modifier(LiquidGlass(cornerRadius: cornerRadius, interactive: interactive))
    }
}

// MARK: - Animaciones reutilizables

extension Animation {
    static var snappy: Animation { .spring(response: 0.38, dampingFraction: 0.78) }
    static var gentle: Animation { .spring(response: 0.55, dampingFraction: 0.85) }
}

// MARK: - Entrada con stagger (aparece desde abajo con fade)

struct AppearTransition: ViewModifier {
    let index: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .onAppear {
                // Tope al retraso: con 200 proyectos el último esperaba 8 s en aparecer.
                withAnimation(.gentle.delay(Double(min(index, 10)) * 0.03)) {
                    shown = true
                }
            }
    }
}

extension View {
    /// Animación de entrada escalonada según el índice del elemento.
    func appear(index: Int) -> some View { modifier(AppearTransition(index: index)) }
}
