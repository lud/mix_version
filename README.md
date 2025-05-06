# mix version

Automatically updates the version of Elixir projects:

* Updates the version number in `mix.exs`.
* Commits the changes.
* Creates an annotated git tag with the new version.
* Supports hooks to add additional changes, for instance updating a change log.


## Installation

### As a dependency

You can install MixVersion as a regular dependency in your Elixir projects:

```elixir
def deps do
  [
    {:mix_version, "~> 2.4", only: [:dev, :test], runtime: false},
  ]
end
```


### Installing globally

When managing multiple projects, it can be easier to install the mix task as an
archive.

```bash
mix archive.install hex mix_version
```



## Breaking changes in version 2


The v2 is a partial rewrite where most checks are run before attempting to make
any modification for the project. A few changes to how MixVersion should be used
were implemented:

* The configuration of MixVersion from the config files is not supported
  anymore. This is to support MixVersion as a globally installed archive. When
  MixVersion is not listed in the dependencies, Elixir would warn if a project
  contains configuration for an unknown application.
* The new configuration is provided by listing a `:versioning` from the
  `project/0` callback of the `mix.exs` file.
* The `--git-only` option was dropped. MixVersion will warn and prompt if
  some files are not checked in, allowing to fix those issues before any change
  is made to the `mix.exs` file and any commit/tag is created.
* Any unchecked change to the `mix.exs` file will prevent MixVersion to run.
* The `:annotate` option is now `true` by default, creating annotated tags.


<!-- doc-start -->

## Configuration


Configuration can be provided under `:versioning` from the `project/0` callback
of the project file:

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
    annotate:   true,
    annotation: "new version %s",
    commit_msg: "new version %s",
    tag_prefix: "v"
  ]
end
```

In the commit message and annotation, any occurence of `%s` will be replaced by
the new version number. The presence of `%s` is not mandatory.

This configuration is totally optional. The sample values above are the default
values used by `mix version`.

Configuration can be overriden by command line options. For instance, if
`:annotate` is set to `false` in configuration, you can use the `--annotate` CLI
flag to force it to be `true`.

<!-- doc-end -->

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
-i, --info
      Only outputs the current version and stops. Ignores all other options.
      Defaults to false.

-M, --major
      Bump to a new major version. Defaults to false.

-m, --minor
      Bump to a new minor version. Defaults to false.

-p, --patch
      Bump the patch version. Defaults to false.

-n, --new-version <string>
      Set the new version number. Defaults to nil.

-a, --annotate
      Create an annotated git tag.

-c, --commit-msg <string>
      Define the commit message, with all '%s' replaced by the new VSN.

-A, --annotation <string>
      Define the tag annotation message, with all '%s' replaced by the new VSN.

-x, --tag-prefix <string>
      Define the tag prefix.

-k, --tag-current
      Commit and tag with the current version. Defaults to false.

    --help
      Displays this help.
```

When bumping a part of the version, pre-release tags are dropped. For a major or
minor bump, the version number changes, but it remains the same with a patch
bump..

```text
Bump major:
  1.2.3      ->  2.0.0
  1.2.3-rc1  ->  2.0.0

Bump minor:
  1.2.3      ->  1.3.0
  1.2.3-rc1  ->  1.3.0

Bump patch:
  1.2.3      ->  1.2.4
  1.2.3-rc1  ->  1.2.3  # Still 1.2.3
```


