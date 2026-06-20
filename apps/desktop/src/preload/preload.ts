// /Users/roman/Developer/iosbrowser/apps/desktop/src/preload/preload.ts
import { contextBridge, ipcRenderer } from "electron";
import type { BrowserProfile, ProxyConfig } from "@browser/api-contracts";

const api = {
  activateProfile(profile: BrowserProfile) {
    return ipcRenderer.invoke("profile:activate", profile);
  },
  setProfileProxy(proxy: ProxyConfig) {
    return ipcRenderer.invoke("profile:setProxy", proxy);
  },
  createTab(input: { tabId: string; partition: string; url: string }) {
    return ipcRenderer.invoke("tab:create", input);
  }
};

contextBridge.exposeInMainWorld("browserPlatform", api);

export type DesktopBridge = typeof api;
