//
//  CategoryEditorSheet.swift
//  CENTRO
//
//  Crear o editar una categoría/subcategoría: nombre + color + ícono.
//

import SwiftUI
import AppKit

struct CategoryEditorSheet: View {
    @Bindable var store: ProjectStore
    var editing: VirtualFolder? = nil    // categoría existente (modo editar)
    var parentID: UUID? = nil            // padre (modo crear subcategoría)
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var colorHex = "#B14EFF"
    @State private var symbol = "square.stack"

    private let presets = [
        "#B14EFF", "#0A84FF", "#34C759", "#FF9F0A", "#FF375F", "#5E5CE6",
        "#64D2FF", "#FFD60A", "#FF6B9D", "#30D158", "#BF5AF2", "#8E8E93"
    ]
    private let symbols = [
        "square.stack", "folder.fill", "gamecontroller.fill", "globe", "hammer.fill",
        "paintbrush.fill", "flask.fill", "camera.fill", "music.note", "cart.fill",
        "bolt.fill", "heart.fill", "star.fill", "leaf.fill"
    ]

    private var selectedColor: Color { Color(hex: colorHex) ?? Theme.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(selectedColor)
                    .frame(width: 34, height: 34)
                    .background(selectedColor.opacity(0.16), in: .rect(cornerRadius: 9))
                Text(title).font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
            }

            field(String(localized: "Nombre")) {
                TextField("Nombre de la categoría", text: $name)
                    .textFieldStyle(.plain).font(.system(size: 13))
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .liquidGlass(cornerRadius: 10)
            }

            field(String(localized: "Color")) {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 30), spacing: 12)], spacing: 12) {
                        ForEach(presets, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .gray)
                                .frame(width: 26, height: 26)
                                .overlay(Circle().stroke(.white, lineWidth: colorHex == hex ? 2.5 : 0))
                                .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 0.5))
                                .contentShape(.circle)
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    ColorPicker(selection: Binding(
                        get: { selectedColor },
                        set: { colorHex = Self.hex(from: $0) }
                    )) {
                        Text("Color personalizado").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
            }

            field(String(localized: "Ícono")) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(symbols, id: \.self) { s in
                            Image(systemName: s)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(symbol == s ? AnyShapeStyle(selectedColor) : AnyShapeStyle(.secondary))
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 8)
                                    .fill(symbol == s ? selectedColor.opacity(0.18) : .white.opacity(0.05)))
                                .onTapGesture { symbol = s }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }.buttonStyle(.glassy)
                Button {
                    save()
                } label: { Label(editing == nil ? String(localized: "Crear") : String(localized: "Guardar"), systemImage: "checkmark") }
                    .buttonStyle(.glassy(tint: selectedColor, prominent: true))
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(Theme.background)
        .onAppear {
            if let e = editing { name = e.name; colorHex = e.colorHex; symbol = e.symbol }
        }
    }

    private var title: String {
        if editing != nil { return String(localized: "Editar categoría") }
        return parentID != nil ? String(localized: "Nueva subcategoría") : String(localized: "Nueva categoría")
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        if let e = editing {
            store.updateCategory(e.id, name: n, colorHex: colorHex, symbol: symbol)
        } else {
            store.addCategory(name: n, symbol: symbol, colorHex: colorHex, parentID: parentID)
        }
        dismiss()
    }

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary).tracking(0.6)
            content()
        }
    }

    static func hex(from color: Color) -> String {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        let r = Int(round(ns.redComponent * 255))
        let g = Int(round(ns.greenComponent * 255))
        let b = Int(round(ns.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
