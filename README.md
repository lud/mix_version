# mix version

<!-- rdmx :badges
    hexpm         : "mix_version?color=4e2a8e"
    github_action : "lud/mix_version/elixir.yaml?label=CI&branch=main"
    license       : mix_version
    -->
[![hex.pm Version](https://img.shields.io/hexpm/v/mix_version?color=4e2a8e)](https://hex.pm/packages/mix_version)
[![Build Status](https://img.shields.io/github/actions/workflow/status/lud/mix_version/elixir.yaml?label=CI&branch=main)](https://github.com/lud/mix_version/actions/workflows/elixir.yaml?query=branch%3Amain)
[![License](https://img.shields.io/hexpm/l/mix_version.svg)](https://hex.pm/packages/mix_version)
<!-- rdmx /:badges -->

Automatically updates the version of Elixir projects:

* Updates the version number in `mix.exs`.
* Commits the changes.
* Creates an annotated git tag with the new version.
* Supports hooks to add additional changes, for instance updating a change log.


## Installation

### As a dependency

You can install MixVersion as a regular dependency in your Elixir projects:

<!-- rdmx :app_dep vsn:$app_vsn only:"dev,test" runtime:false -->
```elixir
defp deps do
  [
    {:mix_version, "~> 2.5", only: [:dev, :test], runtime: false},
  ]
end
```
<!-- rdmx /:app_dep -->


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
`:tag_prefix` is set to `"release/"` in configuration, you can use
`--tag-prefix v` to create a `v`-prefixed tag instead.

## Hooks

Hooks run once the new version is known, before `mix.exs` is updated and the
changes are committed. They are listed under the `:before_commit` key of the
`:versioning` configuration and run in order:

* A function of arity 1 receives the new version as a string.
* A function of arity 2 receives the new version and a map with the following
  keys:
  * `:current_vsn` - The current version, as a string.
  * `:next_vsn` - The new version, as a string.
  * `:next_version` - The new version, as a `Version` struct.
  * `:tag_name` - The name of the Git tag that will be created, including the
    tag prefix.
  * `:annotation` - The tag annotation, with all `%s` replaced by the new
    version.
* An `{:add, path}` tuple stages `path` to the Git index, so it is included in
  the version commit.

Functions must return `:ok` or `{:error, reason}`. The first error stops the
command before `mix.exs` is updated and before anything is committed or tagged.

### Example: Generating a changelog

This configuration regenerates `CHANGELOG.md` with
[git-cliff](https://git-cliff.org) and adds it to the version commit:

```elixir
defp versioning do
  [
    before_commit: [
      &gen_changelog/2,
      {:add, "CHANGELOG.md"}
    ]
  ]
end

defp gen_changelog(vsn, info) do
  args = ["cliff", "--tag", vsn, "--with-tag-message", info.annotation, "-o", "CHANGELOG.md"]

  case System.cmd("git", args, stderr_to_stdout: true) do
    {_, 0} -> IO.puts("Updated CHANGELOG.md with #{vsn}")
    {out, _} -> {:error, "Could not update CHANGELOG.md:\n\n #{out}"}
  end
end
```

The `--with-tag-message` flag gives the annotation of the tag being created to
the changelog template as `message`. For older releases, git-cliff reads that
`message` from the annotated tags themselves, so a full regeneration of the
changelog keeps the text of every release. Render it in the `body` template of
your `cliff.toml`:

```toml
body = """
## [{{ version | trim_start_matches(pat="v") }}]
{% if message and message is not starting_with("new version") %}
{{ message }}
{% endif %}
...
"""
```

The `starting_with` filter skips the default `"new version X.Y.Z"` annotation.

### Example: Release notes

Write the introduction of the release in a file and pass it with
`--annotation-file`. It becomes the tag annotation, and the hook above adds it
to the changelog entry:

```bash
mix version --minor --annotation-file tmp/release-notes.md
git push --follow-tags
```

The tag annotation then holds the release notes. Once the tag exists,
`git cliff --latest` renders the introduction followed by the list of changes,
which you can publish as a GitHub release with the
[GitHub CLI](https://cli.github.com):

```bash
gh release create v1.3.0 --notes "$(git cliff --latest --strip all)"
```

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

-c, --commit-msg <string>
      Define the commit message, with all '%s' replaced by the new VSN.

-A, --annotation <string>
      Define the tag annotation message, with all '%s' replaced by the new VSN.

-F, --annotation-file <string>
      Read the tag annotation message from the given file, with all '%s'
      replaced by the new VSN. Cannot be used with --annotation.

-x, --tag-prefix <string>
      Define the tag prefix.

-k, --tag-current
      Commit and tag with the current version. Defaults to false.

    --confirm
      Print the commit message and the tag to create, and ask for confirmation
      before making any change. Defaults to false.

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


