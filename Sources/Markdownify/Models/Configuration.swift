//
//  Configuration.swift
//  Markdownify
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension Markdownify {

    /// Tunables for a Markdownify conversion.
    ///
    /// ```swift
    /// var config = Markdownify.Configuration()
    /// config.readability = .auto
    /// config.frontMatter = .yaml
    /// let doc = try await Markdownify.convert(url: url, config: config)
    /// ```
    public struct Configuration: Sendable, Equatable {

        /// Strategy for running Mozilla Readability before conversion.
        public enum Readability: String, Sendable, Equatable {
            /// Run Readability; if it fails, fall back to the raw page.
            case auto
            /// Run Readability; throw ``MarkdownifyError/readabilityFailed(_:)`` if it fails.
            case always
            /// Skip Readability entirely and convert the raw page.
            case never
        }

        /// Front-matter format prepended to the Markdown output.
        public enum FrontMatter: String, Sendable, Equatable {
            case none, yaml, toml
        }

        /// How `<img>` elements are handled in the Markdown output.
        public enum ImageHandling: String, Sendable, Equatable {
            /// Keep `![alt](src)` with the original (absolutized) src.
            case keepRemote
            /// Strip images entirely.
            case strip
        }

        /// Readability strategy. Default: ``Readability/auto``.
        public var readability: Readability = .auto

        /// Front-matter format. Default: ``FrontMatter/none``.
        public var frontMatter: FrontMatter = .none

        /// Whether to preserve `<a>` links in the output. Default: `true`.
        public var preserveLinks: Bool = true

        /// Image handling strategy. Default: ``ImageHandling/keepRemote``.
        public var imageHandling: ImageHandling = .keepRemote

        /// Enable GitHub-Flavored Markdown extensions (tables,
        /// strikethrough, task lists). Default: `true`.
        public var gfm: Bool = true

        /// Prepend `# Title` to the output when a title is detected.
        /// Default: `true`.
        public var includeTitle: Bool = true

        /// Maximum time to wait for `WKWebView` to finish loading a URL.
        /// Default: 30 seconds.
        public var loadTimeout: TimeInterval = 30

        /// User-Agent override applied to the `WKWebView`.
        ///
        /// `nil` keeps the system default. Default: `nil`.
        public var userAgent: String? = nil

        public init() {}
    }
}
