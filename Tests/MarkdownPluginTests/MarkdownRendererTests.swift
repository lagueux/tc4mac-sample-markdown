import Foundation
@testable import MarkdownPlugin
import Testing

@Suite("Markdown rendering")
struct MarkdownRendererTests {
    @Test("headings, paragraphs, lists and code fences convert")
    func structure() {
        let html = MarkdownRenderer.html(from: """
        # Title
        Some text.

        - one
        - two

        ```
        let x = 1
        ```
        """)
        #expect(html.contains("<h1>Title</h1>"))
        #expect(html.contains("<p>Some text.</p>"))
        #expect(html.contains("<ul>\n<li>one</li>\n<li>two</li>\n</ul>"))
        #expect(html.contains("<pre>\nlet x = 1\n</pre>"))
    }

    @Test("bold, italic and inline code convert inside a line")
    func inlineMarkup() {
        #expect(MarkdownRenderer.inline("a **bold** word") == "a <strong>bold</strong> word")
        #expect(MarkdownRenderer.inline("an *italic* word") == "an <em>italic</em> word")
        #expect(MarkdownRenderer.inline("call `run()` now") == "call <code>run()</code> now")
    }

    @Test("a document cannot inject markup into the rendered page")
    func escaping() {
        let html = MarkdownRenderer.html(from: "# <script>alert(1)</script>")
        #expect(!html.contains("<script>"))
        #expect(html.contains("&lt;script&gt;"))
    }

    @Test("an unmatched marker stays literal rather than half-converting")
    func unmatched() {
        #expect(MarkdownRenderer.inline("2 * 3 = 6") == "2 * 3 = 6")
    }
}
