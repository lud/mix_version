# Changelog

All notable changes to this project will be documented in this file.

## [2.6.0] - 2026-10-01

This release makes the tag annotation a home for release notes.

Write the notes in a file and pass it with `--annotation-file` (`-F`). Hooks of
arity 2 receive the resolved annotation, so a changelog generator such as
git-cliff can include the notes in the entry of the release being cut. The
README has a complete example.

`--confirm` prints the tag name, commit message and annotation, and asks before
making any change.

Behaviour changes to be aware of:

- Declining any prompt now exits with a non-zero status.
- Lines starting with `#` are kept in tag annotations, so Markdown headings
  survive.
- An empty tag annotation is rejected.
- The `:annotate` option is deprecated, tags are always annotated.


### 🚀 Features

- Deprecate the :annotate option, tags are always annotated (_lud_)
- Add --annotation-file (-F) to read the tag annotation from a file (_lud_)
- Support arity-2 before_commit hooks receiving release information (_lud_)
- Add --confirm to print the release summary and ask before making changes (_lud_)

### 🐛 Bug Fixes

- Keep lines starting with '#' in tag annotations (_lud_)
- Reject empty tag annotations and name the hook key in invalid hook errors (_lud_)
- Exit with a non-zero status when a prompt is declined (_lud_)

### 🚜 Refactor

- Refactor around a functional core for testability (_lud_)

### 📚 Documentation

- Added docs for public API (_lud_)
- Document hooks with a git-cliff changelog example (_lud_)

### 🧪 Testing

- Add tests instrumenting subapp (_lud_)

### ⚙️ Miscellaneous Tasks

- Display just uninstall on global install test guard (_lud_)
- Limit justfile verbosity on mix.deps (_lud_)

## [2.5.3] - 2026-04-27

### 🚀 Features

- Use '--allow-empty' when tagging current version (_lud_)

### ⚙️ Miscellaneous Tasks

- Regenerate CLI code (_lud_)

## [2.5.2] - 2025-11-24

### 🐛 Bug Fixes

- Fix app loader without dev deps (_lud_)

## [2.5.1] - 2025-11-17

### 🐛 Bug Fixes

- Use CLI safe paths loader (_lud_)

### ⚙️ Miscellaneous Tasks

- Regenerate CLI modules (_lud_)

## [2.5.0-rc1] - 2025-05-06

### 🚀 Features

- Embedded cli_mate generated code (_lud_)

### 🐛 Bug Fixes

- Always provide a message to git tags (_lud_)

### 📚 Documentation

- Better options layout in docs (_lud_)

### ⚙️ Miscellaneous Tasks

- Upgraded credo config (_lud_)
- Add support branch installation to README (_lud_)
- Updated repository configuration (#5) (_Ludovic Dem_)
- Update Elixir Github workflow (#6) (_Ludovic Dem_)
- Git Cliff configuration (_lud_)
- CLI docs (_lud_)

## [2.4.0] - 2025-03-25

### 🚀 Features

- [**breaking**] Removed support for installing as an archive (_lud_)

### 🐛 Bug Fixes

- Load app.config to support using libraries from hooks (_lud_)

### ⚙️ Miscellaneous Tasks

- Added dialyzer and mix_audit (_lud_)
- Removed git-cliff config (_lud_)

## [2.2.1] - 2024-03-11

### 🐛 Bug Fixes

- Fixed --anotate that would always default to false (upgrade of cli_mate) (_lud_)

## [2.2.0] - 2024-01-22

### 🚀 Features

- Mixfile is now updated only when hooks succeeded (_lud_)

## [2.1.1] - 2023-09-07

### 🚀 Features

- Files added to Git during before_commit hook are printed to stdout (_lud_)

### ⚙️ Miscellaneous Tasks

- Remove useless debug prints (_lud_)

## [2.1.0] - 2023-09-01

### 🚀 Features

- Added support of before commit hook (_lud_)

### 🐛 Bug Fixes

- Usage of CliMate in various stages (_lud_)

## [2.0.6] - 2023-08-31

### 🚀 Features

- Default to false when asking to confirm new version with unstaged changes (_lud_)

## [1.0.0] - 2020-09-12

