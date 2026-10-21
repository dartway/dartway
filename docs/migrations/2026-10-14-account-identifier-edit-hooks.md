---
title: Handle trusted identifier edits in exhaustive change-cause switches
affects:
  dartway_core_server: "0.22.0"
---

## Who is affected

Projects with exhaustive switches over `DwIdentifierChangeCause`.

## What to change

Handle `DwIdentifierChangeCause.updated` in identifier hooks: trusted backend edits have no code
proof, and all batch identity writes finish before the first hook.

The new optional `DwAccountService.updateIdentifiers` capability requires no other project change,
no schema migration and no wire protocol bump. To adopt it for combined profile edits, write the
profile inside its `beforeChange` callback, never lock the project profile first. Removing the final
login method is the existing `dw.invalid` refusal on the composite `identifiers` field. See
[trusted administrative identifier edits](../4-server/auth-identity.md#trusted-administrative-identifier-edits).

## How to check

The server package analyzes with exhaustive switches complete. If adopting the API, test an
occupied second identifier and a throwing hook: neither identifiers nor callback profile writes
persist, and no partial live profile reaches subscribers.
