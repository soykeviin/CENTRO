//
//  SectionViews.swift
//  CENTRO
//
//  Secciones: Tareas, Inbox, Time tracking, Actividad, Daily digest, Deps.
//

import SwiftUI
import Charts

// MARK: - Tareas

struct TasksView: View {
    @Bindable var store: ProjectStore
    @State private var text = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                inputBar(placeholder: "Agregar tarea…", text: $text) {
                    store.addTodo(text); text = ""
                }
                if store.todos.isEmpty {
                    emptyHint("checklist", "Sin tareas", "Anotá lo que tengas pendiente.")
                } else {
                    let pending = store.todos.filter { !$0.done }
                    let done = store.todos.filter { $0.done }
                    ForEach(pending) { todoRow($0) }
                    if !done.isEmpty {
                        Text("Completadas").font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.tertiary).padding(.top, 8)
                        ForEach(done) { todoRow($0) }
                    }
                }
                Spacer(minLength: 20)
            }
            .padding(28).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }

    private func todoRow(_ todo: TodoItem) -> some View {
        HStack(spacing: 12) {
            Button { store.toggleTodo(todo.id) } label: {
                Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17)).foregroundStyle(todo.done ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
            }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.text).font(.system(size: 13))
                    .strikethrough(todo.done).foregroundStyle(todo.done ? .secondary : .primary)
                if let p = todo.projectPath {
                    Text(store.projectName(forPath: p)).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button { store.removeTodo(todo.id) } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.tertiary)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .liquidGlass(cornerRadius: 12)
    }
}

// MARK: - Inbox

struct InboxView: View {
    @Bindable var store: ProjectStore
    @State private var text = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                inputBar(placeholder: "Captura rápida…", text: $text) {
                    store.addInbox(text); text = ""
                }
                if store.inboxItems.isEmpty {
                    emptyHint("tray", "Inbox vacío", "Capturá ideas al vuelo y procesalas después.")
                } else {
                    ForEach(store.inboxItems) { item in
                        HStack(spacing: 12) {
                            Image(systemName: "tray.fill").font(.system(size: 13)).foregroundStyle(Theme.accentSoft)
                            Text(item.text).font(.system(size: 13))
                            Spacer()
                            Button { store.inboxToTodo(item.id) } label: {
                                Image(systemName: "arrow.right.circle").foregroundStyle(.secondary)
                            }.buttonStyle(.plain).help("Convertir en tarea")
                            Button { store.removeInbox(item.id) } label: {
                                Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.tertiary)
                            }.buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .liquidGlass(cornerRadius: 12)
                    }
                }
                Spacer(minLength: 20)
            }
            .padding(28).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Time tracking

struct TimeTrackingView: View {
    @Bindable var store: ProjectStore
    @State private var search = ""

    private var recents: [Project] {
        store.projects.filter { $0.exists && store.totalSeconds(forProject: $0.path) > 0 }
            .sorted { store.lastSessionDate(forProject: $0.path) > store.lastSessionDate(forProject: $1.path) }
    }
    private var allProjects: [Project] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        var list = store.projects.filter { $0.exists }
        if !q.isEmpty { list = list.filter { $0.displayName.lowercased().contains(q) } }
        return list.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let active = store.activeSession {
                    activeCard(active)
                }

                weeklyChart

                // Buscador
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.secondary)
                    TextField("Buscar proyecto…", text: $search)
                        .textFieldStyle(.plain).font(.system(size: 13))
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .liquidGlass(cornerRadius: 11)

                if store.projects.filter({ $0.exists }).isEmpty {
                    emptyHint("timer", "Sin proyectos", "Cargá proyectos para registrar tiempo.")
                } else {
                    if search.isEmpty && !recents.isEmpty {
                        Label("Recientes", systemImage: "clock.fill")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
                        ForEach(recents.prefix(5)) { p in projectRow(p) }
                    }
                    Label(search.isEmpty ? String(localized: "Todos los proyectos") : String(localized: "Resultados"), systemImage: "square.grid.2x2.fill")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
                        .padding(.top, recents.isEmpty || !search.isEmpty ? 0 : 6)
                    ForEach(allProjects) { p in projectRow(p) }
                    if allProjects.isEmpty {
                        Text("Sin resultados").font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 20)
            }
            .padding(28).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }

    private var weeklyChart: some View {
        let _ = store.tick
        let data = store.secondsPerDay(lastDays: 7)
        let total = data.reduce(0) { $0 + $1.seconds }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Esta semana", systemImage: "chart.bar.fill")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
                Spacer()
                Text(formatHM(total)).font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.accent)
            }
            Chart(data, id: \.date) { item in
                BarMark(
                    x: .value("Día", item.date, unit: .day),
                    y: .value("Horas", Double(item.seconds) / 3600.0)
                )
                .foregroundStyle(LinearGradient(colors: [Theme.accent, Theme.accentSoft],
                                                startPoint: .bottom, endPoint: .top))
                .cornerRadius(5)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 130)
        }
        .padding(16)
        .liquidGlass(cornerRadius: 16)
    }

    private func activeCard(_ s: TimeSession) -> some View {
        let _ = store.tick
        return HStack(spacing: 14) {
            Image(systemName: "timer").font(.system(size: 22)).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.projectName(forPath: s.projectPath)).font(.system(size: 14, weight: .semibold))
                Text(formatHMS(s.seconds)).font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .contentTransition(.numericText())
            }
            Spacer()
            Button { store.stopTimer() } label: {
                Label("Detener", systemImage: "stop.fill")
            }.buttonStyle(.glassy(tint: Theme.accent, prominent: true))
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 16)
    }

    private func projectRow(_ p: Project) -> some View {
        let total = store.totalSeconds(forProject: p.path)
        let isActive = store.activeSession?.projectPath == p.path
        return HStack(spacing: 12) {
            ProjectAvatar(project: p, size: 30, corner: 8)
            Text(p.displayName).font(.system(size: 13, weight: .medium))
            Spacer()
            if total > 0 {
                Text(formatHM(total)).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            }
            Button { isActive ? store.stopTimer() : store.startTimer(projectPath: p.path) } label: {
                Image(systemName: isActive ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 20)).foregroundStyle(isActive ? AnyShapeStyle(Theme.lilacGlow) : AnyShapeStyle(Theme.accent))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .liquidGlass(cornerRadius: 12)
    }
}

// MARK: - Actividad

struct ActivityView: View {
    @Bindable var store: ProjectStore
    @State private var data: [ProjectActivity] = []
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if loading {
                    loadingRow(String(localized: "Analizando commits…"))
                } else if data.isEmpty {
                    emptyHint("waveform.path.ecg", "Sin actividad", "No se encontraron commits de git en tus proyectos.")
                } else {
                    ForEach(data) { act in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(act.projectName).font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Text("\(act.totalCommits) commits")
                                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.accentSoft)
                            }
                            Heatmap(byDay: act.byDay)
                            ForEach(Array(act.recent.prefix(3).enumerated()), id: \.offset) { _, c in
                                HStack(spacing: 6) {
                                    Circle().fill(.tertiary).frame(width: 4, height: 4)
                                    Text(c.subject).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                                    Spacer()
                                    Text(c.date).font(.system(size: 10)).foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .liquidGlass(cornerRadius: 14)
                    }
                }
                Spacer(minLength: 20)
            }
            .padding(28).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .task(id: store.projects.count) {
            loading = true
            data = await Insights.activity(for: store.projects)
            loading = false
        }
    }
}

/// Mini heatmap de las últimas ~15 semanas.
struct Heatmap: View {
    let byDay: [String: Int]
    private let cols = 15, rows = 7

    var body: some View {
        let fmt = DateFormatter(); let _ = (fmt.dateFormat = "yyyy-MM-dd")
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        HStack(spacing: 3) {
            ForEach(0..<cols, id: \.self) { c in
                VStack(spacing: 3) {
                    ForEach(0..<rows, id: \.self) { r in
                        let offset = (cols - 1 - c) * rows + (rows - 1 - r)
                        let day = cal.date(byAdding: .day, value: -offset, to: today)!
                        let key = fmt.string(from: day)
                        let count = byDay[key] ?? 0
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.accent.opacity(count == 0 ? 0.08 : min(0.25 + Double(count) * 0.2, 1.0)))
                            .frame(width: 9, height: 9)
                    }
                }
            }
        }
    }
}

// MARK: - Daily digest

struct DigestView: View {
    @Bindable var store: ProjectStore
    @State private var commits: [Insights.DigestCommit] = []
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if loading {
                    loadingRow(String(localized: "Revisando los commits de hoy…"))
                } else if commits.isEmpty {
                    emptyHint("calendar", "Día tranquilo", "Todavía no hay commits hoy. ¡A codear!")
                } else {
                    let files = commits.reduce(0) { $0 + $1.files }
                    let ins = commits.reduce(0) { $0 + $1.insertions }
                    let del = commits.reduce(0) { $0 + $1.deletions }
                    HStack(spacing: 12) {
                        digestStat("\(commits.count)", "commits", Theme.accent)
                        digestStat("\(files)", "archivos", Theme.accentSoft)
                        digestStat("+\(ins)", "líneas", .green)
                        digestStat("-\(del)", "líneas", Theme.lilacGlow)
                    }
                    ForEach(commits) { c in
                        HStack(spacing: 10) {
                            Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.subject).font(.system(size: 12.5)).lineLimit(1)
                                Text(c.projectName).font(.system(size: 10)).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Text("+\(c.insertions) −\(c.deletions)")
                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .liquidGlass(cornerRadius: 12)
                    }
                }
                Spacer(minLength: 20)
            }
            .padding(28).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .task(id: store.projects.count) {
            loading = true
            commits = await Insights.digestToday(for: store.projects)
            loading = false
        }
    }

    private func digestStat(_ value: String, _ label: LocalizedStringKey, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(color)
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14).liquidGlass(cornerRadius: 14)
    }
}

// MARK: - Deps desactualizadas

struct DepsView: View {
    @Bindable var store: ProjectStore
    @State private var results: [(project: Project, deps: [OutdatedDep])] = []
    @State private var loading = false
    @State private var checked = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Revisa dependencias npm desactualizadas en tus proyectos.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Button { Task { await check() } } label: {
                        Label(loading ? String(localized: "Revisando…") : String(localized: "Revisar"), systemImage: "arrow.clockwise")
                    }.buttonStyle(.glassy(tint: Theme.accent, prominent: true)).disabled(loading)
                }
                if loading {
                    loadingRow(String(localized: "Corriendo npm outdated… (puede tardar)"))
                } else if checked && results.isEmpty {
                    emptyHint("checkmark.seal", "Todo al día", "No se encontraron dependencias desactualizadas.")
                } else if !checked {
                    emptyHint("shippingbox", "Sin revisar", "Tocá «Revisar» para analizar tus proyectos npm.")
                } else {
                    ForEach(results, id: \.project.id) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.project.displayName).font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Text("\(item.deps.count) desactualizadas")
                                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.lilacGlow)
                            }
                            ForEach(item.deps.prefix(12)) { dep in
                                HStack(spacing: 8) {
                                    Text(dep.name).font(.system(size: 12, weight: .medium, design: .monospaced))
                                    Spacer()
                                    Text(dep.current).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                                    Image(systemName: "arrow.right").font(.system(size: 9)).foregroundStyle(.tertiary)
                                    Text(dep.latest).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.accent)
                                }
                            }
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .liquidGlass(cornerRadius: 14)
                    }
                }
                Spacer(minLength: 20)
            }
            .padding(28).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }

    private func check() async {
        loading = true
        results = await Insights.outdated(for: store.projects)
        loading = false
        checked = true
    }
}

// MARK: - Helpers compartidos

@ViewBuilder
func inputBar(placeholder: LocalizedStringKey, text: Binding<String>, onSubmit: @escaping () -> Void) -> some View {
    HStack(spacing: 10) {
        Image(systemName: "plus.circle.fill").font(.system(size: 16)).foregroundStyle(Theme.accent)
        TextField(placeholder, text: text)
            .textFieldStyle(.plain).font(.system(size: 13))
            .onSubmit(onSubmit)
        if !text.wrappedValue.isEmpty {
            Button(action: onSubmit) {
                Text("Agregar").font(.system(size: 11, weight: .semibold))
            }.buttonStyle(.glassy(tint: Theme.accent))
        }
    }
    .padding(.horizontal, 14).padding(.vertical, 11)
    .liquidGlass(cornerRadius: 12)
}

@ViewBuilder
func emptyHint(_ symbol: String, _ title: LocalizedStringKey, _ message: LocalizedStringKey) -> some View {
    VStack(spacing: 10) {
        Image(systemName: symbol).font(.system(size: 38, weight: .light)).foregroundStyle(Theme.accent.gradient)
        Text(title).font(.system(size: 16, weight: .bold))
        Text(message).font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity).padding(.vertical, 50)
}

@ViewBuilder
func loadingRow(_ text: String) -> some View {
    HStack(spacing: 10) {
        ProgressView().controlSize(.small)
        Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity).padding(.vertical, 40)
}

func formatHMS(_ s: Int) -> String {
    String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
}
func formatHM(_ s: Int) -> String {
    let h = s / 3600, m = (s % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
}
