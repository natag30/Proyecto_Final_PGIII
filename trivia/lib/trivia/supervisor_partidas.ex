#Autor: Carlos Andres

defmodule Trivia.SupervisorPartidas do
  use DynamicSupervisor

  def start_link(_opciones) do
    DynamicSupervisor.start_link(#Dependo del nombre y argumentos
      __MODULE__,
      :ok,
      name: __MODULE__
    )
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(
      strategy: :one_for_one
    )
  end

  def iniciar_partida(args) do
    especificacion = %{
      id: Trivia.Partida,
      start: {Trivia.Partida, :start_link, [args]},
      restart: :transient
    }

    DynamicSupervisor.start_child(
      __MODULE__,
      especificacion
    )
  end
end
