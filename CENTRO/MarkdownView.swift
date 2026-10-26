//
//  MarkdownView.swift
//  CENTRO
//
//  Renderizador liviano de Markdown (encabezados, listas, código, inline).
//

import SwiftUI

struct MarkdownView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
    }

    // MARK: Bloques

    private enum Block {
        case heading(Int, String)
        case paragraph(String)
        case bullets([String])
        case code(String)
    }

    @ViewBuilder
    private func view(for block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            attributed(text)
                .font(.system(size: level == 1 ? 22 : level == 2 ? 18 : 15,
                              weight: .bold, design: .rounded))
                .padding(.top, level == 1 ? 4 : 2)
        case .paragraph(let text):
            attributed(text).font(.system(size: 13)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(Theme.accent).frame(width: 5, height: 5).padding(.top, 6)
                        attributed(item).font(.system(size: 13)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .code(let code):
            Text(code)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.35), in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 1))
        }
    }

    private func attributed(_ s: String) -> Text {
        if let a = try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(a)
        }
        return Text(s)
    }

    // MARK: Parser

    private var blocks: [Block] {
        var result: [Block] = []
        var inCode = false
        var codeLines: [String] = []
        var para: [String] = []
        var bullets: [String] = []

        func flushPara() { if !para.isEmpty { result.append(.paragraph(para.joined(separator: " "))); para = [] } }
        func flushBullets() { if !bullets.isEmpty { result.append(.bullets(bullets)); bullets = [] } }

        for raw in markdown.components(separatedBy: "\n") {
            let t = raw.trimmingCharacters(in: .whitespaces)

            if t.hasPrefix("```") {
                if inCode { result.append(.code(codeLines.joined(separator: "\n"))); codeLines = []; inCode = false }
                else { flushPara(); flushBullets(); inCode = true }
                continue
            }
            if inCode { codeLines.append(raw); continue }

            if t.isEmpty { flushPara(); flushBullets(); continue }
            if t.hasPrefix("### ") { flushPara(); flushBullets(); result.append(.heading(3, String(t.dropFirst(4)))); continue }
            if t.hasPrefix("## ")  { flushPara(); flushBullets(); result.append(.heading(2, String(t.dropFirst(3)))); continue }
            if t.hasPrefix("# ")   { flushPara(); flushBullets(); result.append(.heading(1, String(t.dropFirst(2)))); continue }
            if t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("+ ") {
                flushPara(); bullets.append(String(t.dropFirst(2))); continue
            }
            if let r = t.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                flushPara(); bullets.append(String(t[r.upperBound...])); continue
            }
            flushBullets()
            para.append(t)
        }
        flushPara(); flushBullets()
        if inCode && !codeLines.isEmpty { result.append(.code(codeLines.joined(separator: "\n"))) }
        return result
    }
}
