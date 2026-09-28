import { readFileSync } from "node:fs";
import { resolve } from "node:path";
export const dataDirectory = () =>
  resolve(process.env.MYAGENDA_DATA || "./data");
export function configFrom(data) {
  const u = new URL(data.url);
  if (
    u.protocol !== "https:" ||
    u.username ||
    u.password ||
    u.pathname !== "/" ||
    u.search ||
    u.hash
  )
    throw new Error("Adresse HTTPS sans chemin requise.");
  if (
    !Array.isArray(data.redirects) ||
    !data.redirects.length ||
    data.redirects.some((r) => {
      const u = new URL(r);
      return u.protocol !== "https:" || u.username || u.password || u.hash;
    })
  )
    throw new Error("Callback HTTPS exact de Work requis.");
  if (!/^[a-f0-9]{32}:[a-f0-9]{128}$/.test(data.ownerPasswordHash))
    throw new Error("Mot de passe serveur non configuré.");
  return {
    ...data,
    url: u.origin,
    resource: `${u.origin}/mcp`,
    development: false,
  };
}
export function loadConfig() {
  return configFrom(
    JSON.parse(readFileSync(`${dataDirectory()}/config.json`, "utf8")),
  );
}
