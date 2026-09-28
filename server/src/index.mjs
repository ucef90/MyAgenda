import { Store } from "./store.mjs";
import { loadConfig, dataDirectory } from "./config.mjs";
import { createApp } from "./app.mjs";
process.umask(0o077);
const config = loadConfig(),
  store = new Store(`${dataDirectory()}/agenda.sqlite`);
store.prune();
const { app } = createApp(store, config);
const server = app.listen(
  Number(process.env.PORT || 8787),
  process.env.HOST || "127.0.0.1",
  () =>
    console.log(
      "MyAgenda bridge prêt. Aucune donnée personnelle dans les journaux.",
    ),
);
const maintenance = setInterval(() => store.prune(), 3600_000).unref();
for (const signal of ["SIGTERM", "SIGINT"])
  process.on(signal, () => {
    clearInterval(maintenance);
    server.close(() => {
      store.close();
      process.exit(0);
    });
  });
