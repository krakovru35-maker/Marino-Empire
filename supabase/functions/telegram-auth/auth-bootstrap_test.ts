import {
  BootstrapError,
  DuplicateIdentityEmailError,
  createMagicLinkSession,
  ensureIdentity,
  withBootstrapLease,
} from "./auth-bootstrap.ts";

function assert(condition: unknown, message = "assertion failed"): asserts condition {
  if (!condition) throw new Error(message);
}

function baseIdentity(overrides: Record<string, unknown> = {}) {
  const deleted: string[] = [];
  const logs: unknown[] = [];
  const operations = {
    findLink: async () => null as string | null,
    createUser: async () => "new-user",
    insertLink: async (_id: string) => {},
    deleteUser: async (id: string) => { deleted.push(id); },
    sleep: async (_ms: number) => {},
    logMasked: (entry: unknown) => { logs.push(entry); },
    ...overrides,
  };
  return { operations, deleted, logs };
}

Deno.test("new user is compensated when identity insert fails", async () => {
  const fixture = baseIdentity({ insertLink: async () => { throw new Error("insert failed"); } });
  try {
    await ensureIdentity(fixture.operations);
    throw new Error("expected failure");
  } catch (error) {
    assert(error instanceof BootstrapError);
    assert(fixture.deleted.length === 1 && fixture.deleted[0] === "new-user");
  }
});

Deno.test("cleanup failure emits masked telemetry without user data", async () => {
  const fixture = baseIdentity({
    insertLink: async () => { throw new Error("insert failed"); },
    deleteUser: async () => { throw { status: 503, code: "cleanup_failed", authUserId: "must-not-log" }; },
  });
  try {
    await ensureIdentity(fixture.operations);
    throw new Error("expected failure");
  } catch (error) {
    assert(error instanceof BootstrapError);
    const serialized = JSON.stringify(fixture.logs);
    assert(serialized.includes("orphan_auth_user_cleanup_failed"));
    assert(!serialized.includes("must-not-log"));
  }
});

Deno.test("pre-existing user is never deleted", async () => {
  const fixture = baseIdentity({ findLink: async () => "existing-user" });
  const result = await ensureIdentity(fixture.operations);
  assert(result.authUserId === "existing-user");
  assert(fixture.deleted.length === 0);
});

Deno.test("duplicate email without identity link fails closed", async () => {
  const fixture = baseIdentity({ createUser: async () => { throw new DuplicateIdentityEmailError(); } });
  try {
    await ensureIdentity(fixture.operations);
    throw new Error("expected failure");
  } catch (error) {
    assert(error instanceof BootstrapError && error.telemetryCode === "identity_conflict");
    assert(fixture.deleted.length === 0);
    assert(JSON.stringify(fixture.logs).includes("duplicate_email_without_link"));
  }
});

Deno.test("lease is always released and release failure is masked", async () => {
  const logs: unknown[] = [];
  const result = await withBootstrapLease("lease-token", {
    acquire: async () => true,
    release: async () => { throw { status: 503, code: "release_failed", sensitive: "not logged" }; },
    sleep: async () => {},
    logMasked: (entry) => logs.push(entry),
  }, async () => "ok");
  assert(result === "ok");
  assert(JSON.stringify(logs).includes("bootstrap_lease_release_failed"));
  assert(!JSON.stringify(logs).includes("sensitive"));
});

Deno.test("concurrent first bootstrap allows only one active lease owner", async () => {
  let owner: string | null = null;
  let operationsRun = 0;
  const createLeaseOps = () => ({
    acquire: async (token: string) => {
      if (owner === null || owner === token) { owner = token; return true; }
      return false;
    },
    release: async (token: string) => {
      if (owner !== token) return false;
      owner = null;
      return true;
    },
    sleep: async () => {},
    logMasked: () => {},
  });

  let unblockFirst!: () => void;
  const firstBlocked = new Promise<void>((resolve) => { unblockFirst = resolve; });
  const first = withBootstrapLease("first-token", createLeaseOps(), async () => {
    operationsRun += 1;
    await firstBlocked;
    return "first";
  });
  await Promise.resolve();
  const second = withBootstrapLease("second-token", createLeaseOps(), async () => {
    operationsRun += 1;
    return "second";
  });
  try {
    await second;
    throw new Error("second lease should not be acquired");
  } catch (error) {
    assert(error instanceof BootstrapError && error.publicCode === "identity_bootstrap_busy");
  }
  unblockFirst();
  assert(await first === "first");
  assert(operationsRun === 1);
});

Deno.test("magic link contract passes token_hash only to verifier", async () => {
  let verified = "";
  const session = await createMagicLinkSession({
    generateHashedToken: async () => "synthetic-hash-not-a-secret",
    verifyHashedToken: async (tokenHash) => { verified = tokenHash; return { access_token: "synthetic" }; },
  });
  assert(verified === "synthetic-hash-not-a-secret");
  assert(session.access_token === "synthetic");
});
