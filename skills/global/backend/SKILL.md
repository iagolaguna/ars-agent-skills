---
name: backend
description: >-
  Best practices for server code in Node.js and Next.js (route handlers,
  server actions, Server Component data access, workers, CLIs): validate input
  at the edge with a schema, keep domain logic pure with dependencies passed
  in, return typed errors and map them to HTTP in one place, parse env once,
  log structured events at the edge, and handle async safely. Use whenever
  writing, refactoring, or reviewing API routes, server actions, services,
  database access, jobs, or webhooks, including "add an endpoint", "create a
  server action", "fix this handler", or a review of backend code. Load the
  typescript skill with it.
---

# backend

Rules for server-side TypeScript in Node.js and Next.js. Everything in the `typescript` skill applies here too; load it first.

Check the project first: Node version, ESM or CommonJS, Next.js version and router, the validation library (zod, valibot), the DB layer (Prisma, Drizzle, raw SQL), and the logger. Use what's there.

Next.js caching and request APIs, ORMs, and validation libraries all change between majors. Follow `<library_check>` from the `typescript` skill: when you aren't highly confident about the installed version's API or recommended pattern, query Context7 before writing.

## Shape of a request

Every entry point (route handler, server action, queue consumer, cron, CLI command) does the same three things and nothing else:

1. **Parse** the input with a schema. Anything not parsed is `unknown`.
2. **Call** a domain function with typed input and its dependencies.
3. **Map** the result to the response: success to data, each error `kind` to a status, through one exhaustive function.

<example>

```ts
export async function POST(request: Request): Promise<Response> {
  const parsed = acceptInviteSchema.safeParse(await request.json())
  if (!parsed.success) return Response.json({ error: "invalid_input", issues: parsed.error.issues }, { status: 400 })

  const result = await acceptInvite(parsed.data, { db, now: new Date() })
  if (!result.ok) return Response.json({ error: result.error.kind }, { status: inviteErrorStatus(result.error) })

  return Response.json(result.value)
}
```

</example>

Business rules don't live in the handler, and the domain function doesn't know about `Request`, `Response`, cookies, or status codes.

## Domain code

- **Dependencies come in as parameters** (`{ db, now, mailer }`), typed by a named `Deps` type. No importing a DB client or reading `process.env` deep inside logic. That's what makes it testable without mocks of modules.
- **Split pure decisions from I/O.** Load what you need, hand it to a pure function that decides, then write the outcome. The pure part is where the rules and the tests are.
- **Expected failures are typed results** (`Result<T, InviteError>`), not exceptions. Throw only for bugs and infrastructure failures, and let them reach the edge as a 500.
- **Multiple writes that must agree run in one transaction.** Avoid N+1 queries: load related rows in one query or a batched one.
- Queries are parameterized. Never build SQL from strings.

## Input, output, and config

- **One schema per input**, and the type comes from it (`z.infer`). Share the schema with the frontend when the form sends the same shape.
- **Shape the output deliberately.** Map DB rows to a named response type; don't return the ORM entity, which leaks columns and couples the API to the table.
- **Parse env once at startup** into a typed, frozen `config` module that fails fast on a missing value. The rest of the code imports `config`, never `process.env`.
- Error responses carry a stable `kind` code the client can switch on. Never send a stack trace, SQL error, or internal message.

## Errors at the edge

- One function per error union maps `kind` to status, with a `never` check, so a new error kind can't ship without a status.
- Unexpected throws are caught once, at the top of the entry point or by the framework's error boundary, logged with their `cause`, and answered with a generic 500.
- In Next.js, `redirect()`, `notFound()`, and friends work by throwing. Don't call them inside a `try` whose `catch` would swallow them.

## Logging

- Structured, with a stable event name and fields: `logger.info("invite.accepted", { inviteId, durationMs })`. No string concatenation.
- Log at the edge, once per outcome. Not a log line in every layer for the same event.
- Call the logger directly. A helper whose only job is to call `logger.info` with the same fields is noise (see `typescript`).
- Never log secrets, tokens, passwords, or full request bodies with personal data.

## Async

- No floating promises: every promise is awaited, returned, or explicitly handed to something that handles its rejection.
- Independent work runs together with `Promise.all`, or `Promise.allSettled` when one failure shouldn't cancel the rest. No `await` inside a loop when the iterations don't depend on each other.
- Every outbound call has a timeout (`AbortSignal.timeout(ms)`) and, where it's safe to repeat, a bounded retry.
- No synchronous filesystem or CPU-heavy work in the request path.

## Next.js server code

- **Server actions are public HTTP endpoints.** Each one authenticates, authorizes, and validates its input with a schema, exactly like a route handler. Being imported only from your own form protects nothing.
- Modules that hold secrets or DB access start with `import "server-only"`.
- Server Components call the domain function directly. Don't `fetch` your own route handlers from the server.
- Check auth in the handler or action that touches the data, not only in middleware.

## Node.js

- `node:` prefix for built-ins (`node:fs/promises`, `node:crypto`).
- Match the project's module system; in ESM, relative imports carry their extension when the project's resolution needs it.
- Long-running processes handle `SIGTERM`: stop taking work, finish in-flight requests, close pools.

## Before you finish

<self_review>
On top of the `typescript` checklist:

- every entry point parses its input with a schema before using it
- domain functions take dependencies as parameters and return typed results
- error kinds map to statuses through one exhaustive function
- no `process.env` outside the config module
- no floating promises, every outbound call has a timeout
- each outcome is logged once, at the edge, without secrets
- the project's typecheck, lint, and tests pass

Fix what fails before reporting the work as done.
</self_review>
