<!-- markdownlint-disable -->

# Changelog
All notable changes to this project will be documented in this file.

## [Unreleased]

## [2.0.4] - 2022-07-27
### Fixed
- Fixed bug with --tag-current not having a default value.

## [2.0.3] - 2022-07-27
### Added
- The new `--tag-current` option (with short `-k`) allows simply tag the current
  version specified in `mix.exs` without changing it.

## [2.0.0] - 2022-04-19
### Changed
- The order of events has been modified in order to run all possible checks before any modification to the codebase or Git is made. This includes checking the Git tag availability and unstaged changes.
- Any unstaged modification to `mix.exs` will now make the tool to fail.
- The configuration for commit messages, annotations and tag prefix is now pulled from the `mix.exs` file, under a `:versioning` key returned from `project/0`. Any configuration in the app config files for the `:mix_version` OTP app is ignored.
- The `:annotate` option now defaults to `true`, creating annotated git tags.

## [1.3.0] - 2020-10-26
### Added
- Git annotated tags are supported, but not enabled by default

## 1.2.0 - 2020-09-29
### Added
- Versions set as module attributes in mix.exs can now be replaced

[Unreleased]: https://github.com/lud/mix_version/compare/v2.0.4...HEAD
[2.0.4]: https://github.com/lud/mix_version/compare/v2.0.3...v2.0.4
[2.0.3]: https://github.com/lud/mix_version/compare/v2.0.0...v2.0.3
[2.0.0]: https://github.com/lud/mix_version/compare/v1.3.0...v2.0.0
[1.3.0]: https://github.com/lud/mix_version/compare/v1.2.0...v1.3.0
