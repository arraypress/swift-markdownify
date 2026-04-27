//
//  MarkdownDocument.swift
//  Markdownify
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The result of a Markdownify conversion.
///
/// Combines the rendered Markdown with metadata extracted by Readability
/// (when available) and the original source URL.
///
/// ```swift
/// let doc = try await Markdownify.convert(url: pageURL)
/// print(doc.markdown)
/// print("Title: \(doc.title ?? "—")")
/// print("Site:  \(doc.siteName ?? "—")")
/// ```
public struct MarkdownDocument: Sendable, Equatable {

    /// The converted Markdown body.
    ///
    /// Includes any front-matter and `# Title` heading prepended by the
    /// configured ``Markdownify/Configuration``.
    public let markdown: String

    /// The article title, taken from Readability or `<title>`.
    public let title: String?

    /// The author/byline string, when Readability detects one.
    public let byline: String?

    /// The site name, when Readability detects one.
    public let siteName: String?

    /// The detected language code (e.g. `"en"`).
    public let language: String?

    /// The article's published timestamp, when present in metadata.
    public let publishedTime: String?

    /// A short excerpt produced by Readability.
    public let excerpt: String?

    /// The original source URL the document was converted from.
    public let sourceURL: URL?

    /// Approximate length of the extracted article (characters), as
    /// reported by Readability — falls back to the Markdown length.
    public let length: Int

    public init(
        markdown: String,
        title: String? = nil,
        byline: String? = nil,
        siteName: String? = nil,
        language: String? = nil,
        publishedTime: String? = nil,
        excerpt: String? = nil,
        sourceURL: URL? = nil,
        length: Int = 0
    ) {
        self.markdown = markdown
        self.title = title
        self.byline = byline
        self.siteName = siteName
        self.language = language
        self.publishedTime = publishedTime
        self.excerpt = excerpt
        self.sourceURL = sourceURL
        self.length = length
    }
}
