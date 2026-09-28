import { DatabaseSync } from "node:sqlite";
import { mkdirSync, chmodSync } from "node:fs";
import { dirname } from "node:path";
import {
  createHash,
  randomBytes,
  randomUUID,
  scryptSync,
  timingSafeEqual,
} from "node:crypto";

export const randomToken = () => randomBytes(32).toString("base64url");
export const digest = (value) =>
  createHash("sha256").update(value).digest("hex");
export function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object")
    return `{${Object.keys(value)
      .sort()
      .map((k) => `${JSON.stringify(k)}:${canonical(value[k])}`)
      .join(",")}}`;
  return JSON.stringify(value);
}
export const taskHash = (task) => digest(canonical(task));
export function passwordHash(password) {
  const salt = randomBytes(16).toString("hex");
  return `${salt}:${scryptSync(password, salt, 64).toString("hex")}`;
}
export function verifyPassword(password, encoded) {
  const [salt, key] = encoded.split(":");
  const expected = Buffer.from(key, "hex");
  return (
    expected.length === 64 &&
    timingSafeEqual(scryptSync(password, salt, 64), expected)
  );
}
export class Store {
  constructor(path) {
    if (path !== ":memory:")
      mkdirSync(dirname(path), { recursive: true, mode: 0o700 });
    this.db = new DatabaseSync(path);
    if (path !== ":memory:") chmodSync(path, 0o600);
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;
      CREATE TABLE IF NOT EXISTS records (kind TEXT NOT NULL, id TEXT NOT NULL, data TEXT NOT NULL, expires INTEGER, PRIMARY KEY(kind,id));`);
  }
  get(kind, id) {
    const row = this.db
      .prepare("SELECT data,expires FROM records WHERE kind=? AND id=?")
      .get(kind, id);
    return row && (!row.expires || row.expires > Date.now())
      ? JSON.parse(row.data)
      : undefined;
  }
  put(kind, id, data, expires = null) {
    this.db
      .prepare(
        "INSERT INTO records VALUES(?,?,?,?) ON CONFLICT(kind,id) DO UPDATE SET data=excluded.data, expires=excluded.expires",
      )
      .run(kind, id, JSON.stringify(data), expires);
    return data;
  }
  delete(kind, id) {
    this.db.prepare("DELETE FROM records WHERE kind=? AND id=?").run(kind, id);
  }
  list(kind) {
    return this.db
      .prepare(
        "SELECT id,data FROM records WHERE kind=? AND (expires IS NULL OR expires>?)",
      )
      .all(kind, Date.now())
      .map((r) => ({ id: r.id, ...JSON.parse(r.data) }));
  }
  transaction(fn) {
    this.db.exec("BEGIN IMMEDIATE");
    try {
      const value = fn();
      this.db.exec("COMMIT");
      return value;
    } catch (e) {
      this.db.exec("ROLLBACK");
      throw e;
    }
  }
  prune() {
    this.db
      .prepare("DELETE FROM records WHERE expires IS NOT NULL AND expires<=?")
      .run(Date.now());
  }
  pairingCode() {
    const code = randomBytes(10).toString("hex");
    this.put("pair", digest(code), {}, Date.now() + 10 * 60_000);
    return code;
  }
  pair(code, name) {
    return this.transaction(() => {
      const key = digest(code.replace(/[\s-]/g, "").toLowerCase());
      if (!this.get("pair", key))
        throw new ApiError(401, "Code invalide ou expiré.");
      this.delete("pair", key);
      const deviceId = randomUUID(),
        token = randomToken();
      this.put("device", deviceId, {
        name,
        tokenHash: digest(token),
        revision: 0,
        tasks: [],
        updatedAt: null,
      });
      return { deviceId, token };
    });
  }
  deviceForToken(token) {
    return this.list("device").find((d) => d.tokenHash === digest(token));
  }
  removeDevice(id) {
    this.delete("device", id);
    for (const p of this.list("proposal").filter((p) => p.deviceId === id))
      this.delete("proposal", p.id);
  }
  sync(deviceId, revision, tasks) {
    return this.transaction(() => {
      const device = this.get("device", deviceId);
      if (!device) throw new ApiError(401, "Appareil révoqué.");
      if (revision <= device.revision)
        throw new ApiError(409, "Synchronisation ancienne. Réessayez.");
      this.put("device", deviceId, {
        ...device,
        tasks,
        revision,
        updatedAt: new Date().toISOString(),
      });
      for (const p of this.list("proposal").filter(
        (p) => p.deviceId === deviceId,
      )) {
        if (!tasks.some((t) => t.id === p.taskId))
          this.delete("proposal", p.id);
      }
      return {
        revision,
        proposals: this.list("proposal").filter(
          (p) => p.deviceId === deviceId && p.status === "pending",
        ),
        syncedAt: new Date().toISOString(),
      };
    });
  }
  propose(input) {
    return this.transaction(() => {
      const task = this.get("device", input.deviceId)?.tasks.find(
        (t) => t.id === input.taskId,
      );
      if (!task || task.category !== "training")
        throw new ApiError(404, "Formation partagée introuvable.");
      if (taskHash(task) !== input.basisHash)
        throw new ApiError(
          409,
          "La formation a changé. Relisez-la avant de proposer.",
        );
      const previous = this.list("proposal").find(
        (p) => p.deviceId === input.deviceId && p.requestId === input.requestId,
      );
      if (previous) {
        const old = Object.fromEntries(
          Object.keys(input).map((k) => [k, previous[k]]),
        );
        if (canonical(old) !== canonical(input))
          throw new ApiError(409, "Identifiant de demande déjà utilisé.");
        return previous;
      }
      if (
        this.list("proposal").filter(
          (p) => p.deviceId === input.deviceId && p.status === "pending",
        ).length >= 200
      )
        throw new ApiError(409, "Validez les propositions en attente.");
      const id = randomUUID();
      const proposal = {
        id,
        ...input,
        basis: task,
        status: "pending",
        createdAt: new Date().toISOString(),
      };
      this.put("proposal", id, proposal, Date.now() + 30 * 86400_000);
      return proposal;
    });
  }
  resolve(deviceId, id, decision) {
    const p = this.get("proposal", id);
    if (!p || p.deviceId !== deviceId)
      throw new ApiError(404, "Proposition introuvable.");
    if (p.status !== "pending" && p.status !== decision)
      throw new ApiError(409, "Proposition déjà traitée.");
    this.put(
      "proposal",
      id,
      { ...p, status: decision },
      Date.now() + 30 * 86400_000,
    );
    return { status: decision };
  }
  close() {
    this.db.close();
  }
}
export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}
