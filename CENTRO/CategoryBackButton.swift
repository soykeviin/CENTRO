//
//  CategoryBackButton.swift
//  CENTRO
//
//  Botón "Volver" a la categoría padre. Spring-loaded: al arrastrar un proyecto
//  y mantenerlo 1s encima, navega a la categoría padre sin soltar el arrastre.
//

import SwiftUI

struct CategoryBackButton: View {
    @Bindable var store: ProjectStore
    let parentID: UUID
    @State private var targeted = false
    @State private var springTask: Task<Void, Never>? = nil

    var body: some View {
        Button {
            goBack()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                Text("Volver a \(store.categoryName(parentID) ?? String(localized: "categoría"))")
                    .font(.system(size: 12.5, weight: .semibold))
                if targeted {
                    Text("• soltá para mover acá")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(targeted ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(targeted ? Theme.accent.opacity(0.16) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(targeted ? Theme.accent : .white.opacity(0.08),
                            style: StrokeStyle(lineWidth: targeted ? 2 : 1, dash: targeted ? [6, 4] : []))
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { paths, _ in
            for p in paths { store.setCategory(p, parentID) }
            goBack()
            return !paths.isEmpty
        } isTargeted: { t in
            withAnimation(.snappy) { targeted = t }
            if t {
                springTask?.cancel()
                springTask = Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)   // 1 segundo
                    if !Task.isCancelled { await MainActor.run { goBack() } }
                }
            } else {
                springTask?.cancel()
            }
        }
    }

    private func goBack() {
        withAnimation(.snappy) {
            store.nav = .category(parentID)
            store.selectedProjectID = nil
        }
    }
}
