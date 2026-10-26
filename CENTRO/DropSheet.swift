//
//  DropSheet.swift
//  CENTRO
//
//  Panel al soltar archivos: elegir proyecto destino y copiar/mover.
//

import SwiftUI

struct DropSheet: View {
    @Bindable var store: ProjectStore
    let files: [URL]
    @Environment(\.dismiss) private var dismiss

    @State private var search = ""
    @State private var categoryFilter: UUID? = nil
    @State private var selected: String? = nil      // ruta destino
    @State private var showRecent = false
    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            filesList
            Divider().overlay(.white.opacity(0.08))
            destinationPicker
            if let error {
                Text(error).font(.system(size: 11)).foregroundStyle(Theme.lilacGlow)
            }
            footer
        }
        .padding(22)
        .frame(width: 540, height: 600)
        .background(Theme.background)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 18)).foregroundStyle(Theme.accent)
            (files.count == 1 ? Text("Soltaste \(files.count) elemento") : Text("Soltaste \(files.count) elementos"))
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Spacer()
        }
    }

    private var filesList: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(files, id: \.self) { url in
                    HStack(spacing: 10) {
                        Image(systemName: isDir(url) ? "folder.fill" : "doc.fill")
                            .foregroundStyle(isDir(url) ? AnyShapeStyle(Theme.accentSoft) : AnyShapeStyle(.secondary))
                        Text(url.lastPathComponent).font(.system(size: 12.5)).lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .liquidGlass(cornerRadius: 10)
                }
            }
        }
        .frame(maxHeight: 130)
    }

    // MARK: Destino

    private var destinationPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PONER EN").font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary).tracking(0.6)
                Spacer()
                Button {
                    withAnimation(.snappy) { showRecent.toggle() }
                } label: {
                    Label("Reciente", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(showRecent ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
                }
                .buttonStyle(.plain)
                .opacity(store.recentDropDestinations.isEmpty ? 0.4 : 1)
                .disabled(store.recentDropDestinations.isEmpty)
            }

            if showRecent {
                recentList
            } else {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(.secondary)
                        TextField("Buscar proyecto…", text: $search)
                            .textFieldStyle(.plain).font(.system(size: 12))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .liquidGlass(cornerRadius: 9)

                    if !store.folders.isEmpty {
                        Picker("", selection: $categoryFilter) {
                            Text("Todas").tag(UUID?.none)
                            ForEach(store.folders) { c in Text(c.name).tag(UUID?.some(c.id)) }
                        }
                        .labelsHidden().pickerStyle(.menu).frame(width: 130)
                    }
                }
                projectsList
            }
        }
    }

    private var projectsList: some View {
        ScrollView {
            VStack(spacing: 3) {
                ForEach(filteredProjects) { p in
                    destinationRow(name: p.displayName, path: p.path,
                                   subtitle: shortPath(p.path), icon: nil, project: p)
                }
                if filteredProjects.isEmpty {
                    Text("Sin resultados").font(.system(size: 11)).foregroundStyle(.tertiary).padding(.vertical, 10)
                }
            }
        }
        .frame(maxHeight: 200)
    }

    private var recentList: some View {
        ScrollView {
            VStack(spacing: 3) {
                ForEach(store.recentDropDestinations, id: \.self) { path in
                    destinationRow(name: (path as NSString).lastPathComponent, path: path,
                                   subtitle: shortPath(path), icon: "clock", project: nil)
                }
            }
        }
        .frame(maxHeight: 240)
    }

    private func destinationRow(name: String, path: String, subtitle: String, icon: String?, project: Project?) -> some View {
        let isSel = selected == path
        return Button {
            withAnimation(.snappy) { selected = path }
        } label: {
            HStack(spacing: 10) {
                if let project { ProjectAvatar(project: project, size: 26, corner: 7) }
                else { Image(systemName: icon ?? "folder.fill").foregroundStyle(Theme.accentSoft).frame(width: 26) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                    Text(subtitle).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary).lineLimit(1)
                }
                Spacer()
                if isSel { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background {
                if isSel {
                    RoundedRectangle(cornerRadius: 9).fill(Theme.accent.opacity(0.14))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.accent.opacity(0.3), lineWidth: 0.5))
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            if let selected {
                Text("→ \((selected as NSString).lastPathComponent)")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button("Cancelar") { dismiss() }.buttonStyle(.glassy)
            Button { perform(move: false) } label: { Label("Copiar acá", systemImage: "doc.on.doc") }
                .buttonStyle(.glassy).disabled(selected == nil)
            Button { perform(move: true) } label: { Label("Mover acá", systemImage: "arrow.right.doc.on.clipboard") }
                .buttonStyle(.glassy(tint: Theme.accent, prominent: true)).disabled(selected == nil)
        }
    }

    // MARK: Helpers

    private var filteredProjects: [Project] {
        var list = store.projects.filter { $0.exists && !$0.isHidden }
        if let cat = categoryFilter { list = list.filter { $0.folderID == cat } }
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty { list = list.filter { $0.displayName.lowercased().contains(q) } }
        return list.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func perform(move: Bool) {
        guard let dest = selected else { return }
        if let e = store.dropFiles(files, to: dest, move: move) { error = e }
        else { dismiss() }
    }

    private func isDir(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
    private func shortPath(_ p: String) -> String {
        p.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}
