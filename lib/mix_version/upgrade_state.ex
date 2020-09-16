defmodule MixVersion.UpgradeState do
  @moduledoc """
  Module describing the state of a version upgrade.
  """
  defstruct current_vsn: nil,
            next_vsn: nil,
            changed_files: [],
            opts: %MixVersion.Options{},
            git_repo: nil

  def from_project() do
    project_config = Mix.Project.config()
    current_vsn_str = Keyword.fetch!(project_config, :version)
    current_vsn = Version.parse!(current_vsn_str)

    struct(__MODULE__, current_vsn: current_vsn)
  end

  @doc """
  Returns a state where the current version of the project is considered the
  :next_vsn of the upgrade state. The :current_vsn will be `nil`.
  """
  def from_project_as_new() do
    project_config = Mix.Project.config()
    next_vsn_str = Keyword.fetch!(project_config, :version)
    next_vsn = Version.parse!(next_vsn_str)

    struct(__MODULE__, next_vsn: next_vsn)
  end

  def set_opts(%__MODULE__{} = state, %MixVersion.Options{} = opts) do
    # Put the new version in the state directly as we know this is our target.
    next_vsn =
      cond do
        opts.new_version != nil -> opts.new_version
        state.next_vsn != nil -> state.next_vsn
        opts.major -> bump(state.current_vsn, :major)
        opts.minor -> bump(state.current_vsn, :minor)
        opts.patch -> bump(state.current_vsn, :patch)
        true -> nil
      end

    struct(state, opts: opts, next_vsn: next_vsn)
  end

  def add_changed_file(%{changed_files: files} = state, path) do
    struct(state, changed_files: [path | files])
  end

  # When bumping the patch of a version with a pre-release tag, we will just
  # drop this pre-release tag.
  def bump(%Version{pre: [_ | _]} = vsn, :patch),
    do: Map.put(vsn, :pre, [])

  def bump(%Version{} = vsn, :patch),
    do: Map.update!(vsn, :patch, &(&1 + 1))

  def bump(%Version{minor: minor} = vsn, :minor),
    do: Map.merge(vsn, %{minor: minor + 1, patch: 0, pre: []})

  def bump(%Version{major: major} = vsn, :major),
    do: Map.merge(vsn, %{major: major + 1, minor: 0, patch: 0, pre: []})
end
