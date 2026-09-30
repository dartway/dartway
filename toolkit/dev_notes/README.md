# Findings about this project

One file per finding that **has no address in code** — CI that runs less than it declares, a pin
that trails, a config written twice, a tendency you keep seeing. A finding that belongs to one feature
is a line in its `knownIssues`; one about the framework is an issue in `__NOTES_TRACKER__`. The full
routing is the `dartway-documentation` skill.

`docs/dev_notes/<slug>.md`, committed like any other file (so it travels through review), one per
finding (so parallel branches never conflict), in __PROJECT_LANGUAGE__. **Short**; the issue holds the
status and decides when the file goes (`dartway-documentation`).

```markdown
# <short title>

- **Issue:** owner/repo#123
- **Where:** `path/file.dart:12` — or the area, if it is not one place
- **What is wrong:** one or two sentences
- **What we did about it:** the workaround that is in place, or nothing yet
- **Possible direction:** optional, one line
```

Which features `/dartway-checkup` has read deeply is [`_coverage.md`](_coverage.md).
