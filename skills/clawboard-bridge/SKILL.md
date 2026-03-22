---
name: clawboard-bridge
description: "Install, design, or improve the Clawboard bridge skill that runs inside a Lobster environment and exposes mobile pairing, state sync, approvals, controlled commands, and local authorization boundaries for the Clawboard iPhone app. Use when building or refining a Lobster skill or sidecar that should (1) start a local bridge service, (2) generate pair codes or QR payloads, (3) exchange pair codes for app tokens, (4) expose lobster/task/approval/alert status to the app, or (5) execute only tightly-scoped approved actions instead of arbitrary remote control."
---

# Clawboard Bridge

Implement the bridge as a **skill-hosted local service**, not as a user-facing standalone product.

## Core workflow

1. Confirm whether the task is about:
   - skill structure
   - sidecar lifecycle
   - pairing protocol
   - app-facing API shape
   - approval and authorization boundaries
2. Read the relevant reference file(s) from `references/`.
3. Preserve the product rule:
   - users should feel they are installing a Lobster skill and pairing in the app
   - users should not need to understand Connector / sidecar internals
4. Keep the bridge boundary narrow:
   - allow structured status reads
   - allow structured pause/resume/terminate/retry
   - allow approval resolution and scoped temporary capabilities
   - do **not** create arbitrary shell, arbitrary file read/write, or generic remote admin channels
5. Prefer additive changes that keep the API shape stable for the iOS app.

## Required architecture rules

- Treat the bridge as a **local control plane** beside Lobster runtime.
- Keep task execution logic separate from pairing/auth/session logic.
- Let Lobster request approval, but never let Lobster approve its own high-risk request.
- Execute approved actions through a whitelist/capability model.
- Keep high-risk credentials on the local machine, not in the mobile app.

## Deliverables to produce when implementing this skill

When asked to create or improve the bridge skill, aim to produce some or all of:

- a `SKILL.md` that explains how the bridge should behave
- reference docs for pairing, approvals, authorization, and lifecycle
- a sidecar launch pattern
- example API payloads for `/pair/session`, `/pair/exchange`, `/lobsters`, `/tasks`, `/approvals`, `/alerts`
- a narrow command model for pause/resume/terminate/retry and approval resolution

## Resource map

- Pairing and trust bootstrap: read `references/pairing.md`
- Approval and authorization boundary: read `references/authorization.md`
- Skill/sidecar responsibilities and lifecycle: read `references/lifecycle.md`

## Implementation guidance

### Pairing

Implement pairing with:
- short-lived pair code or QR payload
- app exchange to long-lived bearer token
- explicit expiry and re-issue behavior

### State sync

Expose stable app-facing models for:
- lobsters
- tasks
- approvals
- alerts
- node/device info

Normalize runtime-specific details before returning them.

### Authorization

Treat approval as:
- request
- human decision in app
- local bridge execution of a limited action
- temporary capability or result handoff back to runtime

Do not equate approval with general machine access.

### Lifecycle

Prefer:
- skill as install/config entrypoint
- sidecar/background service as runtime carrier for pairing/session/cache

If embedding everything in one process, explicitly justify why isolation is unnecessary.
