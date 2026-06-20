// /Users/roman/Developer/iosbrowser/apps/desktop/src/main/main.ts
import { BrowserWindow, app, protocol } from "electron";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { registerBrowserIpc } from "./ipc.js";

const dirname = path.dirname(fileURLToPath(import.meta.url));
const isDev = process.env.NODE_ENV === "development";

protocol.registerSchemesAsPrivileged([
  { scheme: "browser", privileges: { standard: true, secure: true, supportFetchAPI: true } }
]);

async function createWindow(): Promise<void> {
  const window = new BrowserWindow({
    width: 1440,
    height: 960,
    minWidth: 1100,
    minHeight: 720,
    title: "AI Browser",
    webPreferences: {
      preload: path.join(dirname, "../preload/preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true
    }
  });

  registerBrowserIpc(window);

  if (isDev) {
    await window.loadURL("http://127.0.0.1:5173");
  } else {
    await window.loadFile(path.join(dirname, "../renderer/index.html"));
  }
}

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

await app.whenReady();
await createWindow();
