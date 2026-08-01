import Foundation

/// Markdown to HTML on top of Foundation's own CommonMark parser
/// (`AttributedString(markdown:)`) — full links, images, nested lists,
/// block quotes, code fences and thematic breaks, with zero third-party
/// dependencies. The plugin still only CONVERTS; the host renders the HTML
/// (and themes it for light/dark, so this emits no colors).
public enum MarkdownRenderer {
    public static func html(from markdown: String) -> String {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: false,
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible)
        let stripped = strippingRawHTML(markdown)
        guard let parsed = try? AttributedString(markdown: stripped, options: options) else {
            // A document the parser refuses still shows as readable text.
            return wrap("<pre>\(escaped(markdown))</pre>")
        }
        var out = ""
        // The open block-intent stack, outermost first, diffed run to run.
        // Each entry remembers the tag it emitted (nil = suppressed, e.g.
        // a paragraph directly inside a list item).
        var open: [(component: PresentationIntent.IntentType, tag: String?)] = []

        for run in parsed.runs {
            let text = String(parsed[run.range].characters)
            // Outermost-first (components come innermost-first).
            let stack = (run.presentationIntent?.components ?? []).reversed()
                .filter { tag(for: $0.kind) != nil || isBreak($0.kind) }

            // Close what's no longer open, innermost first.
            let common = zip(open, stack)
                .prefix { $0.0.component.identity == $0.1.identity }.count
            for entry in open[common...].reversed() {
                if let tag = entry.tag { out += "</\(tag)>\n" }
            }
            open.removeSubrange(common...)
            // Open what's new, outermost first.
            for component in stack.dropFirst(common) {
                if isBreak(component.kind) {
                    out += "<hr>\n"
                    open.append((component, nil))
                    continue
                }
                var tag = tag(for: component.kind)
                // A paragraph as a list item's direct content needs no <p> —
                // it would double the item's spacing.
                if case .paragraph = component.kind,
                   case .listItem = open.last?.component.kind { tag = nil }
                if let tag { out += "<\(tag)>" }
                open.append((component, tag))
            }
            if stack.contains(where: { isBreak($0.kind) }) { continue }
            out += inlineHTML(for: run, text: text)
        }
        for entry in open.reversed() {
            if let tag = entry.tag { out += "</\(tag)>\n" }
        }
        return wrap(out)
    }

    /// The HTML element for a block intent; nil for intents that need no
    /// element of their own (list-item paragraphs read fine bare).
    private static func tag(for kind: PresentationIntent.Kind) -> String? {
        switch kind {
        case .paragraph: "p"
        case .header(let level): "h\(min(max(level, 1), 6))"
        case .unorderedList: "ul"
        case .orderedList: "ol"
        case .listItem: "li"
        case .blockQuote: "blockquote"
        case .codeBlock: "pre"
        case .table: "table"
        case .tableHeaderRow, .tableRow: "tr"
        case .tableCell: "td"
        default: nil
        }
    }

    private static func isBreak(_ kind: PresentationIntent.Kind) -> Bool {
        if case .thematicBreak = kind { return true }
        return false
    }

    /// One run's text with its inline markup: code/strong/em/strikethrough,
    /// links, and images (shown as their alt text, linked when a link wraps
    /// them — a converted document never fetches remote resources).
    private static func inlineHTML(for run: AttributedString.Runs.Run, text: String) -> String {
        var html = escaped(text)
        if let inline = run.inlinePresentationIntent {
            if inline.contains(.code) { html = "<code>\(html)</code>" }
            if inline.contains(.stronglyEmphasized) { html = "<strong>\(html)</strong>" }
            if inline.contains(.emphasized) { html = "<em>\(html)</em>" }
            if inline.contains(.strikethrough) { html = "<del>\(html)</del>" }
        }
        if run.imageURL != nil {
            let alt = text.isEmpty ? "image" : text
            html = "[\(escaped(alt))]"
        }
        if let link = run.link {
            html = "<a href=\"\(escaped(link.absoluteString))\">\(html)</a>"
        }
        return html
    }

    /// Removes raw HTML tags before parsing — a converted page must not
    /// carry the source's tags (they'd show literally once escaped, the
    /// "<a id=…> on screen" defect) — EXCEPT inside code fences and inline
    /// code spans: code examples keep their tags and render escaped.
    static func strippingRawHTML(_ markdown: String) -> String {
        var out: [String] = []
        var inFence = false
        for line in markdown.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                inFence.toggle()
                out.append(line)
                continue
            }
            if inFence {
                out.append(line)
                continue
            }
            // Even-indexed segments are outside inline code spans.
            let parts = line.components(separatedBy: "`")
            out.append(parts.enumerated().map { index, part in
                index % 2 == 0
                    ? part.replacingOccurrences(
                        of: "</?[a-zA-Z][^>]*>", with: "", options: .regularExpression)
                    : part
            }.joined(separator: "`"))
        }
        return out.joined(separator: "\n")
    }

    static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func wrap(_ body: String) -> String {
        "<html><body>\n\(body)\n</body></html>"
    }
}
