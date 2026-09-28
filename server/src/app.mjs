import express from "express";
import { z } from "zod";
import { mcpAuthRouter } from "@modelcontextprotocol/sdk/server/auth/router.js";
import { requireBearerAuth } from "@modelcontextprotocol/sdk/server/auth/middleware/bearerAuth.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { OwnerAuth, scopes } from "./auth.mjs";
import { createMcp } from "./mcp.mjs";
import { ApiError } from "./store.mjs";
import { snapshotSchema } from "./schemas.mjs";

// Global limits are intentional: this is a single-owner server. No proxy IP trust.
function throttle(max, duration = 60_000) {
  let reset = 0,
    count = 0;
  return (_req, res, next) => {
    if (Date.now() > reset) {
      reset = Date.now() + duration;
      count = 0;
    }
    if (++count > max)
      return res
        .status(429)
        .json({ error: "Trop de tentatives. Réessayez dans une minute." });
    next();
  };
}
export function createApp(store, config) {
  const app = express(),
    auth = new OwnerAuth(store, config);
  app.disable("x-powered-by");
  app.use((req, res, next) => {
    res.set({
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "no-referrer",
      "X-Frame-Options": "DENY",
      "Content-Security-Policy":
        "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'",
    });
    // Reject Host spoofing/DNS rebinding and cross-origin browser calls.
    if (req.headers.host !== new URL(config.url).host)
      return res.status(403).end();
    if (req.headers.origin && req.headers.origin !== new URL(config.url).origin)
      return res.status(403).end();
    next();
  });
  app.get("/health", (_req, res) =>
    res.json({ service: "MyAgenda", version: "0.5.0" }),
  );
  app.post(
    "/consent",
    throttle(10),
    express.urlencoded({ extended: false, limit: "4kb" }),
    (req, res) => auth.consent(req, res),
  );
  app.use(
    mcpAuthRouter({
      provider: auth,
      issuerUrl: new URL(config.url),
      resourceServerUrl: new URL(config.resource),
      scopesSupported: scopes,
      resourceName: "MyAgenda privé",
    }),
  );
  app.post(
    "/v1/pair",
    throttle(20),
    express.json({ limit: "4kb" }),
    (req, res) => {
      const input = z
        .object({
          code: z.string().min(1).max(100),
          name: z.string().trim().min(1).max(80),
        })
        .strict()
        .parse(req.body);
      res.json(store.pair(input.code, input.name));
    },
  );
  app.use(
    "/v1",
    throttle(120),
    (req, res, next) => {
      const value = req.headers.authorization;
      const device =
        typeof value === "string" &&
        value.startsWith("Bearer ") &&
        value.length < 200
          ? store.deviceForToken(value.slice(7))
          : null;
      if (!device)
        return res
          .status(401)
          .json({ error: "Appareil déconnecté. Associez-le à nouveau." });
      req.device = device;
      next();
    },
    express.json({ limit: "2mb" }),
  );
  app.post("/v1/sync", (req, res) => {
    const { revision, tasks } = snapshotSchema.parse(req.body);
    res.json(store.sync(req.device.id, revision, tasks));
  });
  app.post("/v1/proposals/:id/resolve", (req, res) => {
    const { decision } = z
      .object({ decision: z.enum(["accepted", "rejected"]) })
      .strict()
      .parse(req.body);
    res.json(store.resolve(req.device.id, req.params.id, decision));
  });
  app.delete("/v1/device", (req, res) => {
    store.removeDevice(req.device.id);
    res.json({ disconnected: true });
  });
  app.use(
    "/mcp",
    requireBearerAuth({
      verifier: auth,
      requiredScopes: ["agenda:read"],
      resourceMetadataUrl: `${config.url}/.well-known/oauth-protected-resource/mcp`,
    }),
    throttle(120),
  );
  app.post("/mcp", express.json({ limit: "64kb" }), async (req, res) => {
    const server = createMcp(store, req.auth);
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: undefined,
      enableJsonResponse: true,
    });
    res.on("close", () => {
      void transport.close();
      void server.close();
    });
    await server.connect(transport);
    await transport.handleRequest(req, res, req.body);
  });
  app.all("/mcp", (_req, res) => res.status(405).end());
  app.use((err, _req, res, _next) => {
    if (res.headersSent) return;
    res
      .status(
        err instanceof ApiError
          ? err.status
          : err instanceof z.ZodError
            ? 400
            : err.type === "entity.too.large"
              ? 413
              : 500,
      )
      .json({
        error:
          err instanceof ApiError
            ? err.message
            : err instanceof z.ZodError
              ? "Données invalides ou trop volumineuses."
              : "Le serveur ne peut pas traiter la demande.",
      });
  });
  return { app, auth };
}
