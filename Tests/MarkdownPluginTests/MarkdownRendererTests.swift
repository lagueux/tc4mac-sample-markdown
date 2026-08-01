import Foundation
@testable import MarkdownPlugin
import Testing

/// The renderer sits on Foundation's CommonMark parser, so these assert the
/// EMITTED HTML SHAPE — including the regressions tc4mac's owner hit with
/// the old hand-rolled converter (UAT 2026-08-01): raw link syntax shown
/// verbatim, double list bullets, literal inline HTML.
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
        #expect(html.contains("<ul>"))
        #expect(html.contains("<li>one</li>"))
        #expect(html.contains("<li>two</li>"))
        #expect(html.contains("let x = 1"))
        #expect(html.contains("<pre>"))
    }

    @Test("bold, italic and inline code convert inside a line")
    func inlineMarkup() {
        let html = MarkdownRenderer.html(from: "a **bold** and *italic* `code` word")
        #expect(html.contains("<strong>bold</strong>"))
        #expect(html.contains("<em>italic</em>"))
        #expect(html.contains("<code>code</code>"))
    }

    @Test("links become anchors, never raw [text](url) on screen")
    func links() {
        let html = MarkdownRenderer.html(from: "See [Overview](#overview) for more.")
        #expect(html.contains("<a href=\"#overview\">Overview</a>"))
        #expect(!html.contains("[Overview]("))
    }

    @Test("a badge — image inside a link — shows as linked alt text")
    func badgeImageLink() {
        let html = MarkdownRenderer.html(
            from: "[![Build](https://img.example/badge.svg)](https://ci.example/run)")
        // The parser folds the image into its alt text — the badge shows as
        // clean linked text, no raw ![…](…) syntax and no fetched resource.
        #expect(html.contains("<a href=\"https://ci.example/run\">Build</a>"))
        #expect(!html.contains("!["))
        #expect(!html.contains("badge.svg)"))
    }

    @Test("list items carry exactly one bullet source — the <li> itself")
    func singleBullets() {
        let html = MarkdownRenderer.html(from: "- [Overview](#overview)\n- [Team](#team)")
        #expect(html.contains("<li>"))
        // No nested list around a flat two-item list, and no literal bullet
        // characters — the double-bullet regression.
        #expect(!html.contains("<ul><ul>") && !html.contains("<ul>\n<ul>"))
        #expect(!html.contains("•"))
    }

    @Test("inline HTML is neutralized, not shown as literal source")
    func inlineHTMLDropped() {
        let html = MarkdownRenderer.html(from: "<a id=\"overview\"></a>\n\n# Overview")
        #expect(html.contains("<h1>Overview</h1>"))
        #expect(!html.contains("&lt;a id="), "raw anchor source leaked into the page")
    }

    @Test("blockquotes and thematic breaks render as elements")
    func quoteAndRule() {
        let html = MarkdownRenderer.html(from: "> quoted wisdom\n\n---\n\nafter")
        #expect(html.contains("<blockquote>"))
        #expect(html.contains("quoted wisdom"))
        #expect(html.contains("<hr>"))
        #expect(!html.contains("---"))
    }

    @Test("fenced code keeps its tags, rendered escaped")
    func fencedCodeKeepsTags() {
        let html = MarkdownRenderer.html(from: "```\n<div class=\"x\">\n```")
        #expect(html.contains("&lt;div class="), "code example lost its tags")
        #expect(!html.contains("<div class="))
    }

    @Test("markup in the document cannot inject HTML")
    func escaping() {
        let html = MarkdownRenderer.html(from: "evil `<script>alert(1)</script>` here")
        #expect(!html.contains("<script>"))
        #expect(html.contains("&lt;script&gt;"))
    }
}
