import Foundation

/// Markdown to HTML, kept small and pure so it is testable without a host.
/// Deliberately not a full CommonMark implementation: a sample should show
/// how a viewer plugin is *shaped*, and the shape is "convert, hand back,
/// let the host render".
public enum MarkdownRenderer {
    public static func html(from markdown: String) -> String {
        var out: [String] = []
        var inList = false
        var inCode = false
        for rawLine in markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                out.append(inCode ? "</pre>" : "<pre>")
                inCode.toggle()
                continue
            }
            if inCode {
                out.append(escaped(rawLine))
                continue
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                if !inList { out.append("<ul>"); inList = true }
                out.append("<li>\(inline(String(line.dropFirst(2))))</li>")
                continue
            }
            if inList { out.append("</ul>"); inList = false }

            if line.isEmpty { continue }
            if line.hasPrefix("#") {
                let level = min(line.prefix(while: { $0 == "#" }).count, 6)
                let text = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                out.append("<h\(level)>\(inline(text))</h\(level)>")
                continue
            }
            out.append("<p>\(inline(line))</p>")
        }
        if inList { out.append("</ul>") }
        if inCode { out.append("</pre>") }
        return "<html><body>\n" + out.joined(separator: "\n") + "\n</body></html>"
    }

    /// Bold, italic, and inline code. Escaping happens first, so a document
    /// containing markup cannot inject it into the rendered page.
    static func inline(_ text: String) -> String {
        var result = escaped(text)
        for (marker, tag) in [("**", "strong"), ("*", "em"), ("`", "code")] {
            result = wrap(result, marker: marker, tag: tag)
        }
        return result
    }

    static func wrap(_ text: String, marker: String, tag: String) -> String {
        let parts = text.components(separatedBy: marker)
        guard parts.count >= 3 else { return text }
        var result = parts[0]
        var index = 1
        while index < parts.count {
            if index + 1 < parts.count || parts.count % 2 == 1 {
                result += "<\(tag)>\(parts[index])</\(tag)>"
                index += 1
                if index < parts.count { result += parts[index] }
                index += 1
            } else {
                result += marker + parts[index]
                index += 1
            }
        }
        return result
    }

    static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
