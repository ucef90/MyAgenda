import { mkdirSync, writeFileSync, existsSync, readFileSync } from "node:fs";
import { Store, passwordHash, randomToken } from "./store.mjs";
import { configFrom, dataDirectory, loadConfig } from "./config.mjs";
process.umask(0o077);
const [command, ...args] = process.argv.slice(2),
  dir = dataDirectory();
const option = (name) => args[args.indexOf(name) + 1];
mkdirSync(dir, { recursive: true, mode: 0o700 });
if (command === "setup") {
  if (existsSync(`${dir}/config.json`))
    throw new Error(
      "Serveur déjà configuré. Utilisez callback pour modifier le retour Work.",
    );
  if (!args.includes("--url") || !args.includes("--redirect"))
    throw new Error(
      "Usage : npm run setup -- --url https://votre-domaine --redirect URL_EXACTE_COPIÉE_DE_WORK",
    );
  const password = randomToken();
  const data = {
    url: option("--url"),
    redirects: [option("--redirect")],
    ownerPasswordHash: passwordHash(password),
  };
  configFrom(data);
  writeFileSync(`${dir}/config.json`, JSON.stringify(data, null, 2), {
    mode: 0o600,
    flag: "wx",
  });
  writeFileSync(`${dir}/owner-password.txt`, password + "\n", {
    mode: 0o600,
    flag: "wx",
  });
  console.log(
    `Serveur configuré. Mot de passe privé : ${dir}/owner-password.txt. Conservez-le dans votre gestionnaire de mots de passe, puis supprimez ce fichier. Ne le collez pas dans ChatGPT.`,
  );
} else if (command === "callback") {
  if (!args[0])
    throw new Error(
      "Usage : node src/cli.mjs callback URL_EXACTE_COPIÉE_DE_WORK",
    );
  const data = JSON.parse(readFileSync(`${dir}/config.json`, "utf8"));
  data.redirects = [args[0]];
  configFrom(data);
  writeFileSync(`${dir}/config.json`, JSON.stringify(data, null, 2), {
    mode: 0o600,
  });
  console.log("Callback actualisé. Redémarrez le serveur et reconnectez Work.");
} else if (command === "manifest") {
  const c = loadConfig();
  console.log(
    JSON.stringify(
      {
        $schema: "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json",
        mcpServers: { myagenda: { type: "streamable-http", url: c.resource } },
      },
      null,
      2,
    ),
  );
} else {
  loadConfig();
  const store = new Store(`${dir}/agenda.sqlite`);
  if (command === "pair") {
    const code = store.pairingCode();
    writeFileSync(`${dir}/pairing-code.txt`, code + "\n", { mode: 0o600 });
    console.log(
      `Code valable 10 minutes, une seule fois : ${dir}/pairing-code.txt. Saisissez-le dans MyAgenda, pas dans la conversation.`,
    );
  } else if (command === "devices")
    console.log(
      JSON.stringify(
        store
          .list("device")
          .map((d) => ({ id: d.id, name: d.name, updatedAt: d.updatedAt })),
        null,
        2,
      ),
    );
  else if (command === "revoke-device" && args[0]) {
    store.removeDevice(args[0]);
    console.log("Appareil et données partagées supprimés.");
  } else if (command === "revoke-work") {
    for (const kind of ["access", "refresh", "code", "consent", "client"])
      for (const record of store.list(kind)) store.delete(kind, record.id);
    console.log("Toutes les autorisations Work ont été révoquées.");
  } else
    throw new Error(
      "Commandes : setup, callback, pair, devices, revoke-device ID, revoke-work, manifest",
    );
  store.close();
}
