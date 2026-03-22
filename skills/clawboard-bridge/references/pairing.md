# Pairing

## Goal
Establish first trust between Clawboard iPhone app and the local bridge service running inside a Lobster environment.

## Expected user flow
1. Install and enable Clawboard skill.
2. Skill starts bridge sidecar.
3. Sidecar shows pair code or QR payload.
4. App exchanges pair code for bearer token.
5. App stores token and starts reading bridge state.

## Minimum protocol
- `GET /pair/session`
- `POST /pair/exchange`

## Rules
- Pair code must be short-lived.
- Pair code must not be reused after expiry.
- Exchanged token must represent app access to bridge APIs only.
- Pairing should return node identity so the app can label the connection.

## Product framing
Describe this to users as:
- install skill
- pair node
- connect to your lobster

Avoid leading with:
- connector
- middleware
- sidecar
