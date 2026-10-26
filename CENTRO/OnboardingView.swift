//
//  OnboardingView.swift
//  CENTRO
//
//  Bienvenida del primer arranque: idioma, cómo abrir los proyectos
//  (terminal, comando de Claude Code, botones de las tarjetas) y la lupa
//  de la barra de menú. Todo se puede cambiar después en Configuración.
//

import SwiftUI

struct OnboardingView: View {
    @Bindable var store: ProjectStore
    @Bindable private var prefs = AppPrefs.shared

    /// Paso actual. Se guarda para seguir donde quedó si la app se reinicia al cambiar el idioma.
    @AppStorage("onboardingStep") private var step = 0
    @State private var language = AppLanguage.current

    private let steps = 3

    var body: some View {
        ZStack {
            Theme.background
            VStack(spacing: 0) {
                header
                    .padding(.top, 44)
                Group {
                    switch step {
                    case 0:  languageStep
                    case 1:  openStep
                    default: menuBarStep
                    }
                }
                .frame(maxWidth: 640)
                .padding(.horizontal, 40)
                .padding(.top, 28)
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .opacity))
                Spacer(minLength: 16)
                footer
                    .frame(maxWidth: 640)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)
            }
        }
        .frame(minWidth: 900, minHeight: 640)
        .animation(.snappy, value: step)
    }

    // MARK: Encabezado y pie

    private var header: some View {
        VStack(spacing: 14) {
            Image("CentroMark")
                .resizable().interpolation(.high)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 14))
                .shadow(color: Theme.lilac.opacity(0.6), radius: 18)
            HStack(spacing: 6) {
                ForEach(0..<steps, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? AnyShapeStyle(Theme.lilac) : AnyShapeStyle(.white.opacity(0.15)))
                        .frame(width: i == step ? 26 : 8, height: 6)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Atrás") { step -= 1 }
                    .buttonStyle(.glassy)
            }
            Spacer()
            Button(step == steps - 1 ? "Empezar a usar CENTRO" : "Continuar") { next() }
                .buttonStyle(.glassy(tint: Theme.accent, prominent: true))
                .keyboardShortcut(.defaultAction)
        }
    }

    private func next() {
        if step == 0 {
            if language != AppLanguage.atLaunch {
                language.apply()
                step = 1
                AppLanguage.relaunch()   // macOS aplica el idioma al arrancar
                return
            }
        }
        if step < steps - 1 {
            step += 1
        } else {
            step = 0
            prefs.onboardingDone = true
        }
    }

    // MARK: Paso 1 — idioma

    private var languageStep: some View {
        VStack(spacing: 22) {
            title("Bienvenido a CENTRO",
                  "Todos tus proyectos en un solo lugar: abrilos en tu editor, en la terminal o con Claude Code en un clic.")
            VStack(spacing: 10) {
                ForEach(AppLanguage.allCases) { lang in
                    choiceRow(selected: language == lang) { language = lang } content: {
                        Image(systemName: lang == .system ? "globe" : "character.bubble")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.lilac).frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(lang.name).font(.system(size: 14, weight: .semibold))
                            if lang == .system {
                                Text("Usa el idioma de tu Mac").font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Text(verbatim: "Choose your language · Elegí tu idioma")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
        }
    }

    // MARK: Paso 2 — cómo abrir los proyectos

    private var openStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                title("¿Cómo abrís tus proyectos?", "Elegí tus herramientas. Podés cambiarlo cuando quieras en Configuración.")

                section("Terminal") {
                    Picker("", selection: $prefs.terminalApp) {
                        ForEach(TerminalApp.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 260)
                }

                section("Comando de Claude Code") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(AppPrefs.defaultClaudeCommand, text: $prefs.claudeCommand)
                            .textFieldStyle(.plain).font(.system(size: 12.5, design: .monospaced))
                            .padding(.horizontal, 10).padding(.vertical, 8).liquidGlass(cornerRadius: 9)
                        HStack(spacing: 6) {
                            ForEach([AppPrefs.defaultClaudeCommand, "claude", "claude --continue"], id: \.self) { cmd in
                                Button { prefs.claudeCommand = cmd } label: {
                                    Text(cmd).font(.system(size: 10.5, design: .monospaced))
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(prefs.claudeCommand == cmd ? Theme.lilac.opacity(0.25) : .white.opacity(0.06),
                                                    in: .capsule)
                                }.buttonStyle(.plain)
                            }
                        }
                        Text("--dangerously-skip-permissions deja que Claude ejecute comandos sin pedirte permiso cada vez. Usalo solo en proyectos en los que confíes.")
                            .font(.system(size: 10.5)).foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                section("Botones de cada proyecto") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Aparecen al pasar el cursor por una tarjeta.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        actionToggles($prefs.cardActions, excluding: ["centro"])
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Paso 3 — lupa de la barra de menú

    private var menuBarStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            title("Buscá desde la barra de menú",
                  "Tocá la lupa arriba a la derecha, escribí el nombre de un proyecto y elegí cómo abrirlo, sin abrir la ventana de CENTRO.")
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 30, height: 24)
                    .background(.white.opacity(0.12), in: .rect(cornerRadius: 6))
                Text("Así se ve en la barra de menú").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            section("Opciones al elegir un proyecto") {
                actionToggles($prefs.quickSearchActions, excluding: [])
            }
            Text("Después de esto, agregá tus proyectos: una carpeta que los contenga o de a uno.")
                .font(.system(size: 11.5)).foregroundStyle(.secondary)
        }
    }

    // MARK: Piezas

    private func title(_ t: LocalizedStringKey, _ subtitle: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t).font(.system(size: 28, weight: .heavy, design: .rounded))
            Text(subtitle).font(.system(size: 13.5)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section<C: View>(_ t: LocalizedStringKey, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t).font(.system(size: 13, weight: .bold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func choiceRow<C: View>(selected: Bool, action: @escaping () -> Void,
                                     @ViewBuilder content: () -> C) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                content()
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16)).foregroundStyle(selected ? AnyShapeStyle(Theme.lilac) : AnyShapeStyle(.tertiary))
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .liquidGlass(cornerRadius: 12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Theme.lilac.opacity(0.7) : .clear, lineWidth: 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// Grilla de acciones para prender/apagar. Las prendidas conservan su orden.
    private func actionToggles(_ selection: Binding<[String]>, excluding: Set<String>) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], spacing: 8) {
            ForEach(LaunchAction.builtIn.filter { !excluding.contains($0.id) }) { a in
                let on = selection.wrappedValue.contains(a.id)
                Button {
                    if on { selection.wrappedValue.removeAll { $0 == a.id } }
                    else { selection.wrappedValue.append(a.id) }
                } label: {
                    HStack(spacing: 9) {
                        AppGlyph(symbol: a.symbol, asset: a.asset, size: a.asset != nil ? 18 : 13, tint: Theme.lilac)
                            .frame(width: 22)
                        Text(a.name).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: on ? "checkmark.square.fill" : "square")
                            .foregroundStyle(on ? AnyShapeStyle(Theme.lilac) : AnyShapeStyle(.tertiary))
                    }
                    .padding(.horizontal, 11).padding(.vertical, 9)
                    .liquidGlass(cornerRadius: 10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? Theme.lilac.opacity(0.5) : .clear, lineWidth: 1))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
