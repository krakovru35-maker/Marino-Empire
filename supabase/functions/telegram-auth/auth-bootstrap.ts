export class BootstrapError extends Error {
  constructor(
    public readonly publicCode: string,
    public readonly httpStatus = 503,
    public readonly telemetryCode = publicCode,
  ) {
    super(publicCode);
    this.name = "BootstrapError";
  }
}

export class DuplicateIdentityEmailError extends Error {
  constructor() {
    super("duplicate_identity_email");
    this.name = "DuplicateIdentityEmailError";
  }
}

export type MaskedTelemetry = {
  event: string;
  status: number | null;
  code: string;
};

export type IdentityOperations = {
  findLink: () => Promise<string | null>;
  createUser: () => Promise<string>;
  insertLink: (authUserId: string) => Promise<void>;
  deleteUser: (authUserId: string) => Promise<void>;
  sleep: (milliseconds: number) => Promise<void>;
  logMasked: (entry: MaskedTelemetry) => void;
};

export type LeaseOperations = {
  acquire: (leaseToken: string, leaseSeconds: number) => Promise<boolean>;
  release: (leaseToken: string) => Promise<boolean>;
  sleep: (milliseconds: number) => Promise<void>;
  logMasked: (entry: MaskedTelemetry) => void;
};

async function retryFindLink(operations: IdentityOperations) {
  for (const delay of [0, 50, 150, 300]) {
    if (delay) await operations.sleep(delay);
    const existing = await operations.findLink();
    if (existing) return existing;
  }
  return null;
}

async function compensateNewUser(authUserId: string, operations: IdentityOperations) {
  try {
    await operations.deleteUser(authUserId);
  } catch (error) {
    const candidate = error as { status?: number; code?: string };
    operations.logMasked({
      event: "orphan_auth_user_cleanup_failed",
      status: Number.isInteger(candidate?.status) ? candidate.status! : null,
      code: typeof candidate?.code === "string" ? candidate.code : "unknown",
    });
  }
}

export async function ensureIdentity(operations: IdentityOperations) {
  const existing = await operations.findLink();
  if (existing) return { authUserId: existing, createdThisRequest: false };

  let createdAuthUserId: string;
  try {
    createdAuthUserId = await operations.createUser();
  } catch (error) {
    if (error instanceof DuplicateIdentityEmailError) {
      const racedLink = await retryFindLink(operations);
      if (racedLink) return { authUserId: racedLink, createdThisRequest: false };
      operations.logMasked({ event: "identity_conflict", status: 503, code: "duplicate_email_without_link" });
      throw new BootstrapError("identity_creation_failed", 503, "identity_conflict");
    }
    throw new BootstrapError("identity_creation_failed");
  }

  try {
    await operations.insertLink(createdAuthUserId);
    return { authUserId: createdAuthUserId, createdThisRequest: true };
  } catch (_) {
    const racedLink = await retryFindLink(operations);
    if (racedLink === createdAuthUserId) {
      return { authUserId: createdAuthUserId, createdThisRequest: true };
    }
    await compensateNewUser(createdAuthUserId, operations);
    if (racedLink) {
      operations.logMasked({ event: "identity_conflict", status: 503, code: "unique_link_conflict" });
    }
    throw new BootstrapError("identity_creation_failed");
  }
}

export async function withBootstrapLease<T>(
  leaseToken: string,
  operations: LeaseOperations,
  operation: () => Promise<T>,
) {
  let acquired = false;
  for (const delay of [0, 50, 100, 200]) {
    if (delay) await operations.sleep(delay);
    acquired = await operations.acquire(leaseToken, 10);
    if (acquired) break;
  }
  if (!acquired) throw new BootstrapError("identity_bootstrap_busy", 503);

  try {
    return await operation();
  } finally {
    try {
      const released = await operations.release(leaseToken);
      if (!released) operations.logMasked({ event: "bootstrap_lease_release_failed", status: null, code: "not_owner" });
    } catch (error) {
      const candidate = error as { status?: number; code?: string };
      operations.logMasked({
        event: "bootstrap_lease_release_failed",
        status: Number.isInteger(candidate?.status) ? candidate.status! : null,
        code: typeof candidate?.code === "string" ? candidate.code : "unknown",
      });
    }
  }
}

export async function createMagicLinkSession<T>(operations: {
  generateHashedToken: () => Promise<string>;
  verifyHashedToken: (tokenHash: string) => Promise<T>;
}) {
  let tokenHash: string | undefined;
  try {
    tokenHash = await operations.generateHashedToken();
    if (!tokenHash) throw new BootstrapError("session_create_failed");
    return await operations.verifyHashedToken(tokenHash);
  } finally {
    tokenHash = undefined;
  }
}
