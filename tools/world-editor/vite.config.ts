import { resolve } from "node:path";
import { defineConfig } from "vite";
import { worldEditorApi } from "./server/api.ts";

// Local only: the editor shows the packs' art, which their licences forbid redistributing.
export default defineConfig({
  plugins: [worldEditorApi(resolve(import.meta.dirname, "../.."))],
  server: { host: "localhost", port: 5174, open: true },
});
