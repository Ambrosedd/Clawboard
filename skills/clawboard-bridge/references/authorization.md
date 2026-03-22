# Authorization Boundary

## Principle
Lobster may request approval, but Lobster must not grant its own high-risk approval.

## Approval flow
1. Runtime reaches a sensitive step.
2. Runtime emits approval request.
3. Bridge records pending approval.
4. App shows approval card.
5. Human approves/rejects/narrows scope.
6. Bridge executes a local whitelist action.
7. Runtime receives a temporary capability or continuation signal.

## Acceptable actions
- scoped export access
- scoped upload access
- temporary API token issuance
- fixed restart/read-log style operations from a whitelist

## Unacceptable actions
- arbitrary shell
- arbitrary file read/write
- arbitrary database access
- granting runtime broad machine authority

## Design rule
Approval should create a narrowly-scoped lease/capability, not an unrestricted privilege escalation.
