import { z } from "zod";

// --- Seller (dashboard) auth ------------------------------------------------

export const registerSellerSchema = z.object({
  username: z
    .string()
    .trim()
    .min(3, "Username must be at least 3 characters")
    .max(32)
    .regex(/^[a-zA-Z0-9_.-]+$/, "Only letters, numbers, _ . - are allowed"),
  email: z.string().trim().email("Enter a valid email").max(254),
  password: z.string().min(8, "Password must be at least 8 characters").max(200),
});

export const loginSellerSchema = z.object({
  username: z.string().trim().min(1, "Username is required"),
  password: z.string().min(1, "Password is required"),
});

// --- Applications -----------------------------------------------------------

export const createAppSchema = z.object({
  name: z.string().trim().min(2, "Name must be at least 2 characters").max(60),
  version: z.string().trim().max(20).optional().default("1.0"),
});

export const updateAppSchema = z.object({
  name: z.string().trim().min(2).max(60).optional(),
  version: z.string().trim().max(20).optional(),
  status: z.enum(["active", "paused"]).optional(),
  hwid_lock: z.boolean().optional(),
  download_url: z.string().trim().url("Must be a valid URL").max(500).nullable().optional(),
});

// --- License keys -----------------------------------------------------------

export const createKeysSchema = z.object({
  app_id: z.string().min(1),
  amount: z.number().int().min(1).max(1000).default(1),
  duration_days: z.number().int().min(0).max(36500).default(30),
  level: z.number().int().min(1).max(100).default(1),
  max_uses: z.number().int().min(1).max(100000).default(1),
  mask: z.string().max(64).optional(),
  prefix: z.string().max(16).optional(),
  note: z.string().max(200).optional(),
});

// --- Users (managed from the dashboard) -------------------------------------

export const updateUserSchema = z.object({
  banned: z.boolean().optional(),
  ban_reason: z.string().max(200).nullable().optional(),
  level: z.number().int().min(1).max(100).optional(),
  expires_at: z.number().int().nullable().optional(),
  reset_hwid: z.boolean().optional(),
});

// --- Blacklist / variables --------------------------------------------------

export const createBlacklistSchema = z.object({
  app_id: z.string().min(1),
  type: z.enum(["ip", "hwid"]),
  value: z.string().trim().min(1).max(200),
  reason: z.string().max(200).optional(),
});

export const createVariableSchema = z.object({
  app_id: z.string().min(1),
  name: z.string().trim().min(1).max(60),
  value: z.string().max(2000),
  secret: z.boolean().default(false),
});

// --- Client authentication API (/api/v1/*) ----------------------------------

export const appIdentitySchema = z.object({
  app_id: z.string().min(1, "app_id is required"),
  secret: z.string().min(1, "secret is required"),
  version: z.string().optional(),
});

export const clientInitSchema = appIdentitySchema;

export const clientRegisterSchema = appIdentitySchema.extend({
  username: z.string().trim().min(1).max(64),
  password: z.string().min(1).max(200),
  key: z.string().trim().min(1),
  email: z.string().email().optional(),
  hwid: z.string().max(256).optional(),
});

export const clientLoginSchema = appIdentitySchema.extend({
  username: z.string().trim().min(1).max(64),
  password: z.string().min(1).max(200),
  hwid: z.string().max(256).optional(),
});

export const clientLicenseSchema = appIdentitySchema.extend({
  key: z.string().trim().min(1),
  hwid: z.string().max(256).optional(),
});

export const clientVerifySchema = appIdentitySchema.extend({
  token: z.string().min(1),
  hwid: z.string().max(256).optional(),
});

export const clientUpgradeSchema = appIdentitySchema.extend({
  username: z.string().trim().min(1).max(64),
  key: z.string().trim().min(1),
});

export const clientLogSchema = appIdentitySchema.extend({
  token: z.string().optional(),
  message: z.string().max(2000),
  username: z.string().max(64).optional(),
});

export const clientVarSchema = appIdentitySchema.extend({
  name: z.string().trim().min(1).max(60),
  token: z.string().optional(),
});
