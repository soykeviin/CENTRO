//
//  AppDelegate.swift
//  CENTRO
//
//  Mantiene la app viva en segundo plano (para que la lupa de la barra de menú
//  funcione aunque cierres la ventana).
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false   // no cerrar la app al cerrar la ventana (sigue en la barra de menú)
    }
}
