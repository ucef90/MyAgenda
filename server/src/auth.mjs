import {
  InvalidClientMetadataError,
  InvalidGrantError,
  InvalidTokenError,
  InvalidScopeError,
  InvalidTargetError,
  InvalidRequestError,
} from "@modelcontextprotocol/sdk/server/auth/errors.js";
import { randomToken, digest, verifyPassword } from "./store.mjs";
export const scopes = ["agenda:read", "agenda:propose"];
const escape = (text) =>
  String(text).replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
export class OwnerAuth {
  constructor(store, config) {
    this.store = store;
    this.config = config;
    this.clientsStore = {
      getClient: (id) => store.get("client", id),
      registerClient: (client) => {
        if (
          !client.redirect_uris?.length ||
          client.redirect_uris.some((u) => !config.redirects.includes(u))
        )
          throw new InvalidClientMetadataError(
            "Redirect URI not allowed by the owner.",
          );
        if (
          client.grant_types?.some(
            (t) => !["authorization_code", "refresh_token"].includes(t),
          )
        )
          throw new InvalidClientMetadataError("Unsupported grant.");
        if (store.list("client").length >= 100)
          throw new InvalidClientMetadataError("Registration limit reached.");
        const result = {
          ...client,
          client_id: client.client_id || randomToken(),
          client_id_issued_at: Math.floor(Date.now() / 1000),
        };
        store.put("client", result.client_id, result);
        return result;
      },
    };
  }
  resource(resource) {
    if (!resource || resource.href !== this.config.resource)
      throw new InvalidTargetError(
        "The MyAgenda MCP resource must be specified.",
      );
  }
  async authorize(client, params, res) {
    this.resource(params.resource);
    if (!this.config.redirects.includes(params.redirectUri))
      throw new InvalidRequestError("Redirect not allowed.");
    const requested = params.scopes?.length ? params.scopes : scopes;
    if (requested.some((s) => !scopes.includes(s)))
      throw new InvalidScopeError("Unknown scope.");
    if (!/^[A-Za-z0-9_-]{43}$/.test(params.codeChallenge))
      throw new InvalidRequestError("S256 challenge required.");
    const nonce = randomToken();
    this.store.put(
      "consent",
      digest(nonce),
      {
        clientId: client.client_id,
        ...params,
        resource: params.resource.href,
        scopes: requested,
      },
      Date.now() + 10 * 60_000,
    );
    res.cookie("myagenda_consent", nonce, {
      httpOnly: true,
      secure: !this.config.development,
      sameSite: "lax",
      path: "/consent",
      maxAge: 600_000,
    });
    res
      .type("html")
      .send(
        `<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Autoriser MyAgenda</title><style>body{font:18px system-ui;max-width:560px;margin:8vh auto;padding:24px;color:#18264c;background:#f5f7fc}input,button{box-sizing:border-box;width:100%;padding:16px;margin:12px 0;font:inherit}button{background:#4538bd;color:white;border:0;border-radius:12px}</style><h1>Relier ChatGPT Work</h1><p>Client : ${escape(client.client_name || "ChatGPT Work")}</p><p>Autorisez l’accès aux tâches que vous partagez et ${requested.includes("agenda:propose") ? "la création de propositions à valider sur votre iPhone" : "leur lecture"}. Aucun mail ne peut être envoyé et aucune tâche n’est modifiée directement.</p><form method="post" action="/consent"><input type="hidden" name="nonce" value="${nonce}"><label>Mot de passe du serveur MyAgenda<input name="password" type="password" autocomplete="current-password" required maxlength="256"></label><button name="decision" value="allow">Autoriser</button><button name="decision" value="deny" formnovalidate>Refuser</button></form></html>`,
      );
  }
  consent(req, res) {
    const { nonce, password, decision } = req.body || {};
    const cookie = req.headers.cookie
      ?.split(";")
      .map((s) => s.trim())
      .find((s) => s.startsWith("myagenda_consent="))
      ?.slice(17);
    if (
      typeof nonce !== "string" ||
      nonce !== cookie ||
      !["allow", "deny"].includes(decision)
    )
      return res
        .status(400)
        .send("Session expirée. Recommencez la connexion depuis Work.");
    const key = digest(nonce),
      pending = this.store.get("consent", key);
    if (!pending) return res.status(400).send("Autorisation expirée.");
    if (
      decision === "allow" &&
      (typeof password !== "string" ||
        password.length > 256 ||
        !verifyPassword(password, this.config.ownerPasswordHash))
    )
      return res
        .status(403)
        .send("Mot de passe incorrect. Revenez en arrière pour réessayer.");
    this.store.delete("consent", key);
    res.clearCookie("myagenda_consent", {
      path: "/consent",
      secure: !this.config.development,
      httpOnly: true,
      sameSite: "lax",
    });
    const redirect = new URL(pending.redirectUri);
    if (pending.state) redirect.searchParams.set("state", pending.state);
    // Issuer response identification is not advertised; use the exact callback from Work.
    if (decision === "deny")
      redirect.searchParams.set("error", "access_denied");
    else {
      const code = randomToken();
      this.store.put("code", digest(code), pending, Date.now() + 60_000);
      redirect.searchParams.set("code", code);
    }
    res.redirect(303, redirect.href);
  }
  code(client, code) {
    const pending = this.store.get("code", digest(code));
    if (!pending || pending.clientId !== client.client_id)
      throw new InvalidGrantError("Invalid or expired authorization code.");
    return pending;
  }
  async challengeForAuthorizationCode(client, code) {
    return this.code(client, code).codeChallenge;
  }
  issue(clientId, grantedScopes, family = randomToken()) {
    const access = randomToken(),
      refresh = randomToken();
    const expiresAt = Math.floor(Date.now() / 1000) + 3600;
    this.store.put(
      "access",
      digest(access),
      {
        clientId,
        scopes: grantedScopes,
        resource: this.config.resource,
        expiresAt,
        family,
      },
      expiresAt * 1000,
    );
    this.store.put(
      "refresh",
      digest(refresh),
      {
        clientId,
        scopes: grantedScopes,
        resource: this.config.resource,
        family,
        used: false,
      },
      Date.now() + 30 * 86400_000,
    );
    return {
      access_token: access,
      token_type: "Bearer",
      expires_in: 3600,
      refresh_token: refresh,
      scope: grantedScopes.join(" "),
    };
  }
  async exchangeAuthorizationCode(
    client,
    code,
    _verifier,
    redirectUri,
    resource,
  ) {
    this.resource(resource);
    return this.store.transaction(() => {
      const pending = this.code(client, code);
      if (
        redirectUri !== pending.redirectUri ||
        pending.resource !== resource.href
      )
        throw new InvalidGrantError("Authorization binding mismatch.");
      this.store.delete("code", digest(code));
      return this.issue(client.client_id, pending.scopes);
    });
  }
  revokeFamily(family) {
    for (const kind of ["access", "refresh"])
      for (const t of this.store.list(kind))
        if (t.family === family) this.store.delete(kind, t.id);
  }
  async exchangeRefreshToken(client, token, requestedScopes, resource) {
    this.resource(resource);
    const key = digest(token),
      old = this.store.get("refresh", key);
    if (
      !old ||
      old.clientId !== client.client_id ||
      old.resource !== resource.href
    )
      throw new InvalidGrantError("Invalid refresh token.");
    if (old.used) {
      this.revokeFamily(old.family);
      throw new InvalidGrantError("Refresh token reuse: session revoked.");
    }
    const requested = requestedScopes ?? old.scopes;
    if (requested.some((s) => !old.scopes.includes(s)))
      throw new InvalidScopeError("Scope escalation refused.");
    return this.store.transaction(() => {
      this.store.put(
        "refresh",
        key,
        { ...old, used: true },
        Date.now() + 30 * 86400_000,
      );
      return this.issue(client.client_id, requested, old.family);
    });
  }
  async verifyAccessToken(token) {
    const access = this.store.get("access", digest(token));
    if (!access || access.resource !== this.config.resource)
      throw new InvalidTokenError("Invalid or expired token.");
    return { token, ...access };
  }
  async revokeToken(client, request) {
    const token =
      this.store.get("access", digest(request.token)) ||
      this.store.get("refresh", digest(request.token));
    if (token?.clientId === client.client_id) this.revokeFamily(token.family);
  }
}
