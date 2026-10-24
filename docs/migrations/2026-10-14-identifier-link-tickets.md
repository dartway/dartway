---
title: Apply the identifier confirmation ticket migration
affects:
  dartway_core_server: "0.22.0"
---

## Who is affected

Every server upgrading to this version, including servers that continue using code confirmation.

## What to do

Apply framework migration `20261014_000000_dw_identifier_links` before serving traffic. It extends
`dw_code_ticket` with delivery, a link hash and request-bound replace intent; `code_hash` becomes
nullable with a constraint requiring exactly the hash of the selected delivery. Existing code
requests and rate-limit history remain intact. The server's normal migration startup applies it.

Rollback deletes link tickets before restoring the old non-null code hash, leaving code tickets,
accounts and identities intact. Already confirmed identifier changes are not undone by rollback.

Link delivery is optional adoption, not a required application wiring change. Read
[the link confirmation contract](../4-server/auth-identity.md#confirming-an-identifier-by-link)
when adopting it. Verify migration on a populated database and both code and link flows.
