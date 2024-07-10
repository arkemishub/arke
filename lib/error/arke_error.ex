defmodule Arke.Errors.ArkeError do
  defexception context: :generic, errors: "Generic Arke error", plug_status: 400
end