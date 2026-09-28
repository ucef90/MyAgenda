import test from "node:test";
import { createServer, request as httpRequest } from "node:http";
import assert from "node:assert/strict";
import { randomUUID, createHash } from "node:crypto";
import { Store, passwordHash, taskHash } from "../src/store.mjs";
import { createApp } from "../src/app.mjs";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

const task = {
  id: "training-1",
  title: "Formation Power BI",
  project: "Client exemple",
  category: "training",
  professional: true,
  minutes: 120,
  scheduledAt: "2030-10-02T09:00:00.000Z",
  deadline: null,
  status: "planned",
  preparation: { support: null, order: null, email: null },
};
const evidence = {
  title: "Confirmation de signature",
  messageId: "abc123",
  date: "2030-09-28T09:00:00.000Z",
  url: "https://mail.google.com/mail/u/0/#all/abc123",
};
async function fixture(t) {
  const store = new Store(":memory:");
  const config = {
    url: "http://127.0.0.1",
    resource: "",
    redirects: ["https://chatgpt.com/connector/oauth/test"],
    ownerPasswordHash: passwordHash("owner-test-password"),
    development: true,
  };
  const listener = createServer().listen(0, "127.0.0.1");
  await new Promise((resolve) => listener.once("listening", resolve));
  config.url = `http://127.0.0.1:${listener.address().port}`;
  config.resource = `${config.url}/mcp`;
  const { app, auth } = createApp(store, config);
  listener.on("request", app);
  t.after(async () => {
    await new Promise((resolve) => listener.close(resolve));
    store.close();
  });
  const request = (
    path,
    { token, body, method = body ? "POST" : "GET", ...other } = {},
  ) =>
    fetch(config.url + path, {
      method,
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(body ? { "Content-Type": "application/json" } : {}),
        ...other.headers,
      },
      body: body ? JSON.stringify(body) : undefined,
      redirect: "manual",
    });
  const pair = async (name = "iPhone test") => {
    const res = await request("/v1/pair", {
      body: { code: store.pairingCode(), name },
    });
    assert.equal(res.status, 200);
    return res.json();
  };
  const oauth = async () => {
    const reg = await request("/register", {
      body: {
        client_name: "Work test",
        redirect_uris: config.redirects,
        token_endpoint_auth_method: "none",
        grant_types: ["authorization_code", "refresh_token"],
        response_types: ["code"],
      },
    });
    assert.equal(reg.status, 201);
    const client = await reg.json();
    const verifier = "a".repeat(64),
      challenge = createHash("sha256").update(verifier).digest("base64url");
    const params = new URLSearchParams({
      client_id: client.client_id,
      redirect_uri: config.redirects[0],
      response_type: "code",
      state: "anti-csrf-state",
      code_challenge: challenge,
      code_challenge_method: "S256",
      resource: config.resource,
      scope: "agenda:read agenda:propose",
    });
    const page = await request("/authorize?" + params);
    assert.equal(page.status, 200);
    const html = await page.text(),
      nonce = html.match(/name="nonce" value="([^"]+)"/)[1];
    const cookie = page.headers.get("set-cookie").split(";")[0];
    const bad = await fetch(config.url + "/consent", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        nonce,
        password: "owner-test-password",
        decision: "allow",
      }),
      redirect: "manual",
    });
    assert.equal(bad.status, 400, "consent requires browser-bound nonce");
    const consent = await fetch(config.url + "/consent", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Cookie: cookie,
      },
      body: new URLSearchParams({
        nonce,
        password: "owner-test-password",
        decision: "allow",
      }),
      redirect: "manual",
    });
    assert.equal(consent.status, 303);
    const callback = new URL(consent.headers.get("location"));
    assert.equal(callback.searchParams.get("state"), "anti-csrf-state");
    const code = callback.searchParams.get("code");
    const exchange = (values) =>
      fetch(config.url + "/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          client_id: client.client_id,
          resource: config.resource,
          ...values,
        }),
      });
    const grant = {
      grant_type: "authorization_code",
      code,
      code_verifier: verifier,
      redirect_uri: config.redirects[0],
    };
    return { client, exchange, grant };
  };
  return { store, config, auth, request, pair, oauth };
}

test("Private API, host/origin checks and single-use device pairing", async (t) => {
  const f = await fixture(t);
  assert.equal((await f.request("/v1/sync", { body: {} })).status, 401);
  assert.equal((await f.request("/mcp", { body: {} })).status, 401);
  const hostStatus = await new Promise((resolve) => {
    const req = httpRequest(
      f.config.url + "/health",
      { headers: { Host: "attacker.invalid" } },
      (res) => {
        res.resume();
        resolve(res.statusCode);
      },
    );
    req.end();
  });
  assert.equal(hostStatus, 403);
  assert.equal(
    (
      await f.request("/health", {
        headers: { Origin: "https://attacker.invalid" },
      })
    ).status,
    403,
  );
  const code = f.store.pairingCode();
  assert.equal(
    (await f.request("/v1/pair", { body: { code, name: "Téléphone" } })).status,
    200,
  );
  assert.equal(
    (await f.request("/v1/pair", { body: { code, name: "Autre" } })).status,
    401,
  );
  const d = await f.pair();
  assert.ok(!JSON.stringify(f.store.list("device")).includes(d.token));
  await f.request("/v1/device", { method: "DELETE", token: d.token });
  assert.equal(
    (
      await f.request("/v1/sync", {
        token: d.token,
        body: { revision: 1, tasks: [] },
      })
    ).status,
    401,
  );
});

test("OAuth exact redirects, PKCE, audience, single-use code and refresh replay", async (t) => {
  const f = await fixture(t);
  const badRegistration = await f.request("/register", {
    body: {
      redirect_uris: ["https://attacker.invalid/cb"],
      token_endpoint_auth_method: "none",
    },
  });
  assert.equal(badRegistration.status, 400);
  const metadata = await (
    await f.request("/.well-known/oauth-protected-resource/mcp")
  ).json();
  assert.equal(metadata.resource, f.config.resource);
  const issuer = await (
    await f.request("/.well-known/oauth-authorization-server")
  ).json();
  assert.equal(issuer.issuer, f.config.url + "/");
  assert.deepEqual(issuer.code_challenge_methods_supported, ["S256"]);
  const { exchange, grant } = await f.oauth();
  assert.equal(
    (await exchange({ ...grant, code_verifier: "b".repeat(64) })).status,
    400,
  );
  assert.equal(
    (await exchange({ ...grant, resource: "https://attacker.invalid/mcp" }))
      .status,
    400,
  );
  assert.equal(
    (await exchange({ ...grant, redirect_uri: "https://attacker.invalid/cb" }))
      .status,
    400,
  );
  const res = await exchange(grant);
  assert.equal(res.status, 200);
  const tokens = await res.json();
  assert.equal((await exchange(grant)).status, 400);
  const next = await exchange({
    grant_type: "refresh_token",
    refresh_token: tokens.refresh_token,
  });
  assert.equal(next.status, 200);
  const fresh = await next.json();
  assert.equal(
    (
      await exchange({
        grant_type: "refresh_token",
        refresh_token: tokens.refresh_token,
      })
    ).status,
    400,
  );
  await assert.rejects(f.auth.verifyAccessToken(fresh.access_token));
});

test("Real MCP lifecycle: Gmail evidence proposal, inbox, no automatic task mutation", async (t) => {
  const f = await fixture(t),
    d = await f.pair(),
    other = await f.pair("Mac");
  const sync = await f.request("/v1/sync", {
    token: d.token,
    body: { revision: 1, tasks: [task] },
  });
  assert.equal(sync.status, 200);
  const { exchange, grant } = await f.oauth();
  const tokens = await (await exchange(grant)).json();
  const client = new Client({ name: "integration-test", version: "1" });
  await client.connect(
    new StreamableHTTPClientTransport(new URL(f.config.resource), {
      requestInit: {
        headers: { Authorization: `Bearer ${tokens.access_token}` },
      },
    }),
  );
  t.after(() => client.close());
  assert.equal((await client.listTools()).tools.length, 5);
  const result = await client.callTool({
    name: "list_tasks",
    arguments: { deviceId: d.deviceId },
  });
  const listed = result.structuredContent.tasks[0];
  assert.equal(listed.basisHash, taskHash(task));
  const input = {
    deviceId: d.deviceId,
    taskId: task.id,
    basisHash: listed.basisHash,
    requestId: randomUUID(),
    field: "order",
    value: true,
    reason: "Le mail référence explicitement le bon signé pour cette session.",
    evidence: [evidence],
  };
  const proposed = await client.callTool({
    name: "propose_preparation",
    arguments: input,
  });
  assert.equal(proposed.isError, undefined);
  const id = proposed.structuredContent.proposalId;
  const repeat = await client.callTool({
    name: "propose_preparation",
    arguments: input,
  });
  assert.equal(repeat.structuredContent.proposalId, id);
  assert.equal(
    f.store.get("device", d.deviceId).tasks[0].preparation.order,
    null,
  );
  const inbox = await (
    await f.request("/v1/sync", {
      token: d.token,
      body: { revision: 2, tasks: [task] },
    })
  ).json();
  assert.equal(inbox.proposals[0].id, id);
  assert.equal(
    (
      await f.request(`/v1/proposals/${id}/resolve`, {
        token: other.token,
        body: { decision: "accepted" },
      })
    ).status,
    404,
  );
  assert.equal(
    (
      await f.request(`/v1/proposals/${id}/resolve`, {
        token: d.token,
        body: { decision: "accepted" },
      })
    ).status,
    200,
  );
  assert.equal(
    f.store.get("device", d.deviceId).tasks[0].preparation.order,
    null,
    "app is authoritative",
  );
  await f.request("/v1/device", { method: "DELETE", token: d.token });
  assert.equal(f.store.list("proposal").length, 0);
});

test("Data minimization, stale snapshots, stale proposals and evidence validation", async (t) => {
  const f = await fixture(t),
    d = await f.pair();
  assert.equal(
    (
      await f.request("/v1/sync", {
        token: d.token,
        body: { revision: 1, tasks: [{ ...task, notes: "private" }] },
      })
    ).status,
    400,
  );
  await f.request("/v1/sync", {
    token: d.token,
    body: { revision: 2, tasks: [task] },
  });
  assert.equal(
    (
      await f.request("/v1/sync", {
        token: d.token,
        body: { revision: 1, tasks: [] },
      })
    ).status,
    409,
  );
  const tokens = f.auth.issue("test", ["agenda:read", "agenda:propose"]);
  const client = new Client({ name: "test", version: "1" });
  await client.connect(
    new StreamableHTTPClientTransport(new URL(f.config.resource), {
      requestInit: {
        headers: { Authorization: `Bearer ${tokens.access_token}` },
      },
    }),
  );
  t.after(() => client.close());
  const input = {
    deviceId: d.deviceId,
    taskId: task.id,
    basisHash: taskHash(task),
    requestId: randomUUID(),
    field: "support",
    value: false,
    reason: "Rien trouvé",
    evidence: [],
  };
  assert.equal(
    (await client.callTool({ name: "propose_preparation", arguments: input }))
      .isError,
    true,
  );
  assert.equal(
    (
      await client.callTool({
        name: "propose_preparation",
        arguments: {
          ...input,
          value: true,
          evidence: [{ ...evidence, url: "https://evil.invalid" }],
        },
      })
    ).isError,
    true,
  );
  assert.equal(
    (
      await client.callTool({
        name: "propose_preparation",
        arguments: { ...input, value: null },
      })
    ).isError,
    undefined,
  );
  await f.request("/v1/sync", {
    token: d.token,
    body: { revision: 3, tasks: [{ ...task, title: "Formation déplacée" }] },
  });
  assert.equal(
    (
      await client.callTool({
        name: "propose_preparation",
        arguments: {
          ...input,
          value: true,
          evidence: [evidence],
          requestId: randomUUID(),
        },
      })
    ).isError,
    true,
  );
  await f.request("/v1/sync", {
    token: d.token,
    body: { revision: 4, tasks: [] },
  });
  assert.equal(f.store.list("proposal").length, 0, "unshared data purged");
});

test("Read-only OAuth grant cannot create proposals", async (t) => {
  const f = await fixture(t),
    d = await f.pair();
  f.store.sync(d.deviceId, 1, [task]);
  const token = f.auth.issue("reader", ["agenda:read"]).access_token;
  const client = new Client({ name: "reader", version: "1" });
  await client.connect(
    new StreamableHTTPClientTransport(new URL(f.config.resource), {
      requestInit: { headers: { Authorization: `Bearer ${token}` } },
    }),
  );
  t.after(() => client.close());
  const result = await client.callTool({
    name: "propose_preparation",
    arguments: {
      deviceId: d.deviceId,
      taskId: task.id,
      basisHash: taskHash(task),
      requestId: randomUUID(),
      field: "email",
      value: null,
      reason: "À vérifier",
      evidence: [],
    },
  });
  assert.equal(result.isError, true);
  assert.equal(f.store.list("proposal").length, 0);
});
