// /Users/roman/Developer/iosbrowser/apps/desktop/src/renderer/global.d.ts
import type { DesktopBridge } from "../preload/preload";

declare global {
  interface Window {
    browserPlatform: DesktopBridge;
  }
}
