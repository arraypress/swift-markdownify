//
//  MarkdownifyTests.swift
//  Markdownify
//
//  Created by David Sherlock on 2026.
//

import XCTest
@testable import Markdownify

@MainActor
final class MarkdownifyTests: XCTestCase {

    // MARK: - Helpers

    private func loadFixture(_ name: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "html") else {
            XCTFail("Missing fixture: \(name).html")
            throw XCTSkip("Fixture missing")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func convertFixture(
        _ name: String,
        baseURL: URL? = URL(string: "https://example.test/article"),
        config: Markdownify.Configuration = .init()
    ) async throws -> MarkdownDocument {
        let html = try loadFixture(name)
        return try await Markdownify.convert(html: html, baseURL: baseURL, config: config)
    }

    // MARK: - Basic Conversion

    func testConvertsHeadings() async throws {
        let doc = try await convertFixture("article")
        XCTAssertTrue(doc.markdown.contains("# The Quick Brown Fox"))
        XCTAssertTrue(doc.markdown.contains("## A Subsection"))
        XCTAssertTrue(doc.markdown.contains("## Code"))
    }

    func testConvertsBoldAndItalic() async throws {
        let doc = try await convertFixture("article")
        XCTAssertTrue(doc.markdown.contains("**opening paragraph**"))
        XCTAssertTrue(doc.markdown.contains("_italic text_"))
    }

    func testConvertsLinks() async throws {
        let doc = try await convertFixture("article")
        XCTAssertTrue(doc.markdown.contains("[cited link](https://example.com/cited)"))
    }

    func testConvertsBulletList() async throws {
        let doc = try await convertFixture("article")
        XCTAssertTrue(doc.markdown.contains("-   First item"))
        XCTAssertTrue(doc.markdown.contains("`inline code`"))
        XCTAssertTrue(doc.markdown.contains("-   Third item"))
    }

    func testConvertsCodeBlock() async throws {
        let doc = try await convertFixture("article")
        XCTAssertTrue(doc.markdown.contains("```"))
        XCTAssertTrue(doc.markdown.contains("let x = 42"))
        XCTAssertTrue(doc.markdown.contains("print(x)"))
    }

    func testConvertsTable() async throws {
        let doc = try await convertFixture("article")
        XCTAssertTrue(doc.markdown.contains("| Name | Score |"))
        XCTAssertTrue(doc.markdown.contains("| Alice | 95 |"))
        XCTAssertTrue(doc.markdown.contains("| Bob | 87 |"))
    }

    func testAbsolutizesRelativeImageURL() async throws {
        let doc = try await convertFixture("article")
        XCTAssertTrue(
            doc.markdown.contains("https://example.test/images/photo.jpg"),
            "Expected relative image src to be resolved against baseURL.\n\(doc.markdown)"
        )
    }

    // MARK: - Metadata

    func testExtractsTitle() async throws {
        let doc = try await convertFixture("article")
        XCTAssertEqual(doc.title, "The Quick Brown Fox")
    }

    func testExposesSourceURL() async throws {
        let url = URL(string: "https://example.test/article")!
        let doc = try await convertFixture("article", baseURL: url)
        XCTAssertEqual(doc.sourceURL, url)
    }

    // MARK: - Configuration

    func testStripImages() async throws {
        var config = Markdownify.Configuration()
        config.imageHandling = .strip
        let doc = try await convertFixture("article", config: config)
        XCTAssertFalse(doc.markdown.contains("![A photo]"))
    }

    func testStripLinks() async throws {
        var config = Markdownify.Configuration()
        config.preserveLinks = false
        let doc = try await convertFixture("article", config: config)
        XCTAssertFalse(doc.markdown.contains("](https://example.com/cited)"))
        XCTAssertTrue(doc.markdown.contains("cited link"))
    }

    func testYAMLFrontMatter() async throws {
        var config = Markdownify.Configuration()
        config.frontMatter = .yaml
        let doc = try await convertFixture("article", config: config)
        XCTAssertTrue(doc.markdown.hasPrefix("---\n"))
        XCTAssertTrue(doc.markdown.contains("title: \"The Quick Brown Fox\""))
    }

    func testTOMLFrontMatter() async throws {
        var config = Markdownify.Configuration()
        config.frontMatter = .toml
        let doc = try await convertFixture("article", config: config)
        XCTAssertTrue(doc.markdown.hasPrefix("+++\n"))
    }

    func testReadabilityNeverPreservesAside() async throws {
        // The flat fixture has no <main>/<article>, so .never falls back to
        // <body> and the <aside> content survives. With Readability on, that
        // aside would be stripped — proving the toggle works.
        var config = Markdownify.Configuration()
        config.readability = .never
        let doc = try await convertFixture("flat", config: config)
        XCTAssertTrue(
            doc.markdown.contains("Aside content that should appear"),
            "Expected <aside> to survive when Readability is disabled.\n\(doc.markdown)"
        )
    }

    func testReadabilityAutoStripsAside() async throws {
        let doc = try await convertFixture("article")
        XCTAssertFalse(
            doc.markdown.contains("Sidebar — should be removed by Readability"),
            "Expected Readability to remove the <aside>."
        )
    }

    func testIncludeTitleFalse() async throws {
        var config = Markdownify.Configuration()
        config.includeTitle = false
        let doc = try await convertFixture("article", config: config)
        XCTAssertFalse(doc.markdown.hasPrefix("# The Quick Brown Fox"))
    }
}
