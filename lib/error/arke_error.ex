defmodule Arke.Errors.ArkeError do
  defexception [:error_message,:type]

  def message(%{error_message: nil}=exception), do: "implementare messagio"
  def message(%{error_message: msg}=exception) when is_binary(msg), do: msg
  def message(%{error_message: [%{context: context, message: message}]}=exception), do: "context: #{context}, message: #{message}"
  def message(%{error_message: errors}=exception) when is_list(errors) do
    formatted_errors =
      errors
      |> Enum.map(&format_error/1)
      |> Enum.join("\n")

    "Found multiple errors:\n" <> formatted_errors
  end

  defp format_error(%{context: context, message: message}) do
    "- context: #{context}, message: #{message}"
  end

end