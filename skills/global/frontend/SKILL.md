---
name: frontend
description: >-
  Best practices for frontend code in React and Next.js client components:
  named prop types, pure render, derived state instead of synced state, effects
  only for external systems, UI states as discriminated unions, components and
  logic kept at module scope, and accessible markup. Use whenever writing,
  refactoring, or reviewing components, hooks, forms, or client-side data
  fetching (.tsx, .jsx), including "build this page", "add a form", "fix this
  hook", or a review of UI code. Load the typescript skill with it.
---

# frontend

Rules for React UI code. Everything in the `typescript` skill applies here too; load it first. This skill adds what's specific to components.

Check the project first: React version, whether it's Next.js App Router, and which data layer it uses (Server Components, TanStack Query, SWR, tRPC). Use what's there.

React, Next.js, and the data libraries change a lot between majors (Server Components, the React Compiler, `use`, form actions). Follow `<library_check>` from the `typescript` skill: when you aren't highly confident about the installed version's API or recommended pattern, query Context7 before writing.

## Components

- **Props get a named type**: `type InviteCardProps = { ... }` next to the component, exported when a parent builds them. Never `function InviteCard({ invite }: { invite: Invite })`.
- **Render is pure.** Same props and state, same output. No fetches, subscriptions, `Date.now()`, or writes to outside variables during render.
- **Never define a component inside another component.** Every render creates a new type, so React unmounts it and its state resets. Move it to module scope and pass what it needs as props.
- **Logic out of the component body.** Formatting, filtering, validation, mapping API data to view data: pure functions at module scope (or in their own file), called from the component. The component wires state to markup.
- **Small and single-purpose.** When a component handles several states with big blocks of JSX each, split one component per state.
- **Return early for loading, error, and empty**, then render the main case unindented. No nested ternaries in JSX.

## State

- **Derive, don't sync.** If a value can be computed from props or other state, compute it during render. A `useEffect` that sets state from props or from other state is a bug waiting for a stale render.
- **One union for request state**, not `isLoading`, `isError`, and `data` side by side. Render it with an exhaustive `switch` (see `typescript`).
- **Keep state where it's used** and lift it only when a sibling needs it. Reach for context or a store when prop drilling crosses several layers that don't use the value, not before.
- **Server data belongs to the data layer.** Don't copy query results into `useState`.
- `useMemo` and `useCallback` only for a measured cost or a referentially stable value a dependency array or memoized child needs. If the project uses the React Compiler, skip them.

## Effects

- **An effect syncs with something outside React**: a subscription, a DOM API, a timer, a non-React widget. Responding to a user action goes in the event handler.
- **No raw `fetch` in `useEffect`** for data the app needs. Use Server Components, the project's query library, or a server action. When an effect must fetch, handle cancellation with `AbortController`.
- Every effect that subscribes returns a cleanup. Dependency arrays are complete; don't silence `react-hooks/exhaustive-deps`.

## Next.js client and server

- Server Components by default. `"use client"` goes on the smallest leaf that needs state, effects, or browser APIs, not on a page or layout.
- Props crossing into a client component must be serializable; no functions except server actions.
- Never import a server-only module (DB client, secrets) into a client file. Mark those modules with `import "server-only"`.

## Forms

- Validate with the same schema the backend uses, imported from a shared module, and derive the form's types from it.
- Show field errors from the typed error the server returns, not from parsing a message string.
- Disable submit while pending and make the action idempotent on the server anyway.

## Markup and accessibility

- Semantic elements: `button` for actions, `a` for navigation, `label` tied to every input, headings in order. No `div` with `onClick`.
- Lists use a stable key from the data, never the index when items can reorder, insert, or delete.
- Images have `alt` (empty for decorative ones). Interactive elements are reachable and usable by keyboard, with visible focus.
- No comments explaining what markup renders; the JSX already says it.

## Before you finish

<self_review>
On top of the `typescript` checklist:

- props, hook return values, and context values have named types
- no component is declared inside another, and no pure helper lives inside a component body
- no effect copies props or state into state
- request state is a union rendered with an exhaustive switch
- the project's typecheck, lint, and tests pass

Fix what fails before reporting the work as done.
</self_review>
