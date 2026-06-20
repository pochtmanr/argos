// /Users/roman/Developer/iosbrowser/packages/proxy-engine/src/index.ts
import type { ProxyConfig } from "@browser/api-contracts";

export type ElectronProxyRules = {
  proxyRules: string;
  proxyBypassRules: string;
};

export function assertProxyConfig(config: ProxyConfig): void {
  if (config.protocol === "ssh" && !config.sshKeyRef && !config.passwordRef) {
    throw new Error("SSH proxy requires an sshKeyRef or passwordRef");
  }
  if (config.host === "localhost" || config.host === "127.0.0.1") {
    throw new Error("Loopback proxies require an explicit local-network policy override");
  }
}

export function toElectronProxyRules(config: ProxyConfig): ElectronProxyRules {
  assertProxyConfig(config);
  const scheme = config.protocol === "socks5" ? "socks5" : config.protocol;
  const endpoint = `${scheme}://${config.host}:${config.port}`;
  return {
    proxyRules: `${scheme}=${endpoint}`,
    proxyBypassRules: config.bypassRules.join(",")
  };
}

export function proxyFingerprintLabel(config: ProxyConfig): string {
  return `${config.protocol}:${config.host}:${config.port}`;
}
