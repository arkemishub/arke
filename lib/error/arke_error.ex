defmodule Arke.Errors.ArkeError do
  defexception context: :generic,
               message: :undefined,
               errors: :undefined,
               type: :error
end