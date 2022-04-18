defmodule MixVersion.Config do
  @moduledoc """
  Helpers to read from the Mix project the app is called in.
  """

  def current_project do
    Mix.Project.config()
  end

  def otp_app(project) do
    project_get(project, :app)
  end

  # -- Data reader ------------------------------------------------------------

  def project_get(key_or_path) do
    project_get(current_project(), key_or_path)
  end

  def project_get(mod, key_or_path) do
    _project_get(mod, key_or_path)
  end

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
