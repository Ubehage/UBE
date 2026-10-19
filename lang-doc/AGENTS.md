# UBE language-definition instructions

This folder contains normative and internal language-definition material.
`README.md` is a reader-facing map; agent rules live here.

- Treat `language-spec.md` and `grammar/ube.ebnf` as the normative language
  sources.
- Keep grammar and semantic changes synchronized.
- Keep `bootstrap-profile.md` aligned with verified compiler behavior.
- Keep `project-files.md` aligned with manifest and build-system behavior.
- Update references and the public manual in `../docs/` when language behavior
  changes.
- Never document planned behavior as implemented.

Repository architecture and project roadmaps live in `../project-docs/`.
