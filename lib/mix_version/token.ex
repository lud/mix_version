defmodule MixVersion.Token do
  @moduledoc """
  The "token" is the state of the command line execution, passed to and returned
  from all stages.
  """

  @enforce_keys [:opts, :git_cmd?, :git_repo, :current_vsn, :mixfile_path, :cwd]
  @defaults [
    opts: nil,
    git_cmd?: false,
    git_repo: nil,
    current_vsn: nil,
    next_vsn: nil,
    hooks: %{},
    mixfile_path: nil,
    cwd: nil
  ]
  defstruct @defaults

  @type t :: %__MODULE__{}

  @doc """
  Builds a new token from an environment map containing the current version,
  the parsed CLI options, the configured hooks, the path of the project
  mixfile and the working directory.

  The Git related fields start with their default values and are filled by the
  Git detection stages.
  """
  def new(env) do
    struct!(__MODULE__,
      current_vsn: env.current_vsn,
      opts: env.opts,
      git_cmd?: false,
      git_repo: nil,
      hooks: env.hooks,
      mixfile_path: env.mixfile_path,
      cwd: env.cwd
    )
  end

  @defaults
  |> Keyword.keys()
  |> Enum.each(fn k ->
    @doc """
    Returns the token with the `#{inspect(k)}` field set to the given value.
    """
    def unquote(:"put_#{k}")(%__MODULE__{} = token, value) do
      Map.put(token, unquote(k), value)
    end
  end)
end
