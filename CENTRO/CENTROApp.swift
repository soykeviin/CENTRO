//
//  CENTROApp.swift
//  CENTRO
//

import SwiftUI

@main
struct CENTROApp: App {
    @State private var store = ProjectStore()
    @Bindable private var prefs = AppPrefs.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        _ = AppLanguage.atLaunch   // fijar el idioma de arranque antes de que se pueda cambiar
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            Group {
                if let q = UserDefaults.standard.string(forKey: "centroShowcaseSearch") {
                    // Solo para capturas (README, videos): `-centroShowcaseSearch <texto>`
                    // muestra la lupa en una ventana normal con esa búsqueda.
                    QuickSearchMenu(store: store, initialQuery: q, autofocus: false).fixedSize()
                } else if prefs.onboardingDone {
                    ContentView(store: store)
                } else {
                    OnboardingView(store: store)   // primer arranque: idioma y preferencias
                }
            }
            .preferredColorScheme(.dark)
            .modifier(ShowcaseScale())
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)

        MenuBarExtra(isInserted: timerActive) {
            TimerMenuView(store: store)
        } label: {
            TimerMenuLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        // Lupa: buscar un proyecto y abrirlo (carpeta / Claude Code / CENTRO)
        MenuBarExtra("Buscar proyecto", systemImage: "magnifyingglass") {
            QuickSearchMenu(store: store)
                .preferredColorScheme(.dark)
        }
        .menuBarExtraStyle(.window)
    }

    private var timerActive: Binding<Bool> {
        Binding(get: { store.activeSession != nil }, set: { _ in })
    }
}

/// Solo para capturas: `-centroShowcaseScale 2` dibuja la ventana al doble de tamaño
/// (nítida aunque el monitor sea 1x). Sin el argumento no hace nada.
private struct ShowcaseScale: ViewModifier {
    private let scale = CGFloat(UserDefaults.standard.double(forKey: "centroShowcaseScale"))
    private let base = CGSize(width: UserDefaults.standard.double(forKey: "centroShowcaseWidth"),
                              height: UserDefaults.standard.double(forKey: "centroShowcaseHeight"))

    func body(content: Content) -> some View {
        if scale > 0, base.width > 0, base.height > 0 {
            content
                .frame(width: base.width, height: base.height, alignment: .topLeading)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: base.width * scale, height: base.height * scale, alignment: .topLeading)
        } else {
            content
        }
    }
}
