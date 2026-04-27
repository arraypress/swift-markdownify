# Swift Markdownify

A Swift library for converting webpages and HTML to clean Markdown. Uses Mozilla Readability for content extraction and Turndown for HTML→Markdown conversion, executed in a hidden `WKWebView` so JavaScript-rendered pages work correctly.

```swift
import Markdownify

let url = URL(string: "https://en.wikipedia.org/wiki/Markdown")!
let doc = try await Markdownify.convert(url: url)
print(doc.markdown)
```

## Features

- 📰 **Readability-powered** — strips ads, navs, sidebars, comments before conversion
- 📐 **GitHub-Flavored Markdown** — tables, strikethrough, task lists out of the box
- 🌐 **Renders JavaScript** — uses `WKWebView`, so SPAs and JS-built pages convert correctly
- 📝 **Front-matter** — optional YAML or TOML metadata block
- 🔗 **Absolute URLs** — relative `<a href>` and `<img src>` are resolved against the page URL
- 🧪 **HTML input too** — convert pre-fetched HTML strings without a network round-trip
- 🍎 **Cross-platform** — macOS 13+, iOS 16+
- ⚡ **Async/await** native — built for modern Swift concurrency
- 🛡️ **Typed error handling** — specific errors for every failure case

## Requirements

- macOS 13.0+ / iOS 16.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-markdownify.git", from: "1.0.0")
]
```

Add `Markdownify` to your target's dependencies.

## Quick Start

```swift
import Markdownify

let url = URL(string: "https://www.theverge.com/some-article")!
let doc = try await Markdownify.convert(url: url)

print(doc.markdown)
print(doc.title ?? "—")
print(doc.byline ?? "—")
```

### Converting an HTML string

If you've already fetched HTML — for example from inside a Safari Web Extension `content.js` — pass it directly:

```swift
let doc = try await Markdownify.convert(
    html: htmlString,
    baseURL: URL(string: "https://example.com/article")
)
```

The `baseURL` is used to resolve relative links and image paths.

## Configuration

```swift
var config = Markdownify.Configuration()
config.readability    = .auto       // .auto / .always / .never
config.frontMatter    = .yaml       // .none / .yaml / .toml
config.preserveLinks  = true
config.imageHandling  = .keepRemote // .keepRemote / .strip
config.gfm            = true        // GitHub-Flavored Markdown plugin
config.includeTitle   = true        // prepend "# Title" when detected
config.loadTimeout    = 30          // seconds
config.userAgent      = nil         // override `WKWebView` user agent

let doc = try await Markdownify.convert(url: url, config: config)
```

### Readability strategies

- `.auto` (default) — run Readability; if it returns nothing, fall back to the raw page.
- `.always` — run Readability; throw `MarkdownifyError.readabilityFailed` if it returns nothing.
- `.never` — skip Readability entirely. Useful if the page is already pre-cleaned (e.g. piping HTML straight from a Safari extension that already extracted the article element).

### Front-matter

`.yaml` produces a fenced YAML block at the top of the output:

```markdown
---
title: "The Article Title"
author: "Jane Author"
site: "Example.com"
language: "en"
date: "2026-04-22T10:30:00Z"
source: "https://example.com/article"
---

# The Article Title

Body text…
```

`.toml` produces an equivalent `+++` block.

## Result

```swift
public struct MarkdownDocument: Sendable {
    public let markdown: String        // the converted body
    public let title: String?
    public let byline: String?
    public let siteName: String?
    public let language: String?
    public let publishedTime: String?
    public let excerpt: String?
    public let sourceURL: URL?
    public let length: Int
}
```

## Errors

```swift
public enum MarkdownifyError: Error {
    case invalidURL(String)
    case loadFailed(String)
    case timeout
    case missingResource(String)
    case javaScriptFailed(String)
    case invalidResponse(String)
    case readabilityFailed(String)
}
```

## Notes

- All conversions run on the main actor because `WKWebView` is main-thread-only. From an async context, just `try await Markdownify.convert(...)` — the library handles the actor hop.
- For pages requiring authentication or cookies (logged-in Substacks, paywalled articles), a plain `convert(url:)` call won't have the right session. Use a Safari Web Extension to extract the HTML inside the user's authenticated browser context and pass it to `convert(html:baseURL:)`.

## License

MIT — see [LICENSE](./LICENSE). Bundled JavaScript dependencies (Readability, Turndown, turndown-plugin-gfm) carry their own MIT/Apache 2.0 licenses; see [Sources/Markdownify/Resources/JS/LICENSES.md](./Sources/Markdownify/Resources/JS/LICENSES.md).
