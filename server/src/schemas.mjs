import { z } from "zod";
const id = z.string().min(1).max(100);
const date = z.string().datetime().nullable();
export const taskSchema = z
  .object({
    id,
    title: z.string().min(1).max(300),
    project: z.string().max(300),
    category: z.enum([
      "work",
      "training",
      "sport",
      "music",
      "personal",
      "rest",
    ]),
    professional: z.boolean(),
    minutes: z.number().int().min(5).max(1440),
    scheduledAt: date,
    deadline: date,
    status: z.enum(["todo", "planned", "inProgress", "completed", "cancelled"]),
    preparation: z
      .object({
        support: z.boolean().nullable(),
        order: z.boolean().nullable(),
        email: z.boolean().nullable(),
      })
      .strict(),
  })
  .strict();
export const snapshotSchema = z
  .object({
    revision: z.number().int().positive().max(Number.MAX_SAFE_INTEGER),
    tasks: z
      .array(taskSchema)
      .max(1000)
      .refine(
        (ts) => new Set(ts.map((t) => t.id)).size === ts.length,
        "Duplicate task ID",
      ),
  })
  .strict();
export const evidenceSchema = z
  .object({
    title: z.string().min(1).max(200),
    // References, not email bodies or attachments. Opening a mail remains in Gmail.
    messageId: z.string().regex(/^[a-zA-Z0-9_-]{1,200}$/),
    date: z.string().datetime(),
    url: z
      .string()
      .url()
      .max(1000)
      .refine((value) => {
        const u = new URL(value);
        return (
          u.protocol === "https:" &&
          u.hostname === "mail.google.com" &&
          !u.username &&
          !u.password &&
          !u.port
        );
      }, "Gmail HTTPS link required"),
  })
  .strict();
export const proposalShape = {
  deviceId: z.string().uuid(),
  taskId: id,
  basisHash: z.string().regex(/^[a-f0-9]{64}$/),
  requestId: z
    .string()
    .uuid()
    .describe("Unique idempotency key. Reuse only for an identical retry."),
  field: z.enum(["support", "order", "email"]),
  value: z.boolean().nullable(),
  reason: z.string().min(1).max(1000),
  evidence: z.array(evidenceSchema).max(5),
};
export const proposalSchema = z
  .object(proposalShape)
  .strict()
  .superRefine((p, ctx) => {
    if (p.value !== null && p.evidence.length === 0)
      ctx.addIssue({
        code: "custom",
        message:
          "A positive or negative conclusion requires evidence. Use null when unknown.",
      });
  });
