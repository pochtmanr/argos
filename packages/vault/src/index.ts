// /Users/roman/Developer/iosbrowser/packages/vault/src/index.ts
import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";

export type EncryptedPayload = {
  algorithm: "aes-256-gcm";
  keyId: string;
  iv: string;
  authTag: string;
  ciphertext: string;
};

export function encryptVaultPayload(plaintext: Uint8Array, key: Uint8Array, keyId: string): EncryptedPayload {
  if (key.byteLength !== 32) throw new Error("Vault key must be 32 bytes");
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  return {
    algorithm: "aes-256-gcm",
    keyId,
    iv: iv.toString("base64url"),
    authTag: cipher.getAuthTag().toString("base64url"),
    ciphertext: ciphertext.toString("base64url")
  };
}

export function decryptVaultPayload(payload: EncryptedPayload, key: Uint8Array): Buffer {
  if (payload.algorithm !== "aes-256-gcm") throw new Error(`Unsupported algorithm: ${payload.algorithm}`);
  const decipher = createDecipheriv("aes-256-gcm", key, Buffer.from(payload.iv, "base64url"));
  decipher.setAuthTag(Buffer.from(payload.authTag, "base64url"));
  return Buffer.concat([decipher.update(Buffer.from(payload.ciphertext, "base64url")), decipher.final()]);
}
