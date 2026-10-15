---
name: context7-mcp
description: Fetch current library documentation with Context7 MCP tools.
---

# Context7 MCP

## Steps

1. `resolve-library-id` with the library name and what to look up in the library's documentation. Use the official library name with proper punctuation (e.g., "Next.js" not "nextjs", "Customer.io" not "customerio", "Three.js" not "threejs")
2. Pick the best match by: exact name match, description relevance, code snippet count, source reputation (High/Medium preferred), and benchmark score (higher is better). Use version-specific IDs when the user mentions a version
3. `query-docs` with the selected library ID and what to look up in the library's documentation (not single words), scoped to a single concept. If the question spans multiple distinct concepts (e.g. routing and auth and caching), make a separate `query-docs` call per concept with the same library ID, unless the question is about how the concepts interact — combined queries dilute ranking and return shallow results for each topic
4. Answer using the fetched docs
