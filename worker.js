// Serves the confession at 1689.intentmesh.dev (canonical) and ALSO serves it
// URL-preserving at intentmesh.dev/1689/ via internal rewrite, so crawlers,
// preview generators, and AI readers never hit a cross-origin redirect.
export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Apple fetches this to authorize universal links and will not retry a 404,
    // so it is served from the worker rather than static assets, which do not
    // reliably serve dot-directories.
    if (url.pathname === "/.well-known/apple-app-site-association") {
      return new Response(JSON.stringify({
        applinks: {
          details: [{
            appIDs: ["NPVX6Z996W.com.intentmesh.confession1689"],
            components: [{ "/": "/p/*", comment: "paragraph permalinks" }],
          }],
        },
      }), {
        headers: {
          "content-type": "application/json",
          "cache-control": "public, max-age=3600",
        },
      });
    }

    // Paragraph permalinks. These are what the app claims as universal links,
    // so a shared link opens the app when installed and the reader when not.
    // Claiming "/" instead would hijack every visit to the homepage.
    const permalink = url.pathname.match(/^\/(?:1689\/)?p\/([a-z0-9-]+)$/i);
    if (permalink) {
      const target = new URL(request.url);
      target.hostname = "1689.intentmesh.dev";
      target.pathname = "/";
      const page = await env.ASSETS.fetch(new Request(target.toString(), request));
      const html = await page.text();
      // Hand the id to the page so it can scroll without a visible jump.
      return new Response(
        html.replace("</head>",
          `<script>window.__permalink=${JSON.stringify(permalink[1])}</script></head>`),
        { headers: { "content-type": "text/html; charset=utf-8",
                     "cache-control": "public, max-age=300" } });
    }

    if (url.hostname === "intentmesh.dev") {
      // Canonicalize /1689 -> /1689/ so the page's relative URLs resolve
      if (url.pathname === "/1689") {
        return Response.redirect(url.origin + "/1689/" + url.search, 301);
      }
      const inner = url.pathname.replace(/^\/1689\//, "/");
      const rewritten = new Request(
        "https://1689.intentmesh.dev" + inner + url.search, request);
      return env.ASSETS.fetch(rewritten);
    }
    return env.ASSETS.fetch(request);
  },
};
