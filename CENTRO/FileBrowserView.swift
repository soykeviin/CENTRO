//
//  FileBrowserView.swift
//  CENTRO
//
//  Explorador de archivos de un proyecto: navega carpetas y abre archivos.
//

import SwiftUI

struct FileBrowserView: View {
    let rootPath: String
    @State private var currentPath: String
    @State private var entries: [Entry] = []

    init(rootPath: String) {
        self.rootPath = rootPath
        _currentPath = State(initialValue: rootPath)
    }

    struct Entry: Identifiable, Hashable {
        let name: String
        let path: String
        let isDir: Bool
        var id: String { path }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            breadcrumb
            VStack(spacing: 2) {
                if entries.isEmpty {
                    Text("Carpeta vacía")
                        .font(.system(size: 12)).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
                ForEach(entries) { entry in
                    rowView(entry)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: 14)
        }
        .onAppear(perform: reload)
        .onChange(of: currentPath) { _, _ in reload() }
    }

    private var breadcrumb: some View {
        HStack(spacing: 6) {
            if currentPath != rootPath {
                Button {
                    currentPath = (currentPath as NSString).deletingLastPathComponent
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
            Image(systemName: "folder.fill").font(.system(size: 11)).foregroundStyle(.secondary)
            Text(relativeCrumb)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.head)
            Spacer()
            Button { SystemActions.revealInFinder(currentPath) } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Mostrar en Finder")
        }
    }

    private func rowView(_ entry: Entry) -> some View {
        HStack(spacing: 10) {
            Button {
                if entry.isDir { currentPath = entry.path }
                else { SystemActions.open(entry.path) }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon(for: entry))
                        .font(.system(size: 13))
                        .foregroundStyle(entry.isDir ? AnyShapeStyle(Theme.accentSoft) : AnyShapeStyle(.secondary))
                        .frame(width: 20)
                    Text(entry.name).font(.system(size: 12.5)).foregroundStyle(.primary).lineLimit(1)
                    Spacer()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            // Quick Look
            Button { SystemActions.quickLook(entry.path) } label: {
                Image(systemName: "eye").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain).help("Vista rápida (Quick Look)")

            if entry.isDir {
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .contextMenu {
            Button { SystemActions.quickLook(entry.path) } label: { Label("Vista rápida", systemImage: "eye") }
            Button { SystemActions.revealInFinder(entry.path) } label: { Label("Mostrar en Finder", systemImage: "folder") }
            Button { SystemActions.open(entry.path) } label: { Label("Abrir", systemImage: "arrow.up.forward.app") }
        }
    }

    private var relativeCrumb: String {
        let base = (rootPath as NSString).lastPathComponent
        if currentPath == rootPath { return base }
        let rel = currentPath.replacingOccurrences(of: rootPath, with: "")
        return base + rel
    }

    private func icon(for entry: Entry) -> String {
        if entry.isDir { return "folder.fill" }
        switch (entry.name as NSString).pathExtension.lowercased() {
        case "swift": return "swift"
        case "js", "ts", "tsx", "jsx", "py", "rb", "go", "rs", "java", "kt", "c", "cpp", "h": return "chevron.left.forwardslash.chevron.right"
        case "json", "yml", "yaml", "toml", "xml", "plist": return "curlybraces"
        case "md", "txt", "rtf": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "icns", "ico": return "photo"
        case "pdf": return "doc.richtext"
        case "zip", "tar", "gz", "dmg": return "archivebox"
        default: return "doc"
        }
    }

    private func reload() {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(
            at: URL(fileURLWithPath: currentPath),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles])) ?? []
        entries = urls.map { url in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            return Entry(name: url.lastPathComponent, path: url.path, isDir: isDir)
        }
        .sorted {
            if $0.isDir != $1.isDir { return $0.isDir }   // carpetas primero
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
