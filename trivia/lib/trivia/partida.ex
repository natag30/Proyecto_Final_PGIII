# Autor: Diego Rincon

Code.require_file("bot.exs", __DIR__)

defmodule Trivia.Partida do
  @moduledoc """
  Módulo que representa una partida de trivia.
  """

  use GenServer, restart: :transient

  @puntos %{basico: {10, -5}, intermedio: {20, -10}, avanzado: {30, -15}}
  @letras ["A", "B", "C", "D"]
  @max_jugadores 8
  @min_bots 2
  @pausa_ms 3_000

  defstruct [
    :id,
    :creador,
    :tema,
    :nivel,
    :total_preguntas,
    :tiempo_pregunta,
    :cliente,
    :sorteo,
    :registrar,
    :gestor,
    :pausa_ms,
    estado: :esperando,
    pregunta_actual: 0,
    jugadores: [],
    destinos: %{},
    bots: %{},
    puntajes: %{},
    preguntas: [],
    ronda: nil
  ]

  # ----------------- funciones -----------------

  @doc "Puntos de una ronda: puntos de aciertos"

  def puntos_rond(:correcto,nivel,restantes,tiemoo) do
    {correcto, _incorrecto} =map.get(@puntos, nivel)
    correcto + bonificacion_tiempo(restantes, tiempo)
  end

  def puntos_ronda(:incorrecto, nivel,_restantes, tiempo) do
    {_correcto, incorrecto} = Map.get(@puntos, nivel)
    incorrecto + bonificacion_tiempo(restantes, tiempo)
  end


  def puntos_ronda(:sin_responder,_nivel,_restantes,_tiempo), do: 0

  @doc "bonificacion = trunc(5* segundos_restantes/tiempo_pregunta),entre 0 y 5"
  def bonificacion(restantes, tiempo)when tiempo > 0 do
    trunc(5 * restantes / tiempo)
  end

  @doc"se valida la respuesta contra el estado de la ronda(un mapa con :abierta y :respuesta).
  se devuelve {:ok, letra} o {:error, motivo}. no se modifica nada una letra invalidada no consume la respuesta del jugador,
  pero si se valida una letra correcta o incorrecta se consume la respuesta y se actualiza el puntaje."

  def validar_respuesta(%{ronda: %{abierta: false}}, _letra), do: {:error, :ronda_cerrada}
  def validar_respuesta(%{ronda: %{respuesta: correcta}}, letra) when letra == correcta, do: {:ok, letra}
  def validar_respuesta(%{ronda: %{respuesta: correcta}}, letra) when letra in @letras and letra != correcta, do: {:error, :incorrecta}
  def validar_respuesta(_partida, _letra), do: {:error, :letra_invalida}

  cond do
    not ronda_abierta -> {:error, :ronda_cerrada}
    letra == correcta -> {:ok, letra}
    letra in @letras and letra != correcta -> {:error, :incorrecta}
    true -> {:error, :letra_invalida}

  end

  defp ronda_abierta?(%{abierta: true}), do: true
  defp ronda_abierta?(_), do: false

  defp normalizar_letra(letra) when is binary(letra), do: letra |> String.trim() |> String.upcase()
  defp normalizar_letra(_), do: nil

  # -------------API de partida -----------------

  def start_link(jugadores) do:
  GenServer.start_link(__MODULE__, jugadores)
  def add_bot(partida, nombre, dificultad, nivel) do:
  GenServer.call(partida, {:add_bot, nombre, dificultad, nivel})
  def start_game(partida) do: GenServer.call(partida, :start_game)
  def answer (partida, jugador, letra) do: GenServer.call(partida, {:answer, jugador, letra})
  def leave(partida, jugador) do: GenServer.call(partida, {:leave, jugador})
  def estado(partida) do: GenServer.call(partida, :estado)
  def puntajes(partida) do: GenServer.call(partida, :puntajes)
  def preguntas(partida) do: GenServer.call(partida, :preguntas)
  def ronda(partida) do: GenServer.call(partida, :ronda)
  def notificar_jugadores(partida, mensaje) do: GenServer.cast(partida, {:notificar, mensaje})
  def finalizar(partida) do: GenServer.cast(partida, :finalizar)
  def reiniciar(partida) do: GenServer.cast(partida, :reiniciar)

end

  # ------------Callbaks de GenServer -----------------

  @impl true
  def init(jugadores) do
    # inicializa la partida con los jugadores y bots
    # crea un mapa de puntajes y destinos para cada jugador
    creador = List.first(jugadores)
    tema = nil
    puntajes = Map.new(jugadores, fn jugador -> {jugador, 0} end)
    destinos = Map.new(jugadores, fn jugador -> {jugador, self()} end)
    bots = %{}

    {:ok,
     %__MODULE__{
       id: :erlang.unique_integer([:positive]),
       jugadores: jugadores,
       puntajes: puntajes,
       creador: creador,
       destinos: destinos,
       bots: bots
     }}
  end


