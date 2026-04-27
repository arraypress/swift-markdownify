/*
 * bridge.js — Markdownify entry point.
 *
 * Evaluated by WKWebView after Readability.js, turndown.js, and
 * turndown-plugin-gfm.js have already been loaded into the page.
 *
 * Exposes a single global function:
 *
 *     window.__markdownifyRun(configJSON) -> resultJSON
 *
 * Both arguments are JSON strings so the Swift side can serialize them
 * cleanly across the WKWebView bridge.
 */

(function () {
  "use strict";

  if (window.__markdownifyRun) return; // idempotent

  function clone(node) {
    return node.cloneNode(true);
  }

  function runReadability(doc) {
    if (typeof Readability !== "function") return null;
    try {
      // Readability mutates the document, so clone first.
      const docClone = doc.cloneNode(true);
      const reader = new Readability(docClone);
      return reader.parse(); // { title, byline, content, textContent, length, excerpt, siteName, lang, publishedTime } | null
    } catch (e) {
      return null;
    }
  }

  function buildTurndown(config) {
    const service = new TurndownService({
      headingStyle: "atx",
      hr: "---",
      bulletListMarker: "-",
      codeBlockStyle: "fenced",
      fence: "```",
      emDelimiter: "_",
      strongDelimiter: "**",
      linkStyle: "inlined",
      linkReferenceStyle: "full",
    });

    if (typeof turndownPluginGfm !== "undefined" && config.gfm !== false) {
      service.use(turndownPluginGfm.gfm);
    }

    if (config.preserveLinks === false) {
      service.addRule("stripLinks", {
        filter: "a",
        replacement: function (content) { return content; },
      });
    }

    if (config.imageHandling === "strip") {
      service.addRule("stripImages", {
        filter: "img",
        replacement: function () { return ""; },
      });
    }

    // Drop noise that Readability might miss
    service.remove(["script", "style", "noscript", "iframe"]);

    return service;
  }

  function absolutize(html, baseURL) {
    if (!baseURL) return html;
    try {
      const tmp = document.implementation.createHTMLDocument("");
      const base = tmp.createElement("base");
      base.href = baseURL;
      tmp.head.appendChild(base);
      const wrapper = tmp.createElement("div");
      wrapper.innerHTML = html;
      tmp.body.appendChild(wrapper);
      // Force resolution by reading absolute URLs from anchor/img elements
      wrapper.querySelectorAll("a[href]").forEach(function (a) { a.setAttribute("href", a.href); });
      wrapper.querySelectorAll("img[src]").forEach(function (i) { i.setAttribute("src", i.src); });
      return wrapper.innerHTML;
    } catch (e) {
      return html;
    }
  }

  function buildFrontMatter(meta, kind) {
    if (kind === "none" || !kind) return "";
    const fields = [];
    if (meta.title)    fields.push(["title",     meta.title]);
    if (meta.byline)   fields.push(["author",    meta.byline]);
    if (meta.siteName) fields.push(["site",      meta.siteName]);
    if (meta.lang)     fields.push(["language",  meta.lang]);
    if (meta.publishedTime) fields.push(["date",  meta.publishedTime]);
    if (meta.url)      fields.push(["source",    meta.url]);
    if (!fields.length) return "";

    if (kind === "yaml") {
      const body = fields.map(function (kv) {
        const v = String(kv[1]).replace(/"/g, '\\"');
        return kv[0] + ': "' + v + '"';
      }).join("\n");
      return "---\n" + body + "\n---\n\n";
    }
    if (kind === "toml") {
      const body = fields.map(function (kv) {
        const v = String(kv[1]).replace(/"/g, '\\"');
        return kv[0] + ' = "' + v + '"';
      }).join("\n");
      return "+++\n" + body + "\n+++\n\n";
    }
    return "";
  }

  window.__markdownifyRun = function (configJSON) {
    const config = JSON.parse(configJSON || "{}");
    const useReadability = config.readability !== "never"; // "auto" | "always" | "never"
    const baseURL = config.baseURL || document.baseURI || location.href;

    let title = document.title || null;
    let html = null;
    let meta = { url: baseURL };

    if (useReadability) {
      const article = runReadability(document);
      if (article) {
        meta = {
          url: baseURL,
          title: article.title || title,
          byline: article.byline || null,
          siteName: article.siteName || null,
          lang: article.lang || null,
          publishedTime: article.publishedTime || null,
          excerpt: article.excerpt || null,
          length: article.length || null,
        };
        title = meta.title;
        html = article.content;
      } else if (config.readability === "always") {
        return JSON.stringify({ ok: false, error: "Readability extraction returned no article." });
      }
    }

    if (!html) {
      // Fallback: use main/article/body
      const root =
        document.querySelector("main") ||
        document.querySelector("article") ||
        document.body;
      html = root ? root.innerHTML : "";
    }

    html = absolutize(html, baseURL);

    let markdown;
    try {
      const service = buildTurndown(config);
      markdown = service.turndown(html);
    } catch (e) {
      return JSON.stringify({ ok: false, error: "Turndown failed: " + (e && e.message ? e.message : String(e)) });
    }

    markdown = markdown.replace(/\n{3,}/g, "\n\n").trim();

    const frontMatter = buildFrontMatter(meta, config.frontMatter || "none");
    const document_ = frontMatter + (title && config.includeTitle !== false ? "# " + title + "\n\n" : "") + markdown + "\n";

    return JSON.stringify({
      ok: true,
      markdown: document_,
      title: title,
      byline: meta.byline || null,
      siteName: meta.siteName || null,
      lang: meta.lang || null,
      publishedTime: meta.publishedTime || null,
      excerpt: meta.excerpt || null,
      url: meta.url,
      length: meta.length || markdown.length,
    });
  };
})();
