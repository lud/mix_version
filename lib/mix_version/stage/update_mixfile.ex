defmodule MixVersion.Stage.UpdateMixfile do
  @moduledoc """
  Stage that is responsible to write the `mix.exs` file with the new version
  number.
  """

  @behaviour MixVersion.Stage

  def applies?(_), do: true

  def run(token) do
    path = Mix.Project.project_file()

    with {:ok, content} <- File.read(path),
         {:ok, new_content} <- swap_mixfile_version(token, content),
         :ok <- File.write(path, new_content),
         CliMate.CLI.writeln("Updated mixfile: #{path}"),
         :ok <- maybe_git_add_mixfile(path, token) do
      {:ok, token}
    else
      {:error, :eacces} -> {:error, "Could not access file #{path}, insufficient permissions"}
      {:error, :enoent} -> {:error, "Could not find file #{path}"}
      {:error, _} = err -> err
    end
  end

  defp swap_mixfile_version(token, content) do
    replace_schemes = [
      {~r/\bversion:\s+"#{token.current_vsn}"/, "version: \"#{token.next_vsn}\""},
      {~r/(?<=\s)@version\s+"#{token.current_vsn}"/, "@version \"#{token.next_vsn}\""}
    ]

    mixfile_result =
      for {regex, replacement} <- replace_schemes, reduce: :error do
        :error ->
          if Regex.match?(regex, content) do
            {:ok, String.replace(content, regex, replacement)}
          else
            :error
          end

        {:ok, _content} = ok ->
          ok
      end

    case mixfile_result do
      :error -> {:error, "Could not find version to replace in mixfile"}
      ok -> ok
    end
  end

  def git_enabled?(%{git_cmd?: has_git, git_repo: repo}), do: has_git && is_struct(repo)

  defp maybe_git_add_mixfile(path, token) do
    if git_enabled?(token) do
      git_add_mixfile(path, token)
    else
      :ok
    end
  end

  defp git_add_mixfile(path, token) do
    MixVersion.Git.add(token.git_repo, path)
  end
end
