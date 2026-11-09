---
name: typescript
description: >-
  Code style for TypeScript and JavaScript: named, traceable types instead of
  inline ones, pure functions, guard clauses, exhaustive pattern matching over
  discriminated unions, typed errors, few comments, and no functions that only
  wrap one call. Use whenever writing, refactoring, or reviewing .ts, .tsx, .js,
  .jsx, .mjs, or .cjs code, on the frontend or the backend, even when the user
  doesn't ask for style ("add an endpoint", "fix this component", "review this
  PR", "refatora esse arquivo").
---

# typescript

Rules for TS and JS that an agent tends to break. They hold on both sides of the stack. The `frontend` and `backend` skills build on this one.

Before writing, read the project's `tsconfig.json`, lint config, and two or three files next to the one you're changing. Formatting and naming follow the project. These rules win over habit, not over a decision the project already made: if it uses `neverthrow`, `Effect`, or `ts-pattern`, use those instead of rolling your own.

In a plain JS project the same rules apply through JSDoc: `// @ts-check`, `@typedef` for named types, `@param` and `@returns` on exports.

## Libraries you don't know well

Training data lags behind libraries, and an API that looks right can be removed, renamed, or discouraged in the version the project has installed.

<library_check>
Before writing code against a library, ask yourself two things: do I know this library's current API for the installed version, and do I know how its maintainers recommend using it? If either answer is "not with high confidence", check before writing:

1. Read the installed version from `package.json` and the lockfile.
2. Look it up with Context7: `resolve-library-id` for the library, then `query-docs` with the version and the specific thing you're doing ("server actions error handling", "zod discriminated union", "TanStack Query mutations").
3. Follow the docs over memory when they disagree, and say so to the user if the project's existing code uses a pattern the docs now discourage.

If Context7 isn't available, read the package's own types and README in `node_modules`.
</library_check>

This applies to frameworks too (Next.js, React, Prisma, Drizzle), and especially across major versions. It doesn't apply to the language itself or to code that doesn't touch a library.

## Types you can trace

A reader should be able to jump from any value to the one place its shape is defined.

- **Name every type that crosses a function boundary.** No object types inline in parameters, return types, generics, or `useState<...>`. Give it a name next to the code that owns it and export it when another module uses it.

  <example>
  <avoid>

  ```ts
  function createInvite(input: { email: string; role: "admin" | "member" }): Promise<{ id: string }>
  ```

  </avoid>
  <prefer>

  ```ts
  type InviteRole = "admin" | "member"
  type CreateInviteInput = { email: string; role: InviteRole }
  type Invite = { id: string }
  function createInvite(input: CreateInviteInput): Promise<Invite>
  ```

  </prefer>
  </example>

- **Derive, don't redeclare.** When a schema, a constant, or a function already defines the shape, get the type from it: `z.infer<typeof schema>`, `(typeof ROLES)[number]`, `Awaited<ReturnType<typeof getUser>>`, `Pick`, `Omit`. Two hand-written copies of one shape drift apart.
- **Annotate the return type of exported functions.** It's the contract and it stops a change in the body from silently changing callers. Let locals infer.
- **Model states as discriminated unions**, not as bags of optional fields and booleans. `{ status: "loading" } | { status: "ready"; data: Invite[] } | { status: "failed"; error: LoadError }` can't be loading and failed at once; `{ isLoading?: boolean; data?: Invite[]; error?: string }` can.
- **`unknown` at boundaries, never `any`.** Anything from the network, storage, env, or `JSON.parse` is `unknown` until a schema or a type guard narrows it.
- **`as` is not a fix.** Use it only when you know something the compiler can't, and never to make an error go away. `satisfies` checks a literal without widening it. `@ts-expect-error` with a reason over `@ts-ignore`.
- **`import type`** for imports used only as types.

## Functions

- **Pure by default.** Output depends only on the arguments; no mutating them, no reading module state, `Date.now()`, `Math.random()`, or env inside domain logic. Pass the clock, ids, and dependencies in. Keep I/O (DB, fetch, logger, filesystem) at the edges and call pure functions from there.
- **Don't mutate what you didn't create.** Return a new object or array (`{ ...user, name }`, `toSorted`, `map`) instead of changing the argument.
- **Validate first, return early.** Check the failure cases at the top and leave the happy path unindented at the end. No `else` after a `return` or `throw`.

  <example>

  ```ts
  function acceptInvite(invite: Invite, now: Date): AcceptResult {
    if (invite.revokedAt) return { ok: false, error: { kind: "revoked" } }
    if (invite.expiresAt < now) return { ok: false, error: { kind: "expired" } }

    return { ok: true, value: { ...invite, acceptedAt: now } }
  }
  ```

  </example>

- **No functions declared inside functions without a reason.** A helper that doesn't close over local state goes to module scope, where it can be tested and reused. Inline callbacks (`items.map((item) => ...)`) are fine.
- **Don't wrap a single call.** A function earns its name when it hides several steps, is called from more than one place with the same shape, or names a domain idea the call doesn't already say. One call passed through with the same arguments is just indirection; inline it.

  <example>
  <avoid reason="a name for one logger call, used once">

  ```ts
  function logAccepted(outcome: SignupOutcome, locale: WaitlistLocale, startedAt: number) {
    logger.info("waitlist.signup_accepted", { outcome, locale, durationMs: elapsedMs(startedAt) })
  }
  logAccepted(outcome, locale, startedAt)
  ```

  </avoid>
  <prefer>

  ```ts
  logger.info("waitlist.signup_accepted", { outcome, locale, durationMs: elapsedMs(startedAt) })
  ```

  </prefer>
  </example>

  When you're about to extract a function, ask: does it hide more than one step, is it called from two places, or does its name say something the call doesn't? If every answer is no, don't extract.

- **Expressions over mutation.** `const` with `map`, `filter`, `reduce`, or a ternary beats a `let` that gets reassigned across branches. A plain `for...of` is fine when it reads better or needs an early `break`.
- **Few parameters.** Past two or three, or when two have the same type, take one named object type.

## Pattern matching

Branch on the shape of the data, and let the compiler tell you when a case is missing.

- **`switch` on the discriminant with an exhaustive `never` check**, so adding a variant breaks the build until every switch handles it.

  <example>

  ```ts
  function inviteErrorStatus(error: InviteError): number {
    switch (error.kind) {
      case "not_found": return 404
      case "revoked":
      case "expired": return 410
      case "already_member": return 409
      default: {
        const unhandled: never = error
        return unhandled
      }
    }
  }
  ```

  </example>

- **A lookup table over an `if`/`else if` chain** when every branch maps a key to a value: `const LABELS: Record<InviteRole, string> = { ... }`. `Record` over a union key is exhaustive too.
- Use `ts-pattern` (`match(x).with(...).exhaustive()`) when the project has it, for nested shapes a `switch` can't reach.
- No nested ternaries. Two levels in means it's a `switch` or a table.

## Errors

- **Expected failures are values, in the return type.** Not found, invalid input, conflict, expired: the caller has to handle them, so the signature says so. Use a result union with a typed error:

  ```ts
  type Result<T, E> = { ok: true; value: T } | { ok: false; error: E }
  type InviteError = { kind: "not_found" } | { kind: "revoked" } | { kind: "expired" } | { kind: "already_member"; userId: string }
  ```

  Define `Result` once per project and import it; don't redeclare it per module.
- **Throw for bugs and broken infrastructure**, the things no caller can recover from. Throw `Error` subclasses with a `readonly kind`, never strings or plain objects, and pass the original as `{ cause }` when rethrowing.
- **`catch` gives `unknown`.** Narrow it before reading `.message`.
- **Handle an error once.** Don't catch to log and rethrow at every layer, and never swallow with an empty `catch` or a `catch` that returns `null`.

## Comments

Code says what; a comment is for why, and most code doesn't need one.

- Write a comment only for something the code can't show: a non-obvious constraint, a workaround with a link to the issue, an invariant a future edit could break.
- Never: comments that restate the next line, `// Step 1` or section banners, JSDoc that repeats the signature, commented-out code, notes to the reviewer about what you changed.
- When you feel a comment is needed to explain what a block does, give the block a better name or extract it into a named function instead.
- Doc comments on exported APIs only when they add what the types don't: units, side effects, what an error means.

## Before you finish

<self_review>
Read back what you wrote and check:

- library calls you weren't sure about were checked against the installed version's docs
- every object type in a signature has a name, and none is a hand copy of a schema or another type
- no `any`, no `as` used to silence an error
- every switch over a union ends with a `never` check
- expected failures are in return types, not thrown
- no helper exists just to wrap one call, and no helper is declared inside another function without closing over its state
- each comment explains a why the code can't
- the project's typecheck and lint pass

Fix what fails before reporting the work as done.
</self_review>
