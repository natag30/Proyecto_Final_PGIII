#Autor: Carlos Andres

defmodule Trivia.Servidor do

  use GenServer

  #Nombre del servidor
  def nombre do
    __MODULE__
  end

  def start_link(_opciones) do
    GenServer.start_link(
      __MODULE__,
      :ok,
      name: nombre()
    )
  end

  @impl true
  def init(:ok) do
    estado = %{}

    {:ok, estado}
  end

  def iniciar do

    with  :ok <- iniciar_proceso(Trivia.Persistencia),
          :ok <- iniciar_proceso(Trivia.BancoPreguntas),
          :ok <- iniciar_proceso(Trivia.GestorJugadores),
          :ok <- iniciar_proceso(Trivia.SupervisorPartidas),
          :ok <- iniciar_proceso(Trivia.GestorPartidas),
          :ok <- iniciar_proceso(__MODULE__) do
    :ok
  end
  end

  defp iniciar_proceso(modulo) do
    case modulo.start_link([]) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        :ok

      error ->
        error
    end
  end
end
