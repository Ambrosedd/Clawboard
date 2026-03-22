# Lifecycle

## Recommended split
- Skill = install/config entrypoint
- Sidecar = long-running bridge runtime
- Lobster runtime = task execution engine

## Why
The bridge usually needs:
- long-lived sessions
- reconnect behavior
- local cache
- approval waiting state
- token handling
- controlled command dispatch

These concerns are usually cleaner in a sidecar than in ordinary task execution logic.

## Operational expectations
The skill should be able to:
- start the sidecar
- stop/restart the sidecar
- surface pairing info
- report basic health
- expose where logs/status can be inspected

## Failure handling
If the sidecar dies:
- runtime tasks should not automatically become root-admin capable
- pair tokens should not silently escalate access
- restart should be explicit or governed by a narrow supervisor rule
