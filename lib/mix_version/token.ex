defmodule MixVersion.Token do
  @moduledoc """
  The "token" is the state of the command line execution, passed to and returned
  from all stages.
  """

  @enforce_keys [:opts, :git_cmd?, :git_repo, :current_vsn]
  @defaults [
    opts: nil,
    git_cmd?: false,
    git_repo: nil,
    current_vsn: nil,
    next_vsn: nil,
    hooks: %{}
  ]
  defstruct @defaults

  @type t :: %__MODULE__{}

  def new(current_vsn, opts, hooks) do
    struct!(__MODULE__,
      current_vsn: current_vsn,
      opts: opts,
      git_cmd?: false,
      git_repo: nil,
      hooks: hooks
    )
  end

  @defaults
  |> Keyword.keys()
  |> Enum.each(fn k ->
    def unquote(:"put_#{k}")(%__MODULE__{} = token, value) do
      Map.put(token, unquote(k), value)
    end
  end)
end
