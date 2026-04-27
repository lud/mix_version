# Changelog

All notable changes to this project will be documented in this file.

## [2.5.3] - 2026-04-27

### 🚀 Features

- Use '--allow-empty' when tagging current version

### ⚙️ Miscellaneous Tasks

- Regenerate CLI code

## [2.5.2] - 2025-11-24

### 🐛 Bug Fixes

- Fix app loader without dev deps

## [2.5.1] - 2025-11-17

### 🐛 Bug Fixes

- Use CLI safe paths loader

### ⚙️ Miscellaneous Tasks

- Regenerate CLI modules

## [2.5.0-rc1] - 2025-05-06

### 🚀 Features

- Embedded cli_mate generated code

### 🐛 Bug Fixes

- Always provide a message to git tags

### 📚 Documentation

- Better options layout in docs

### ⚙️ Miscellaneous Tasks

- Upgraded credo config
- Add support branch installation to README
- Updated repository configuration (#5)
- Update Elixir Github workflow (#6)
- Git Cliff configuration
- CLI docs

## [2.4.0] - 2025-03-25

### 🚀 Features

- [**breaking**] Removed support for installing as an archive

### 🐛 Bug Fixes

- Load app.config to support using libraries from hooks

### ⚙️ Miscellaneous Tasks

- Added dialyzer and mix_audit
- Removed git-cliff config

## [2.2.1] - 2024-03-11

### 🐛 Bug Fixes

- Fixed --anotate that would always default to false (upgrade of cli_mate)

## [2.2.0] - 2024-01-22

### 🚀 Features

- Mixfile is now updated only when hooks succeeded

## [2.1.1] - 2023-09-07

### 🚀 Features

- Files added to Git during before_commit hook are printed to stdout

### ⚙️ Miscellaneous Tasks

- Remove useless debug prints

## [2.1.0] - 2023-09-01

### 🚀 Features

- Added support of before commit hook

### 🐛 Bug Fixes

- Usage of CliMate in various stages

## [2.0.6] - 2023-08-31

### 🚀 Features

- Default to false when asking to confirm new version with unstaged changes

## [1.0.0] - 2020-09-12

