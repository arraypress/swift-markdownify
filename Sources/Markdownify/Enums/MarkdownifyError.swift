//
//  MarkdownifyError.swift
//  Markdownify
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Errors thrown by ``Markdownify``.
public enum MarkdownifyError: Error, Sendable, Equatable {

    /// The provided string was not a valid URL.
    case invalidURL(String)

    /// The page failed to load in the WKWebView.
    case loadFailed(String)

    /// The page took longer than the configured timeout to load.
    case timeout

    /// One of the bundled JavaScript resources could not be located in
    /// the package bundle.
    case missingResource(String)

    /// JavaScript evaluation failed inside the WKWebView.
    case javaScriptFailed(String)

    /// The bridge returned a result that could not be decoded.
    case invalidResponse(String)

    /// Readability requested via `.always` failed to extract content.
    case readabilityFailed(String)
}

extension MarkdownifyError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let s):        return "Invalid URL: \(s)"
        case .loadFailed(let s):        return "Page failed to load: \(s)"
        case .timeout:                  return "Page load timed out."
        case .missingResource(let s):   return "Missing bundled resource: \(s)"
        case .javaScriptFailed(let s):  return "JavaScript error: \(s)"
        case .invalidResponse(let s):   return "Invalid bridge response: \(s)"
        case .readabilityFailed(let s): return "Readability failed: \(s)"
        }
    }
}
