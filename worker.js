// Serves the confession at 1689.intentmesh.dev (canonical) and ALSO serves it
// URL-preserving at intentmesh.dev/1689/ via internal rewrite, so crawlers,
// preview generators, and AI readers never hit a cross-origin redirect.
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
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
