// /Users/roman/Developer/iosbrowser/apps/desktop/vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  root: ".",
  build: {
    outDir: "dist/renderer",
    emptyOutDir: false
  },
  server: {
    port: 5173,
    strictPort: true
  }
});
