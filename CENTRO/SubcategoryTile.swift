//
//  SubcategoryTile.swift
//  CENTRO
//
//  Carpeta de subcategoría: navega al hacer click y acepta proyectos arrastrados.
//

import SwiftUI

struct SubcategoryTile: View {
    let sub: VirtualFolder
    @Bindable var store: ProjectStore
    @State private var targeted = false

    var body: some View {
        Button {
            withAnimation(.snappy) { store.nav = .category(sub.id); store.selectedProjectID = nil }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: sub.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(sub.color)
                    .frame(width: 30, height: 30)
                    .background(sub.color.opacity(0.16), in: .rect(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 1) {
                    Text(sub.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text("\(store.count(for: .category(sub.id))) proyectos")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(targeted ? sub.color.opacity(0.18) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(targeted ? sub.color : .white.opacity(0.08),
                            style: StrokeStyle(lineWidth: targeted ? 2 : 1, dash: targeted ? [6, 4] : []))
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { paths, _ in
            for path in paths { store.setCategory(path, sub.id) }
            return !paths.isEmpty
        } isTargeted: { t in
            withAnimation(.snappy) { targeted = t }
        }
    }
}
