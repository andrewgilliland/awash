import { readFile } from "node:fs/promises";
import { extname } from "node:path";
import type { Plugin } from "vite";
import { runCheck } from "./check.ts";
import { repoPath } from "./files.ts";
import { saveFile, versionOf } from "./save.ts";

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
        if (!path || (request.method !== "GET" && request.method !== "HEAD")) {
          response.statusCode = 404;
          response.end();
          return;
        }
        try {
          const body = await readFile(path);
          response.setHeader("Content-Type", TYPES[extname(path)] ?? "application/octet-stream");
          // Which version was loaded, for a save to check the file hasn't changed since.
          response.setHeader("X-Version", versionOf(body.toString("utf8")));
          response.setHeader("Cache-Control", "no-store");
          response.end(request.method === "HEAD" ? undefined : body);
        } catch {
          response.statusCode = 404;
          response.end();
        }
      });
      server.middlewares.use("/api/save", async (request, response) => {
        if (request.method !== "POST") {
          response.statusCode = 405;
          response.end();
          return;
        }
        let body = "";
        for await (const chunk of request) {
          body += chunk;
        }
        const { path, base, text } = JSON.parse(body) as { path: string; base: string; text: string };
        const result = await saveFile(repo, path, base, text);
        response.statusCode = result.saved ? 200 : result.reason === "changed" ? 409 : 403;
        response.setHeader("Content-Type", "application/json");
        response.end(JSON.stringify(result));
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
