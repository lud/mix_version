defmodule MixVersion.Config do
  @moduledoc """
  Helpers to read from the Mix project the app is called in.
  """

  @doc """
  Returns the configuration of the current Mix project, as given by
  `Mix.Project.config/0`.
  """
  def current_project do
    Mix.Project.config()
  end

  @doc """
  Returns the application name defined in the given project configuration.

  ### Examples

      iex> MixVersion.Config.otp_app(app: :my_app, version: "1.0.0")
      :my_app
  """
  def otp_app(project) do
    project_get(project, :app)
  end

  # -- Data reader ------------------------------------------------------------

  @doc """
  Fetches a value from the current Mix project configuration.

  Accepts a single key or a path of keys, as `project_get/2`. Raises `KeyError`
  when a key is missing.
  """
  def project_get(key_or_path) do
    project_get(current_project(), key_or_path)
  end

  @doc """
  Fetches a value from the given project configuration.

  Accepts a single key, or a list of keys to read from nested keyword lists.
  Raises `KeyError` when a key is missing.

  ### Examples

      iex> project = [app: :my_app, versioning: [annotate: true]]
      iex> MixVersion.Config.project_get(project, :app)
      :my_app
      iex> MixVersion.Config.project_get(project, [:versioning, :annotate])
      true
  """
  def project_get(mod, key_or_path) do
    _project_get(mod, key_or_path)
  end

  @doc """
  Fetches a value from the given project configuration, with a default.

  Behaves like `project_get/2` but returns `default` when a key is missing.

  ### Examples

      iex> MixVersion.Config.project_get([app: :my_app], [:versioning, :annotate], false)
      false
  """
  def project_get(mod, key_or_path, default) do
    _project_get(mod, key_or_path)
  rescue
    _ in KeyError -> default
  end

  defp _project_get(project, key) when is_atom(key) do
    project_get(project, [key])
  end

  defp _project_get(project, keys) when is_list(project) do
    fetch_in!(project, keys)
  end

  defp fetch_in!(data, []) do
    data
  end

  defp fetch_in!(data, [key | keys]) when is_list(data) do
    sub_data = Keyword.fetch!(data, key)
    fetch_in!(sub_data, keys)
  end
end
