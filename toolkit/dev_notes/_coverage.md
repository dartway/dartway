# Deep-pass coverage

Which features `/dartway-checkup` has read properly, and when. The command chooses what to read next
from this table — never-visited first, then the ones that changed most since their pass — so a
project gets covered feature by feature instead of skimmed all at once every time.

Delete a row when the feature is gone. Keep it when the feature is refactored: what matters is when
somebody last looked at it closely.

This file is the project's own record and the installer never overwrites it. The findings themselves
are one file each beside it; the form is in [`README.md`](README.md).

| Feature | Last deep pass | Findings then | Still open |
|---|---|---|---|
| <!-- app/issues/board --> | <!-- 2026-08-08 --> | <!-- 3 --> | <!-- 1 --> |
