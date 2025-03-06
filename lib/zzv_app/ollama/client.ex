# lib/zzv_app/ollama/client.ex
defmodule ZzvApp.Ollama.Client do
  @moduledoc """
  Client for interacting with Ollama API
  """

  @base_url "http://ollama:11434"

  @doc """
  Generate a response using the specified model
  """
  def generate(prompt, opts \\ []) do
    model = Keyword.get(opts, :model, "llama3")

    payload = %{
      model: model,
      prompt: prompt,
      stream: false
    }

    case HTTPoison.post("#{@base_url}/api/generate", Jason.encode!(payload), [{"Content-Type", "application/json"}]) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, response} -> {:ok, response["response"]}
          error -> error
        end
      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "HTTP Error #{status_code}: #{body}"}
      error ->
        error
    end
  end

  @doc """
  List available models
  """
  def list_models do
    case HTTPoison.get("#{@base_url}/api/tags") do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"models" => models}} -> {:ok, models}
          error -> error
        end
      error -> error
    end
  end

  @doc """
  Pull a model from Ollama library
  """
  def pull_model(model_name) do
    payload = %{name: model_name}

    HTTPoison.post("#{@base_url}/api/pull", Jason.encode!(payload), [{"Content-Type", "application/json"}])
  end
end
