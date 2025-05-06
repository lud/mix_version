defmodule MixVersion.CLI.Argument do
  @moduledoc false
  @enforce_keys [:key, :required, :cast, :doc, :type]
  defstruct @enforce_keys

  @type vtype :: :integer | :float | :string
  @type t :: %__MODULE__{
          key: atom,
          required: boolean,
          type: vtype,
          doc: binary | nil,
          cast: nil | (term -> {:ok, term} | {:error, term}) | {module, atom, [term]}
        }

  def new(key, conf) when is_atom(key) and is_list(conf) do
    required = Keyword.get(conf, :required, true)
    cast = Keyword.get(conf, :cast, nil)

    doc = Keyword.get(conf, :doc) || ""
    type = Keyword.get(conf, :type, :string)

    validate_type(type)
    validate_cast(cast)

    %__MODULE__{key: key, required: required, cast: cast, doc: doc, type: type}
  end

  defp validate_cast(cast) do
    case cast do
      f when is_function(f, 1) ->
        :ok

      nil ->
        :ok

      {m, f, a} when is_atom(m) and is_atom(f) and is_list(a) ->
        :ok

      _ ->
        raise ArgumentError,
              "Expected :cast function to be a valid cast function, got: #{inspect(cast)}"
    end
  end

  # We only support raw types for now
  defp validate_type(type) do
    if type not in [:string, :float, :integer] do
      raise ArgumentError,
            "expected argument type to be one of :string, :float or :integer, got: #{inspect(type)}"
    end

    :ok
  end
end
