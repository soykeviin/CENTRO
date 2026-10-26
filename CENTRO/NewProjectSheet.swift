//
//  NewProjectSheet.swift
//  CENTRO
//
//  Crear un proyecto nuevo: CENTRO crea una carpeta nueva donde elijas.
//

import SwiftUI

struct NewProjectSheet: View {
    @Bindable var store: ProjectStore
    var presetCategory: UUID?
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var parentPath = ""
    @State private var categoryID: UUID? = nil
    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").font(.system(size: 18)).foregroundStyle(Theme.accent)
                Text("Nuevo proyecto").font(.system(size: 18, weight: .bold, design: .rounded))
            }
            Text("CENTRO va a crear una carpeta nueva en la ubicación que elijas.")
                .font(.system(size: 12)).foregroundStyle(.secondary)

            field(String(localized: "Nombre")) {
                TextField("Mi proyecto", text: $name)
                    .textFieldStyle(.plain).font(.system(size: 13))
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .liquidGlass(cornerRadius: 10)
            }

            field(String(localized: "Ubicación")) {
                HStack(spacing: 8) {
                    Text(parentPath.isEmpty ? String(localized: "Elegí dónde crearla…") :
                            parentPath.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(parentPath.isEmpty ? .tertiary : .primary)
                        .lineLimit(1).truncationMode(.head)
                    Spacer()
                    Button {
                        if let p = SystemActions.pickFolder(prompt: String(localized: "¿Dónde querés crear la carpeta?")) { parentPath = p }
                    } label: { Label("Elegir", systemImage: "folder") }
                        .buttonStyle(.glassy)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .liquidGlass(cornerRadius: 10)
            }

            if !store.folders.isEmpty {
                field(String(localized: "Categoría")) {
                    Picker("", selection: $categoryID) {
                        Text("Sin categoría").tag(UUID?.none)
                        ForEach(store.folders) { c in Text(c.name).tag(UUID?.some(c.id)) }
                    }
                    .labelsHidden().pickerStyle(.menu)
                }
            }

            if let error {
                Text(error).font(.system(size: 11)).foregroundStyle(Theme.lilacGlow)
            }

            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }.buttonStyle(.glassy)
                Button {
                    if let e = store.createNewProject(name: name, parentPath: parentPath, categoryID: categoryID) {
                        error = e
                    } else {
                        dismiss()
                    }
                } label: { Label("Crear proyecto", systemImage: "plus") }
                    .buttonStyle(.glassy(tint: Theme.accent, prominent: true))
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(Theme.background)
        .onAppear { categoryID = presetCategory }
    }

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary).tracking(0.6)
            content()
        }
    }
}
