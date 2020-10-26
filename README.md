# mix version

<!-- :title: -->

This is a simple tool to update the version number of an elixir project in the `mix.exs` file create a git tag based on the new version.

Check out [version_tasks](https://hex.pm/packages/version_tasks) for a more complete solution.

## Installation

Although this tool can be set as a dependency in you mix projects, is is rather intended to be used as a globally available command line tool.

```bash
mix archive.install hex mix_version
```

## Configuration

The different options can be customized with mix configuration:

```
import Config

config :mix_version,
  tag_prefix: "release-",
  commit_msg: "new version: %s",
  annotation: "tag release-%s created with mix_version",
  annotate: true
```

In the commit message and annotation, any occurence of `%s` will be replaced by the new version number. The presence of `%s` is not mandatory.

Configuration can be overriden by command line options. If `:annotate` is set to `true` in configuration, you can use the `--no-annotate` CLI flag to force it to be `false`.

### Default configuration

```
tag_prefix    "v"
commit_msg    "%s"
annotation    "%s"
annotate      false
```

## Usage

Call the command from within a mix project. With no options, you will be prompted for the new version number.

```bash
mix version [options]
```

### Options

Versions managed by Elixir follow the `MAJOR.MINOR.PATCH` scheme, with optionnaly a pre-release tag as in `1.0.0-rc2`.

```
-M  --major                        Bump the major number.
-m  --minor                        Bump the minor number.
-p  --patch                        Bump the patch number.
-n  --new-version                  Directly enter the new version number.
-x  --tag-prefix <prefix>          Override the tag prefix.
-c  --commit-msg <format>          Override the commit message format.
-a  --annotate                     Create an annotated git tag.
-A  --annotation <format>          Override the annotation message format.
-g  --git-only                     Commit and tag with the current version.
    --help                         Shows this help block.
```

When using the options to bump a part of the version, a pre-release tag will be dropped for a major or minor bump, whereas a patch bump will only remove this pre-release tag and keep the current patch number.

```
Bump patch:
  1.2.3-rc1  ->  1.2.3
  1.2.3      ->  1.2.4

Bump minor:
  1.2.3-rc1  ->  1.3.0
  1.2.3      ->  1.3.0

Bump major:
  1.2.3-rc1  ->  2.0.0
  1.2.3      ->  2.0.0
```
