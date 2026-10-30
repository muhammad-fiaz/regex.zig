import { defineConfig } from "vitepress";
import llmstxt, { copyOrDownloadAsMarkdownButtons } from "vitepress-plugin-llms";

// Canonical site configuration
export const SITE_URL = "https://muhammad-fiaz.github.io/regex.zig";
export const SITE_NAME = "Regex.zig";
export const SITE_DESCRIPTION =
  "Industrial-strength regular expression engine for Zig 0.17.0 delivering guaranteed linear-time PikeVM NFA execution, submatch extraction, UTF-8 case folding, and algorithmic ReDoS immunity without libc or external dependencies.";

// Google Analytics and Google Tag Manager IDs
export const GA_ID = "G-6BVYCRK57P";
export const GTM_ID = "GTM-P4M9T8ZR";

// Google AdSense Client ID
export const ADSENSE_CLIENT_ID = "ca-pub-2040560600290490";

// Microsoft Clarity Project ID
export const CLARITY_ID = "z5vdzih779";

// SEO Keywords
export const KEYWORDS =
  "zig, regex, regular-expressions, pikevm, nfa, linear-time, redos-defense, unicode, captures, pattern-matching, replace, split, cross-platform, windows, linux, macos, aarch64, x86, x86_64, arm, zig-0.17";

export default defineConfig({
  lang: "en-US",
  title: SITE_NAME,
  titleTemplate: ":title | Regex.zig",
  description: SITE_DESCRIPTION,
  lastUpdated: true,
  cleanUrls: false,
  base: "/regex.zig/",

  sitemap: {
    hostname: "https://muhammad-fiaz.github.io/regex.zig/",
  },

  vite: {
    plugins: [llmstxt()],
  },

  markdown: {
    config(md) {
      md.use(copyOrDownloadAsMarkdownButtons);
    },
  },

  head: [
    // Primary Meta Tags
    ["meta", { name: "title", content: SITE_NAME }],
    ["meta", { name: "description", content: SITE_DESCRIPTION }],
    ["meta", { name: "keywords", content: KEYWORDS }],
    ["meta", { name: "author", content: "Muhammad Fiaz" }],
    ["meta", { name: "publisher", content: "Muhammad Fiaz" }],
    ["meta", { name: "robots", content: "index, follow" }],
    ["meta", { name: "language", content: "English" }],
    ["meta", { name: "revisit-after", content: "7 days" }],
    ["meta", { name: "generator", content: "VitePress" }],

    // Web App Manifest
    ["link", { rel: "manifest", href: "/regex.zig/manifest.json" }],

    // Favicons
    ["link", { rel: "icon", type: "image/svg+xml", href: "/regex.zig/favicon.svg" }],

    // Canonical Link is emitted per page in transformPageData below.

    // Open Graph
    ["meta", { property: "og:type", content: "website" }],
    ["meta", { property: "og:url", content: SITE_URL }],
    ["meta", { property: "og:title", content: SITE_NAME }],
    ["meta", { property: "og:description", content: SITE_DESCRIPTION }],
    ["meta", { property: "og:image", content: `${SITE_URL}/favicon.svg` }],
    ["meta", { property: "og:site_name", content: SITE_NAME }],
    ["meta", { property: "og:locale", content: "en_US" }],

    // Twitter Card
    ["meta", { name: "twitter:card", content: "summary" }],
    ["meta", { name: "twitter:url", content: SITE_URL }],
    ["meta", { name: "twitter:title", content: SITE_NAME }],
    ["meta", { name: "twitter:description", content: SITE_DESCRIPTION }],
    ["meta", { name: "twitter:image", content: `${SITE_URL}/favicon.svg` }],
    ["meta", { name: "twitter:site", content: "@muhammadfiaz_" }],
    ["meta", { name: "twitter:creator", content: "@muhammadfiaz_" }],

    // Theme color
    ["meta", { name: "theme-color", content: "#f7a41d" }],
    ["meta", { name: "msapplication-TileColor", content: "#f7a41d" }],

    // Google Analytics
    [
      "script",
      { async: "", src: `https://www.googletagmanager.com/gtag/js?id=${GA_ID}` },
    ],
    [
      "script",
      {},
      `window.dataLayer = window.dataLayer || [];
function gtag(){dataLayer.push(arguments);}
gtag('js', new Date());
gtag('config', '${GA_ID}');`,
    ],

    // Google Tag Manager (noscript fallback is injected after <body> in transformHtml)
    ...(GTM_ID
      ? ([
          [
            "script",
            {},
            `(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start': new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0], j=d.createElement(s), dl=l!='dataLayer'?'&l='+l:''; j.async=true; j.src='https://www.googletagmanager.com/gtm.js?id='+i+dl; f.parentNode.insertBefore(j,f);})(window,document,'script','dataLayer','${GTM_ID}');`,
          ],
        ] as [string, Record<string, string>, string][])
      : []),

    // Google AdSense
    [
      "script",
      {
        async: "",
        src: `https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${ADSENSE_CLIENT_ID}`,
        crossorigin: "anonymous",
      },
    ],

    // Microsoft Clarity
    ...(CLARITY_ID
      ? ([
          [
            "script",
            {},
            `(function(c,l,a,r,i,t,y){
              c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};
              t=l.createElement(r);t.async=1;t.src="https://www.clarity.ms/tag/"+i;
              y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y);
            })(window, document, "clarity", "script", "${CLARITY_ID}");`,
          ],
        ] as [string, Record<string, string>, string][])
      : []),
  ],

  transformHtml(html) {
    if (!GTM_ID) return html;
    const noscript = `<noscript><iframe src="https://www.googletagmanager.com/ns.html?id=${GTM_ID}" height="0" width="0" style="display:none;visibility:hidden"></iframe></noscript>`;
    return html.replace(/<body([^>]*)>/, `<body$1>\n    ${noscript}`);
  },

  ignoreDeadLinks: [/.*\.zig$/],

  transformPageData(pageData: any) {
    const pageTitle = pageData.title || SITE_NAME;
    const pageDescription = pageData.description || SITE_DESCRIPTION;
    // Resolve the published URL. cleanUrls is disabled, so regular pages end
    // in `.html` while directory index pages keep their trailing slash.
    const cleanPath = pageData.relativePath.replace(/\.md$/, "");
    let canonicalUrl: string;
    if (cleanPath === "index") {
      canonicalUrl = `${SITE_URL}/`;
    } else if (cleanPath.endsWith("/index")) {
      canonicalUrl = `${SITE_URL}/${cleanPath.slice(0, -"index".length)}`;
    } else {
      canonicalUrl = `${SITE_URL}/${cleanPath}.html`;
    }

    pageData.frontmatter.head ??= [];
    pageData.frontmatter.head.push(
      ["link", { rel: "canonical", href: canonicalUrl }],
      ["meta", { property: "og:title", content: `${pageTitle} | ${SITE_NAME}` }],
      ["meta", { property: "og:url", content: canonicalUrl }],
      ["meta", { name: "twitter:url", content: canonicalUrl }]
    );

    if (pageData.frontmatter.description) {
      pageData.frontmatter.head.push(
        ["meta", { property: "og:description", content: pageData.frontmatter.description }],
        ["meta", { name: "description", content: pageData.frontmatter.description }]
      );
    }

    // JSON-LD Schema
    const isHome = pageData.relativePath === "index.md";
    const lastUpdated = pageData.lastUpdated
      ? new Date(pageData.lastUpdated).toISOString()
      : new Date().toISOString();

    const graph: any[] = [];

    if (isHome) {
      graph.push({
        "@type": "WebSite",
        name: SITE_NAME,
        url: SITE_URL,
        description: SITE_DESCRIPTION,
        author: {
          "@type": "Person",
          name: "Muhammad Fiaz",
          url: "https://github.com/muhammad-fiaz",
        },
      });
    }

    const primarySchema: Record<string, any> = {
      "@type": isHome ? "SoftwareApplication" : "TechArticle",
      name: isHome ? SITE_NAME : pageTitle,
      description: pageDescription,
      url: canonicalUrl,
      author: {
        "@type": "Person",
        name: "Muhammad Fiaz",
        url: "https://muhammadfiaz.com",
      },
      publisher: {
        "@type": "Person",
        name: "Muhammad Fiaz",
        url: "https://muhammadfiaz.com",
      },
    };

    if (isHome) {
      Object.assign(primarySchema, {
        applicationCategory: "DeveloperApplication",
        operatingSystem: "Cross-platform",
        programmingLanguage: "Zig",
        downloadUrl: "https://github.com/muhammad-fiaz/regex.zig",
        softwareVersion: "0.0.1",
        license: "https://opensource.org/licenses/MIT",
      });
    } else {
      primarySchema["headline"] = pageTitle;
      primarySchema["dateModified"] = lastUpdated;
    }
    graph.push(primarySchema);

    pageData.frontmatter.head.push([
      "script",
      { type: "application/ld+json" },
      JSON.stringify({
        "@context": "https://schema.org",
        "@graph": graph,
      }),
    ]);
  },

  themeConfig: {
    siteTitle: SITE_NAME,

    nav: [
      { text: "Home", link: "/" },
      { text: "Guide", link: "/guide/introduction" },
      { text: "Installation", link: "/guide/installation" },
      { text: "API", link: "/api/regex" },
      { text: "Benchmarks", link: "/guide/benchmarks" },
      { text: "Examples", link: "/examples/" },
      {
        text: "Support",
        items: [
          { text: "Sponsor", link: "https://github.com/sponsors/muhammad-fiaz" },
          { text: "Donate", link: "https://pay.muhammadfiaz.com" },
        ],
      },
      { text: "GitHub", link: "https://github.com/muhammad-fiaz/regex.zig" },
    ],

    sidebar: [
      {
        text: "Guide",
        items: [
          { text: "Introduction", link: "/guide/introduction" },
          { text: "Installation", link: "/guide/installation" },
          { text: "Quick Start", link: "/guide/getting-started" },
          { text: "Architecture & PikeVM", link: "/guide/architecture" },
          { text: "Regex Dialect & Syntax", link: "/guide/syntax" },
          { text: "Inline Options & Limits", link: "/guide/options" },
          { text: "Cross-Platform Targets", link: "/guide/targets" },
          { text: "Benchmarks & Performance", link: "/guide/benchmarks" },
        ],
      },
      {
        text: "API Reference",
        items: [
          { text: "Regex Engine", link: "/api/regex" },
          { text: "Options & Limits", link: "/api/options" },
          { text: "Errors & Diagnostics", link: "/api/errors" },
        ],
      },
      {
        text: "Examples",
        items: [
          { text: "All Examples Overview", link: "/examples/" },
        ],
      },
    ],

    socialLinks: [
      { icon: "github", link: "https://github.com/muhammad-fiaz/regex.zig" },
      { icon: "linkedin", link: "https://www.linkedin.com/in/muhammad-fiaz-" },
      { icon: "x", link: "https://x.com/muhammadfiaz_" },
    ],

    footer: {
      message: "Released under the MIT License.",
      copyright: "Copyright © 2024-2026 Muhammad Fiaz",
    },

    search: {
      provider: "local",
    },

    llms: {
      copyText: "Copy page",
      copiedText: "Copied",
      viewMarkdownText: "View as Markdown",
      openInAIText: "Open in {provider}",
    },

    editLink: {
      pattern: "https://github.com/muhammad-fiaz/regex.zig/edit/main/docs/:path",
      text: "Edit this page on GitHub",
    },

    lastUpdated: {
      text: "Last updated",
      formatOptions: {
        dateStyle: "medium",
        timeStyle: "short",
      },
    },

    outline: {
      level: [2, 3],
      label: "On this page",
    },

    docFooter: {
      prev: "Previous",
      next: "Next",
    },

    returnToTopLabel: "Return to top",
    sidebarMenuLabel: "Menu",
    darkModeSwitchLabel: "Appearance",
    lightModeSwitchTitle: "Switch to dark mode",
    darkModeSwitchTitle: "Switch to light mode",
  },
});
