defmodule MixVersion.Token do
  @moduledoc false

  @enforce_keys [:opts, :git_cmd?, :git_repo, :current_vsn]
  @defaults [opts: nil, git_cmd?: false, git_repo: nil, current_vsn: nil, next_vsn: nil]
  defstruct @defaults

  @type t :: %__MODULE__{}

  def new(current_vsn, opts) do
    struct!(__MODULE__, current_vsn: current_vsn, opts: opts, git_cmd?: false, git_repo: nil)
  end

  @defaults
  |> Keyword.keys()
  |> Enum.each(fn k ->
    def unquote(:"put_#{k}")(%__MODULE__{} = token, value) do
      Map.put(token, unquote(k), value)
    end
  end)
end
