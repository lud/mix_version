# mix version

<!-- doc-start -->

This is a simple tool to automatically update the version number of an Elixir
project in the `mix.exs`, commit the change and create and create a git tag
based on the new version.

Check out [version_tasks](https://hex.pm/packages/version_tasks) for a more
versatile solution.


## Installation

Although this tool can be set as a dependency in you mix projects, is is rather intended to be used as a globally available command line tool.

```bash
mix archive.install hex mix_version
```


## Breaking changes in version 2


The v2 is a partial rewrite where most checks are run before attempting to make
any modification for the project. A few changes to how the tool should be used
were implemented:

* The configuration of the tool from the config files is not supported anymore.
  This is to support the tool as a globally installed archive. When
  `mix_version` is not listed in the dependencies, Elixir would warn if a
  project contains configuration for an unknown application.
* The new configuration is provided by listing a `:versioning` from the
  `project/0` callback of the `mix.exs` file.
* The `--git-only` option was dropped, as the tool will warn and prompt if some
  files are not checked in, allowing to fix those issues before any change is
  made to the `mix.exs` file and any commit/tag is created.
* Any unchecked change to the `mix.exs` file will prevent the tool to run.
* The `:annotate` option is now `true` by default, creating annotated tags.


## Configuration


The configuration for v2 can be provided under `:versioning` from the
`project/0` callback of the project file:

```elixir
# in mix.exs

def project do
  [
    app: :my_app,
    version: "1.2.3",
    # ...
    versioning: versioning()
  ]
end

defp versioning do
  [
    tag_prefix: "release-",
    commit_msg: "new version: %s",
    annotation: "tag release-%s created with mix_version",
    annotate: true
  ]
end
```

In the commit message and annotation, any occurence of `%s` will be replaced by
the new version number. The presence of `%s` is not mandatory.

Configuration can be overriden by command line options. For instance, if
`:annotate` is set to `true` in configuration, you can use the `--no-annotate`
CLI flag to force it to be `false`.


The following sample configuration is now unsupported and will be ignored.

```elixir
import Config

# UNSUPPORTED AS OF v2.0.0
config :mix_version,
  tag_prefix: "release-",
  commit_msg: "new version: %s",
  annotation: "tag release-%s created with mix_version",
  annotate: true
```


### Default configuration

```elixir
annotate:   true
commit_msg: "new version %s"
annotation: "new version %s"
tag_prefix: "v"
```


## Usage

Call the command from within a mix project. With no options, you will be
prompted for the new version number.

```bash
mix version [options]
```


### Options

Versions managed by Elixir follow the `MAJOR.MINOR.PATCH` scheme, with
optionnaly a pre-release tag as in `1.0.0-rc2`.

```text
-M, --major        boolean. Bump to a new major version.
-m, --minor        boolean. Bump to a new minor version.
-p, --patch        boolean. Bump the patch version.
-a, --annotate     boolean. Create an annotated git tag.
-A, --annotation   string. Define the tag annotation message, with all '%s' replaced by the new VSN.
-c, --commit-msg   string. Define the commit message, with all '%s' replaced by the new VSN.
-n, --new-version  string. Set the new version number.
-x, --tag-prefix   string. Define the tag prefix.

```

When using the options to bump a part of the version, a pre-release tag will be
dropped for a major or minor bump, whereas a patch bump will only remove this
pre-release tag and keep the current patch number.

```text
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

<!-- doc-end -->

## TODO

This list contains wanted features

* [ ] Hooks to run system commands such as `chan release` during the version
  upgrade.
* [ ] Git helpers instead of system commands, such as `git_add: "CHANGELOG.md".
* [ ] Subcommands or flags to just print the current or next VSN.
* [ ] `-t` flag to just tag with the _current_ VSN.
