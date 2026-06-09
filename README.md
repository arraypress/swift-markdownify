# Swift Markdownify

Convert webpages and HTML strings to clean Markdown. `Markdownify` runs Mozilla Readability for article extraction and Turndown for HTML-to-Markdown conversion inside a hidden `WKWebView`, so JavaScript-rendered pages are converted from their fully-rendered DOM — not the raw source.

## Features

- 🌐 **JavaScript-aware** — loads pages in a hidden `WKWebView` and converts the rendered DOM, so client-side-rendered content works
- 📰 **Readability extraction** — Mozilla Readability isolates the main article from navigation, ads, and chrome
- 🔁 **HTML or URL input** — convert a remote URL, or pre-fetched HTML via `convert(html:baseURL:)`
- 📝 **GitHub-Flavored Markdown** — Turndown with the GFM plugin (tables, strikethrough, task lists), toggleable
- 📋 **Front matter** — optional YAML or TOML front matter prepended to the output
- 🖼️ **Image handling** — keep remote `![alt](src)` (absolutized) or strip images entirely
- 🔗 **Link control** — preserve or drop `<a>` links
- 🏷️ **Rich metadata** — returns title, byline, site name, language, published time, excerpt, and length
- ⚙️ **Readability strategies** — `auto` (fallback), `always` (throw on failure), or `never`
- ⏱️ **Configurable load timeout** and optional User-Agent override
- 🧱 **Typed errors** — `MarkdownifyError` with `LocalizedError` descriptions
- 📦 **Bundled JS** — Readability, Turndown, and the GFM plugin ship inside the package

## Requirements

- macOS 13.0+ / iOS 16.0+
- Swift 6.0+
- Xcode 26.0+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-markdownify.git", from: "1.0.0")
]
```

## Usage

### Converting a URL

```swift
import Markdownify

let url = URL(string: "https://en.wikipedia.org/wiki/Markdown")!
let doc = try await Markdownify.convert(url: url)

print(doc.markdown)
print("Title: \(doc.title ?? "—")")
print("Site:  \(doc.siteName ?? "—")")
```

### Converting pre-fetched HTML

```swift
let html = "<article><h1>Hello</h1><p>World</p></article>"
let doc = try await Markdownify.convert(html: html, baseURL: URL(string: "https://example.com"))
print(doc.markdown)
```

### Configuration

```swift
var config = Markdownify.Configuration()
config.readability = .auto          // .auto | .always | .never
config.frontMatter = .yaml          // .none | .yaml | .toml
config.gfm = true                   // GitHub-Flavored Markdown extensions
config.imageHandling = .keepRemote  // .keepRemote | .strip
config.preserveLinks = true
config.includeTitle = true
config.loadTimeout = 30
config.userAgent = nil

let doc = try await Markdownify.convert(url: url, config: config)
print(doc.markdown)
```

### Error handling

```swift
do {
    let doc = try await Markdownify.convert(url: url)
    print(doc.markdown)
} catch let error as MarkdownifyError {
    switch error {
    case .invalidURL(let s):        print("Invalid URL: \(s)")
    case .loadFailed(let s):        print("Load failed: \(s)")
    case .timeout:                  print("Timed out")
    case .missingResource(let s):   print("Missing bundled resource: \(s)")
    case .javaScriptFailed(let s):  print("JS error: \(s)")
    case .invalidResponse(let s):   print("Bad bridge response: \(s)")
    case .readabilityFailed(let s): print("Readability failed: \(s)")
    }
}
```

## How It Works

1. The URL is loaded into a hidden `WKWebView` (or HTML is rendered via `loadHTMLString`).
2. After the main frame finishes loading, Mozilla Readability extracts the article content — unless `Configuration.readability` is `.never`.
3. The extracted HTML is fed to Turndown (GFM enabled by default) and the resulting Markdown is returned alongside the detected metadata.

Because `WKWebView` is main-thread-only, both `convert` entry points are annotated `@MainActor`. Pages requiring authentication or cookies can't be converted from a plain `convert(url:)` call — fetch the HTML yourself and pass it to `convert(html:baseURL:)`.

## Models

| Type | Description |
|------|-------------|
| `MarkdownDocument` | Result: `markdown` body plus `title`, `byline`, `siteName`, `language`, `publishedTime`, `excerpt`, `sourceURL`, `length` |
| `Markdownify.Configuration` | Tunables: `readability`, `frontMatter`, `preserveLinks`, `imageHandling`, `gfm`, `includeTitle`, `loadTimeout`, `userAgent` |
| `MarkdownifyError` | Typed conversion errors with `LocalizedError` descriptions |

## Use Cases

- Saving web articles to a Markdown notes system
- Feeding clean article text to LLMs or search indexes
- Building read-it-later or clipping tools
- Archiving pages as portable Markdown

## Testing

```bash
swift test
```

Tests run conversions against bundled HTML fixtures.

## License

MIT License — see LICENSE file for details.

## Author

Created by David Sherlock ([ArrayPress](https://github.com/arraypress)) in 2026.
