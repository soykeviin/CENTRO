//
//  ProjectCardView.swift
//  CENTRO
//
//  Tarjeta de proyecto con Liquid Glass, hover lift y acciones rápidas.
//

import SwiftUI

struct ProjectCardView: View {
    let project: Project
    @Bindable var store: ProjectStore
    @State private var hover = false
    @State private var flash = false
    @State private var confirmRemove = false
    @State private var showRename = false
    @State private var renameText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            stack                       // tecnologías, justo debajo del nombre
            Spacer(minLength: 0)
            if !hover {
                footer
            }
        }
        .padding(16)
        .frame(height: 168, alignment: .topLeading)
        .background(cardBackground)
        .overlay(alignment: .topTrailing) { topRightControls }
        .overlay(hover && !AppPrefs.shared.cardActions.isEmpty ? quickActions : nil, alignment: .bottom)
        .clipShape(.rect(cornerRadius: Theme.cardCorner))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCorner)
                .stroke(flash ? AnyShapeStyle(Theme.lilac) : AnyShapeStyle(.white.opacity(hover ? 0.20 : 0.08)),
                        lineWidth: flash ? 2 : 1)
        )
        .shadow(color: flash ? Theme.lilac.opacity(0.85) : .black.opacity(hover ? 0.45 : 0.25),
                radius: flash ? 28 : (hover ? 22 : 10), y: flash ? 0 : (hover ? 12 : 5))
        .scaleEffect(flash ? 1.04 : (hover ? 1.02 : 1))
        .offset(y: hover ? -2 : 0)
        .animation(.snappy, value: hover)
        .animation(.snappy, value: flash)
        .onHover { hover = $0 }
        .contentShape(.rect)
        .onTapGesture {
            flash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                store.selectedProjectID = project.id
            }
        }
        .draggable(project.path) {
            // preview de arrastre
            HStack(spacing: 8) {
                ProjectAvatar(project: project, size: 26, corner: 7)
                Text(project.displayName).font(.system(size: 12, weight: .semibold))
            }
            .padding(8).background(.ultraThinMaterial, in: .capsule)
        }
        .contextMenu { menu }
        .confirmationDialog(
            "¿Quitar «\(project.displayName)» de CENTRO?",
            isPresented: $confirmRemove,
            titleVisibility: .visible
        ) {
            Button("Quitar de CENTRO", role: .destructive) { store.removeProject(project.id) }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("No se borra ningún archivo del disco. El proyecto deja de aparecer en CENTRO (podés restaurarlo desde Configuración).")
        }
        .alert("Renombrar proyecto", isPresented: $showRename) {
            TextField("Nombre", text: $renameText)
            Button("Guardar") { store.rename(project.id, to: renameText) }
            Button("Cancelar", role: .cancel) { }
        }
    }

    // MARK: Partes

    private var header: some View {
        HStack(alignment: .top, spacing: 11) {
            ProjectAvatar(project: project, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if project.isPinned {
                        Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(Theme.accentSoft)
                    }
                    Text(project.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                }
                if !hover {
                    Text(shortPath)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 22)
        }
    }

    private var stack: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(project.detectedStack.prefix(5)) { StackBadgeView(badge: $0) }
            }
        }
        .frame(height: 22)
        .mask(LinearGradient(colors: [.black, .black, .clear],
                             startPoint: .leading, endPoint: .trailing))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if !project.exists {
                Label("Perdido", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Theme.lilacGlow)
            } else if let cat = category {
                HStack(spacing: 5) {
                    Image(systemName: cat.symbol).font(.system(size: 9, weight: .semibold))
                    Text(cat.name).font(.system(size: 10.5, weight: .medium)).lineLimit(1)
                }
                .foregroundStyle(cat.color)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(cat.color.opacity(0.15), in: .capsule)
            }
            if project.needsInstall { healthChip("npm i", "arrow.down.circle", .orange) }
            if project.missingEnv { healthChip(".env", "key", .yellow) }
            Spacer()
            GitBadgeView(git: project.git)
        }
    }

    private func healthChip(_ text: String, _ symbol: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 8, weight: .bold))
            Text(text).font(.system(size: 9.5, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(color.opacity(0.16), in: .capsule)
    }

    private var category: VirtualFolder? {
        guard let id = project.folderID else { return nil }
        return store.folders.first { $0.id == id }
    }

    private var topRightControls: some View {
        HStack(spacing: 2) {
            if hover {
                Button { store.hideProject(project.id) } label: {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Quitar de CENTRO")
                .transition(.opacity)
            }
            Button { store.toggleFavorite(project.id) } label: {
                Image(systemName: project.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(project.isFavorite ? AnyShapeStyle(Theme.accentSoft) : AnyShapeStyle(.secondary))
                    .padding(8)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .opacity(project.isFavorite || hover ? 1 : 0)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 8) {
            // Botones elegidos en Configuración → Botones de las tarjetas
            ForEach(LaunchAction.resolve(AppPrefs.shared.cardActions, custom: store.customActions)) { a in
                QuickActionButton(symbol: a.symbol, asset: a.asset, name: a.name) {
                    store.perform(a, on: project)
                }
            }
        }
        .padding(8)
        .liquidGlass(cornerRadius: 13, interactive: true)
        .padding(.bottom, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.cardCorner).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: Theme.cardCorner)
                .fill(LinearGradient(colors: [.white.opacity(0.06), .clear],
                                     startPoint: .top, endPoint: .bottom))
            // más oscuro al pasar el cursor
            RoundedRectangle(cornerRadius: Theme.cardCorner)
                .fill(.black.opacity(hover ? 0.34 : 0))
        }
    }

    @ViewBuilder private var menu: some View {
        Button { SystemActions.revealInFinder(project.path) } label: { Label("Mostrar en Finder", systemImage: "folder") }
        Button { SystemActions.runInTerminal(cwd: project.path, command: "") } label: { Label("Abrir en Terminal", systemImage: "terminal") }
        Button { SystemActions.openInVSCode(project.path) } label: { Label("Abrir en VS Code", systemImage: "chevron.left.forwardslash.chevron.right") }
        Divider()
        Button {
            renameText = project.displayName
            showRename = true
        } label: { Label("Renombrar", systemImage: "pencil") }
        Menu("Mover a categoría") {
            Button { store.setCategory(project.id, nil) } label: {
                Label("Sin categoría", systemImage: project.folderID == nil ? "checkmark" : "minus")
            }
            ForEach(store.folders) { f in
                Button { store.setCategory(project.id, f.id) } label: {
                    Label(f.name, systemImage: project.folderID == f.id ? "checkmark" : f.symbol)
                }
            }
        }
        Button { store.toggleFavorite(project.id) } label: {
            Label(project.isFavorite ? String(localized: "Quitar de favoritos") : String(localized: "Marcar favorito"), systemImage: "star")
        }
        Button { store.togglePin(project.id) } label: {
            Label(project.isPinned ? String(localized: "Desfijar") : String(localized: "Fijar arriba"), systemImage: "pin")
        }
        if project.needsInstall {
            Button {
                SystemActions.runInTerminal(cwd: project.path, command: "npm install"); store.markOpened(project.id)
            } label: { Label("npm install", systemImage: "arrow.down.circle") }
        }
        Divider()
        Button { store.hideProject(project.id) } label: {
            Label("Ocultar", systemImage: "eye.slash")
        }
        Button(role: .destructive) { confirmRemove = true } label: {
            Label("Quitar de CENTRO", systemImage: "trash")
        }
    }

    // MARK: Helpers

    private var initials: String {
        let words = project.name.split(whereSeparator: { " -_.".contains($0) })
        let first = words.first?.first.map(String.init) ?? "?"
        let second = words.dropFirst().first?.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }

    private var shortPath: String {
        project.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}
