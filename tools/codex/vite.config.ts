import { resolve } from "node:path";
import { defineConfig } from "vite";
import { codexApi } from "./server/api.ts";

// Local only: the Codex shows the packs' art, which their licences forbid redistributing.
export default defineConfig({
  plugins: [codexApi(resolve(import.meta.dirname, "../.."))],
  server: { host: "localhost", port: 5175, open: "/" },
});
