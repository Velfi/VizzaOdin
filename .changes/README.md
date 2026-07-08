# Changelog Fragments

Add one markdown file per user-visible change in this directory.

Each fragment needs YAML frontmatter with one category:

```md
---
category: added
---
Describe the change in one sentence.
```

Supported categories:

- `added`
- `changed`
- `fixed`
- `removed`

Stable releases compile these fragments into `CHANGELOG.md`. Pre-release tags
use GitHub compare notes and leave fragments in place for the later stable
release.

