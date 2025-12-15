---
description: Crucial things for project architecture
alwaysApply: true
---

# DartWay Specials

## UserProfile and UserInfo Logic

Very important: we don't use serverpod_user_info and UserInfo - it's Serverpod model which we cannot extend directly.
We use UserProfile - additional model for carrying out all user related things.

In order to avoid mess we always add Profile word in relation fields and variables.

Examples:
- `userProfileId` - for the main user relation
- `authorProfileId` - for the author of content
- `updatedByProfileId` - for who last updated the record