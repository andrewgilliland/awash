import { readFile } from "node:fs/promises";
import { extname } from "node:path";
import type { Plugin } from "vite";
import { repoPath } from "./files.ts";

const TYPES: Record<string, string> = { ".png": "image/png" };

// The Codex's server side, inside Vite's dev server: the art under /repo/, and the Codex itself,
// read afresh from the game's files at /api/codex. It reads only; it never writes.
export function codexApi(repo: string): Plugin {
  return {
    name: "codex-api",
    configureServer(server) {
      server.middlewares.use("/repo/", async (request, response) => {
        const path = repoPath(repo, decodeURIComponent((request.url ?? "").split("?")[0].replace(/^\//, "")));
        if (!path || request.method !== "GET") {
          response.statusCode = 404;
          response.end();
          return;
        }
        try {
          const body = await readFile(path);
          response.setHeader("Content-Type", TYPES[extname(path)] ?? "application/octet-stream");
          response.setHeader("Cache-Control", "no-store");
          response.end(body);
        } catch {
          response.statusCode = 404;
          response.end();
        }
      });
      server.middlewares.use("/api/codex", async (_request, response) => {
        const { buildCodex } = await import("./codex.ts");
        response.setHeader("Content-Type", "application/json");
        response.setHeader("Cache-Control", "no-store");
        response.end(JSON.stringify(await buildCodex(repo)));
      });
    },
  };
}
