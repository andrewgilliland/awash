import { readFile } from "node:fs/promises";
import { extname } from "node:path";
import type { Plugin } from "vite";
import { runCheck } from "./check";
import { repoPath } from "./files";

const TYPES: Record<string, string> = {
  ".json": "application/json",
  ".png": "image/png",
  ".tscn": "text/plain; charset=utf-8",
  ".tres": "text/plain; charset=utf-8",
};

// The World editor's server side, inside Vite's dev server: the repo's files under /repo/, read
// only from the folders the editor may read, and the Check, which runs the game's tests.
export function worldEditorApi(repo: string): Plugin {
  return {
    name: "world-editor-api",
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
      server.middlewares.use("/api/check", async (request, response) => {
        if (request.method !== "POST") {
          response.statusCode = 405;
          response.end();
          return;
        }
        const result = await runCheck(repo);
        response.setHeader("Content-Type", "application/json");
        response.end(JSON.stringify(result));
      });
    },
  };
}
