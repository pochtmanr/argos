// /Users/roman/Developer/iosbrowser/apps/desktop/src/main/ipc.ts
import { BrowserView, BrowserWindow, ipcMain, session } from "electron";
import { BrowserProfile, ProxyConfig } from "@browser/api-contracts";
import { createProfileContainer } from "@browser/profile-engine";
import { toElectronProxyRules } from "@browser/proxy-engine";

export function registerBrowserIpc(window: BrowserWindow): void {
  const views = new Map<string, BrowserView>();

  ipcMain.handle("profile:activate", async (_event, input: unknown) => {
    const profile = BrowserProfile.parse(input);
    const container = createProfileContainer(profile, "electron");
    const profileSession = session.fromPartition(container.storagePartition, { cache: true });
    profileSession.setPermissionRequestHandler((_webContents, permission, callback) => {
      callback(["clipboard-read", "media", "geolocation"].includes(permission) === false);
    });
    return container;
  });

  ipcMain.handle("profile:setProxy", async (_event, input: unknown) => {
    const config = ProxyConfig.parse(input);
    const rules = toElectronProxyRules(config);
    await session.defaultSession.setProxy(rules);
    return rules;
  });

  ipcMain.handle("tab:create", async (_event, input: { tabId: string; partition: string; url: string }) => {
    const view = new BrowserView({
      webPreferences: {
        partition: input.partition,
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: true
      }
    });
    views.set(input.tabId, view);
    window.setBrowserView(view);
    view.setBounds({ x: 260, y: 0, width: 1024, height: 768 });
    await view.webContents.loadURL(input.url);
    return { tabId: input.tabId, url: view.webContents.getURL() };
  });
}
