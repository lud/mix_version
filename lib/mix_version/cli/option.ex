defmodule MixVersion.CLI.Option do
  @moduledoc false
  @enforce_keys [:key, :doc, :type, :short, :default, :keep, :doc_arg, :default_doc]
  defstruct @enforce_keys

  @type vtype :: :integer | :float | :string | :count | :boolean
  @type t :: %__MODULE__{
          key: atom,
          doc: binary,
          type: vtype,
          short: atom,
          default: term,
          keep: boolean,
          doc_arg: binary,
          default_doc: binary
        }

  def new(key, conf) when is_atom(key) and is_list(conf) do
    keep = Keyword.get(conf, :keep, false)
    type = Keyword.get(conf, :type, :string)
    doc = Keyword.get(conf, :doc) || ""
    short = Keyword.get(conf, :short, nil)
    doc_arg = Keyword.get_lazy(conf, :doc_arg, fn -> default_doc_arg(type) end)
    default_doc = Keyword.get(conf, :default_doc, nil)

    default =
      case Keyword.fetch(conf, :default) do
        {:ok, term} -> {:default, term}
        :error when type == :boolean -> :skip
        :error -> :skip
      end

    %__MODULE__{
      key: key,
      doc: doc,
      type: type,
      short: short,
      default: default,
      keep: keep,
      doc_arg: doc_arg,
      default_doc: default_doc
    }
  end

  defp default_doc_arg(:integer), do: "integer"
  defp default_doc_arg(:float), do: "float"
  defp default_doc_arg(:string), do: "string"
  defp default_doc_arg(:count), do: nil
  defp default_doc_arg(:boolean), do: nil
end
