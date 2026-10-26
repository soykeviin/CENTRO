//
//  DevServerView.swift
//  CENTRO
//
//  Arrancar/detener el dev server y ver el log en vivo dentro de CENTRO.
//

import SwiftUI

struct DevServerView: View {
    @Bindable var store: ProjectStore
    let path: String
    let command: String
    let label: String

    private var running: Bool { store.devServers.isRunning(path) }
    private var log: String { store.devServers.log(path) }

    var body: some View {
        if running || !log.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "terminal.fill").font(.system(size: 12)).foregroundStyle(.secondary)
                    Text("Dev server").font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
                    if running {
                        HStack(spacing: 5) {
                            Circle().fill(.green).frame(width: 6, height: 6).shadow(color: .green, radius: 3)
                            Text("corriendo").font(.system(size: 11)).foregroundStyle(.green)
                        }
                    }
                    Spacer()
                    Button { store.devServers.clearLog(path) } label: {
                        Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(.tertiary)
                    }.buttonStyle(.plain).help("Limpiar log")
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        Text(log)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .id("logbottom")
                    }
                    .frame(height: 200)
                    .background(.black.opacity(0.5), in: .rect(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 1))
                    .onChange(of: log) { _, _ in
                        withAnimation(.linear(duration: 0.1)) { proxy.scrollTo("logbottom", anchor: .bottom) }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: 14)
        }
    }
}
