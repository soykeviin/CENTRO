//
//  StackDetector.swift
//  CENTRO
//
//  Detecta el stack de un proyecto leyendo su carpeta.
//  Port nativo de server/src/lib/stack-detect.ts
//

import Foundation

nonisolated enum StackDetector {

    private static let frameworkMap: [(dep: String, label: String)] = [
        ("next", "Next.js"), ("nuxt", "Nuxt"), ("react", "React"), ("vue", "Vue"),
        ("svelte", "Svelte"), ("@angular/core", "Angular"), ("astro", "Astro"),
        ("remix", "Remix"), ("solid-js", "SolidJS"), ("express", "Express"),
        ("fastify", "Fastify"), ("koa", "Koa"), ("@nestjs/core", "NestJS"),
        ("vite", "Vite"), ("webpack", "Webpack"), ("electron", "Electron"),
        ("@tauri-apps/api", "Tauri"), ("react-native", "React Native"),
        ("expo", "Expo"), ("tailwindcss", "Tailwind"), ("prisma", "Prisma"),
        ("drizzle-orm", "Drizzle"), ("typescript", "TypeScript")
    ]

    static func detect(at path: String) -> [StackBadge] {
        let fm = FileManager.default
        var badges: [StackBadge] = []
        var seen = Set<String>()

        func add(_ label: String, _ cat: StackCategory) {
            guard !seen.contains(label) else { return }
            seen.insert(label)
            badges.append(StackBadge(label: label, category: cat))
        }
        func has(_ rel: String) -> Bool {
            fm.fileExists(atPath: (path as NSString).appendingPathComponent(rel))
        }

        let entries = (try? fm.contentsOfDirectory(atPath: path)) ?? []

        // package.json
        if has("package.json") {
            add("Node", .runtime)
            if let data = fm.contents(atPath: (path as NSString).appendingPathComponent("package.json")),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var deps: [String: Any] = [:]
                (json["dependencies"] as? [String: Any]).map { deps.merge($0) { a, _ in a } }
                (json["devDependencies"] as? [String: Any]).map { deps.merge($0) { a, _ in a } }
                for fw in frameworkMap where deps[fw.dep] != nil {
                    add(fw.label, fw.label == "TypeScript" ? .language : .framework)
                }
            }
        }

        if has("Cargo.toml") { add("Rust", .language) }
        if has("requirements.txt") || has("pyproject.toml") || has("Pipfile") || has("setup.py") { add("Python", .language) }
        if has("manage.py") { add("Django", .framework) }
        if has("go.mod") { add("Go", .language) }
        if has("Gemfile") { add("Ruby", .language) }
        if has("config/routes.rb") { add("Rails", .framework) }
        if has("composer.json") { add("PHP", .language) }
        if has("artisan") { add("Laravel", .framework) }
        if has("pom.xml") { add("Java/Maven", .language) }
        if has("build.gradle") || has("build.gradle.kts") { add("Gradle", .tool) }
        if has("Package.swift") { add("Swift", .language) }
        if entries.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) { add("Xcode", .tool) }
        if entries.contains(where: { $0.hasSuffix(".uproject") }) { add("Unreal", .framework) }
        if entries.contains(where: { $0.hasSuffix(".csproj") || $0.hasSuffix(".sln") }) { add(".NET", .language) }
        if has("ProjectSettings/ProjectVersion.txt") { add("Unity", .framework) }
        if has("Dockerfile") || has("docker-compose.yml") || has("docker-compose.yaml") { add("Docker", .tool) }
        if has("pubspec.yaml") { add("Flutter/Dart", .language) }

        return badges
    }

    /// Busca un ícono dentro de la carpeta del proyecto (.ico tiene prioridad).
    static func findIcon(at path: String) -> String? {
        let fm = FileManager.default
        func full(_ rel: String) -> String { (path as NSString).appendingPathComponent(rel) }
        func exists(_ rel: String) -> Bool { fm.fileExists(atPath: full(rel)) }

        // 1) Candidatos típicos por nombre (incluye subcarpetas comunes)
        let named = [
            "icon.ico", "favicon.ico", "app.ico",
            "icon.icns", "AppIcon.icns", "app.icns",
            "icon.png", "logo.png", "favicon.png", "app-icon.png", "appicon.png",
            "public/favicon.ico", "public/logo.png", "public/icon.png",
            "assets/icon.png", "assets/logo.png", "src/assets/logo.png",
            "build/icon.png", "build/icon.icns"
        ]
        for c in named where exists(c) { return full(c) }

        // 2) Cualquier .ico / .icns en el nivel superior
        if let entries = try? fm.contentsOfDirectory(atPath: path) {
            if let ico = entries.first(where: { $0.lowercased().hasSuffix(".ico") }) { return full(ico) }
            if let icns = entries.first(where: { $0.lowercased().hasSuffix(".icns") }) { return full(icns) }
        }
        return nil
    }

    // MARK: Smart actions — port de server/src/lib/smart-actions.ts

    static func smartActions(at path: String) -> [SmartAction] {
        let fm = FileManager.default
        var actions: [SmartAction] = []
        func has(_ rel: String) -> Bool {
            fm.fileExists(atPath: (path as NSString).appendingPathComponent(rel))
        }
        let entries = (try? fm.contentsOfDirectory(atPath: path)) ?? []

        // package.json scripts
        if let data = fm.contents(atPath: (path as NSString).appendingPathComponent("package.json")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let scripts = json["scripts"] as? [String: Any] {
            for key in ["dev", "start", "build", "test", "lint"] where scripts[key] != nil {
                let icon = (key == "dev" || key == "start") ? "play.fill"
                         : key == "build" ? "hammer.fill"
                         : key == "test" ? "testtube.2" : "terminal"
                actions.append(.init(id: "npm-\(key)", label: "npm run \(key)", systemImage: icon,
                                     command: "npm run \(key)", opensIn: .terminal))
            }
        }
        if has("Cargo.toml") {
            actions.append(.init(id: "cargo-run", label: "cargo run", systemImage: "play.fill", command: "cargo run", opensIn: .terminal))
            actions.append(.init(id: "cargo-test", label: "cargo test", systemImage: "testtube.2", command: "cargo test", opensIn: .terminal))
        }
        if has("manage.py") {
            actions.append(.init(id: "django", label: "Django runserver", systemImage: "play.fill", command: "python manage.py runserver", opensIn: .terminal))
        }
        if has("go.mod") {
            actions.append(.init(id: "go-run", label: "go run .", systemImage: "play.fill", command: "go run .", opensIn: .terminal))
        }
        if has("docker-compose.yml") || has("docker-compose.yaml") {
            actions.append(.init(id: "docker-up", label: "docker compose up", systemImage: "shippingbox.fill", command: "docker compose up", opensIn: .terminal))
        }
        if let xcw = entries.first(where: { $0.hasSuffix(".xcworkspace") }) {
            actions.append(.init(id: "xcw", label: String(localized: "Abrir en Xcode"), systemImage: "hammer.fill",
                                 command: (path as NSString).appendingPathComponent(xcw), opensIn: .background))
        } else if let xcp = entries.first(where: { $0.hasSuffix(".xcodeproj") }) {
            actions.append(.init(id: "xcp", label: String(localized: "Abrir en Xcode"), systemImage: "hammer.fill",
                                 command: (path as NSString).appendingPathComponent(xcp), opensIn: .background))
        }
        if has(".git") {
            actions.append(.init(id: "git-pull", label: "git pull", systemImage: "arrow.down.circle", command: "git pull", opensIn: .terminal))
            actions.append(.init(id: "git-status", label: "git status", systemImage: "arrow.triangle.branch", command: "git status", opensIn: .terminal))
        }
        return actions
    }
}
