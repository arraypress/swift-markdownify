//
//  Markdownify.swift
//  Markdownify
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Convert webpages and HTML strings to clean Markdown using
/// Mozilla Readability and Turndown, executed in a hidden `WKWebView`.
///
/// ## Quick Start
///
/// ```swift
/// import Markdownify
///
/// let url = URL(string: "https://en.wikipedia.org/wiki/Markdown")!
/// let doc = try await Markdownify.convert(url: url)
/// print(doc.markdown)
/// ```
///
/// ## How It Works
///
/// 1. The given URL is loaded into a hidden `WKWebView` (or HTML is rendered
///    via `loadHTMLString`).
/// 2. After the main frame finishes loading, Mozilla Readability is run to
///    extract the article content (skippable via
///    ``Configuration/Readability/never``).
/// 3. The extracted HTML is fed to Turndown — with the GitHub-Flavored
///    Markdown plugin enabled by default — and the resulting Markdown is
///    returned alongside metadata.
///
/// ## Notes
///
/// - All conversions run on the main actor because `WKWebView` is
///   main-thread-only.
/// - Pages requiring authentication or cookies cannot be converted from a
///   plain ``Markdownify/convert(url:config:)`` call. Use the Safari Web
///   Extension that ships alongside this package, or pass pre-fetched HTML
///   via ``Markdownify/convert(html:baseURL:config:)``.
public enum Markdownify {

    /// Converts a remote webpage to Markdown.
    ///
    /// Loads the URL in a hidden `WKWebView`, runs Readability on the
    /// rendered DOM, then converts the extracted article HTML to Markdown
    /// with Turndown.
    ///
    /// ```swift
    /// let doc = try await Markdownify.convert(url: someURL)
    /// print(doc.markdown)
    /// ```
    ///
    /// - Parameters:
    ///   - url: The URL to fetch and convert.
    ///   - config: Conversion options. See ``Markdownify/Configuration``.
    /// - Throws: ``MarkdownifyError``.
    /// - Returns: A ``MarkdownDocument`` containing the rendered Markdown
    ///   and any metadata extracted by Readability.
    @MainActor
    public static func convert(
        url: URL,
        config: Configuration = Configuration()
    ) async throws -> MarkdownDocument {
        let engine = MarkdownifyEngine(config: config)
        return try await engine.run(.url(url))
    }

    /// Converts a string of HTML to Markdown.
    ///
    /// Loads the HTML into a hidden `WKWebView` via `loadHTMLString`, runs
    /// Readability on it (so the same extraction quality applies), then
    /// converts the result to Markdown.
    ///
    /// Useful when you've already fetched HTML through your own means —
    /// from a Safari Web Extension `content.js`, from a network request,
    /// or from a file on disk.
    ///
    /// - Parameters:
    ///   - html: The HTML string to convert.
    ///   - baseURL: Used to resolve relative links and image paths in the
    ///     HTML. Pass the URL the HTML originally came from when known.
    ///   - config: Conversion options.
    /// - Throws: ``MarkdownifyError``.
    /// - Returns: A ``MarkdownDocument``.
    @MainActor
    public static func convert(
        html: String,
        baseURL: URL? = nil,
        config: Configuration = Configuration()
    ) async throws -> MarkdownDocument {
        let engine = MarkdownifyEngine(config: config)
        return try await engine.run(.html(html, baseURL: baseURL))
    }
}
