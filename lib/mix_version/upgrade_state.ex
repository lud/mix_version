defmodule MixVersion.UpgradeState do
  @moduledoc """
  Module describing the state of a version upgrade.
  """
  defstruct [:current_vsn, :next_vsn, changed_files: [], opts: %MixVersion.Options{}]

  def from_project() do
    project_config = Mix.Project.config()
    current_vsn_str = Keyword.fetch!(project_config, :version)
    current_vsn = Version.parse!(current_vsn_str)

    struct(__MODULE__, current_vsn: current_vsn)
  end

  def set_opts(%__MODULE__{} = state, %MixVersion.Options{} = opts) do
    # Put the new version in the state directly as we know this is our target.
    next_vsn =
      cond do
        opts.new_version != nil -> opts.new_version
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

  defp bump(vsn, key) do
    vsn
    |> Map.update!(key, &(&1 + 1))
    |> Map.put(:pre, [])
  end
end
