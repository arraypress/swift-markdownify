//
//  MarkdownifyEngine.swift
//  Markdownify
//
//  Created by David Sherlock on 2026.
//

import Foundation
import WebKit

/// Internal engine that drives a hidden `WKWebView` through one
/// conversion: load → inject vendor JS → invoke bridge → decode result.
///
/// One engine instance handles one conversion, then is discarded.
@MainActor
final class MarkdownifyEngine: NSObject {

    enum Source {
        case url(URL)
        case html(String, baseURL: URL?)
    }

    // MARK: - Stored

    private let config: Markdownify.Configuration
    private var webView: WKWebView?

    /// Resumed exactly once when the main frame finishes loading or an
    /// error/timeout occurs.
    private var loadContinuation: CheckedContinuation<Void, Error>?

    // MARK: - Init

    init(config: Markdownify.Configuration) {
        self.config = config
        super.init()
    }

    // MARK: - Run

    func run(_ source: Source) async throws -> MarkdownDocument {
        let webView = makeWebView()
        self.webView = webView

        try await load(source, in: webView)
        try await injectVendorScripts(in: webView)
        let payload = try await invokeBridge(in: webView, source: source)

        return try decode(payload, source: source)
    }

    // MARK: - WebView

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        // Run conversion offline-friendly: don't autoplay media etc.
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let view = WKWebView(frame: .init(x: 0, y: 0, width: 1024, height: 768), configuration: config)
        view.navigationDelegate = self
        if let ua = self.config.userAgent {
            view.customUserAgent = ua
        }
        return view
    }

    // MARK: - Load

    private func load(_ source: Source, in webView: WKWebView) async throws {
        let timeout = config.loadTimeout

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.loadContinuation = cont

            switch source {
            case .url(let url):
                webView.load(URLRequest(url: url))
            case .html(let html, let baseURL):
                webView.loadHTMLString(html, baseURL: baseURL)
            }

            // Hop to a detached Task for the timer; it bounces back to the
            // main actor to inspect/resume the continuation. Continuation
            // assignment + delegate resume both happen on @MainActor, so the
            // nil-check is race-free.
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard let self, let pending = self.loadContinuation else { return }
                self.loadContinuation = nil
                pending.resume(throwing: MarkdownifyError.timeout)
            }
        }
    }

    // MARK: - JS Injection

    private func injectVendorScripts(in webView: WKWebView) async throws {
        for resource in ["Readability", "turndown", "turndown-plugin-gfm", "bridge"] {
            let js = try Self.loadResource(named: resource, ext: "js")
            _ = try await webView.evaluateJavaScript(js)
        }
    }

    private func invokeBridge(in webView: WKWebView, source: Source) async throws -> String {
        let configJSON = try Self.encodeConfig(self.config, source: source)
        // The bridge function returns a JSON string.
        let escaped = configJSON
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")

        let call = "window.__markdownifyRun('\(escaped)')"
        let result = try await webView.evaluateJavaScript(call)
        guard let payload = result as? String else {
            throw MarkdownifyError.invalidResponse("Bridge did not return a string.")
        }
        return payload
    }

    // MARK: - Decoding

    private func decode(_ payload: String, source: Source) throws -> MarkdownDocument {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MarkdownifyError.invalidResponse("Bridge payload was not valid JSON.")
        }

        if (json["ok"] as? Bool) == false {
            let message = json["error"] as? String ?? "unknown bridge error"
            if message.hasPrefix("Readability") {
                throw MarkdownifyError.readabilityFailed(message)
            }
            throw MarkdownifyError.javaScriptFailed(message)
        }

        guard let markdown = json["markdown"] as? String else {
            throw MarkdownifyError.invalidResponse("Missing 'markdown' field.")
        }

        let sourceURL: URL? = {
            switch source {
            case .url(let u): return u
            case .html(_, let baseURL): return baseURL
            }
        }()

        return MarkdownDocument(
            markdown: markdown,
            title: json["title"] as? String,
            byline: json["byline"] as? String,
            siteName: json["siteName"] as? String,
            language: json["lang"] as? String,
            publishedTime: json["publishedTime"] as? String,
            excerpt: json["excerpt"] as? String,
            sourceURL: sourceURL,
            length: (json["length"] as? Int) ?? markdown.count
        )
    }

    // MARK: - Helpers

    private static func loadResource(named name: String, ext: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
            throw MarkdownifyError.missingResource("\(name).\(ext)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func encodeConfig(
        _ config: Markdownify.Configuration,
        source: Source
    ) throws -> String {
        var dict: [String: Any] = [
            "readability": config.readability.rawValue,
            "frontMatter": config.frontMatter.rawValue,
            "preserveLinks": config.preserveLinks,
            "imageHandling": config.imageHandling.rawValue,
            "gfm": config.gfm,
            "includeTitle": config.includeTitle
        ]
        switch source {
        case .url(let u):
            dict["baseURL"] = u.absoluteString
        case .html(_, let base):
            if let base { dict["baseURL"] = base.absoluteString }
        }
        let data = try JSONSerialization.data(withJSONObject: dict)
        return String(decoding: data, as: UTF8.self)
    }

}

// MARK: - WKNavigationDelegate

extension MarkdownifyEngine: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadContinuation?.resume()
        loadContinuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadContinuation?.resume(throwing: MarkdownifyError.loadFailed(error.localizedDescription))
        loadContinuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadContinuation?.resume(throwing: MarkdownifyError.loadFailed(error.localizedDescription))
        loadContinuation = nil
    }
}
