# Autor: Diego Rincon

Code.require_file("bot.exs", __DIR__)

defmodule Trivia.Partida do
  @moduledoc """
  Módulo que representa una partida de trivia.
  """

  use GenServer, restart: :transient

  @puntos %{basico: {10, -5}, intermedio: {15, -8}, avanzado: {20, -10}}
  @letras ["A", "B", "C", "D"]
  @max_jugadores 4
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

  # ----------------- funciones puras -----------------

  @doc "Puntos de una ronda: puntos del nivel, más bonificación solo si acierta"
  def puntos_ronda(:correcto, nivel, restantes, tiempo) do
    {correcto, _incorrecto} = Map.get(@puntos, nivel)
    correcto + bonificacion(restantes, tiempo)
  end

  def puntos_ronda(:incorrecto, nivel, _restantes, _tiempo) do
    {_correcto, incorrecto} = Map.get(@puntos, nivel)
    incorrecto
  end

  def puntos_ronda(:sin_responder, _nivel, _restantes, _tiempo), do: 0

  @doc "bonificacion = trunc(5 * segundos_restantes / tiempo_pregunta), entre 0 y 5"
  def bonificacion(restantes, tiempo) when tiempo > 0 do
    restantes = restantes |> max(0) |> min(tiempo)
    trunc(5 * restantes / tiempo)
  end

  @doc """
  Valida si una respuesta se acepta (no si es correcta). Recibe el estado de la ronda
  (un mapa con :abierta y :respuestas). Devuelve {:ok, letra} o {:error, motivo}.
  No modifica nada: una letra inválida no consume la respuesta del jugador.
  """
  def validar_respuesta(ronda, jugador, letra) do
    letra = normalizar_letra(letra)

    cond do
      not ronda_abierta?(ronda) -> {:error, :ronda_cerrada}
      letra not in @letras -> {:error, :letra_invalida}
      Map.has_key?(ronda.respuestas, jugador) -> {:error, :ya_respondio}
      true -> {:ok, letra}
    end
  end

  defp ronda_abierta?(%{abierta: true}), do: true
  defp ronda_abierta?(_), do: false

  defp normalizar_letra(letra) when is_binary(letra), do: letra |> String.trim() |> String.upcase()
  defp normalizar_letra(_), do: nil

  # ------------- API de partida -----------------

  def start_link(args), do: GenServer.start_link(__MODULE__, args)
  def add_bot(partida, dificultad), do: GenServer.call(partida, {:add_bot, dificultad})
  def start_game(partida), do: GenServer.call(partida, :start_game)
  def answer(partida, jugador, letra), do: GenServer.call(partida, {:answer, jugador, letra})
  # bot.exs llama a responder/3: es el mismo camino que usa un humano
  def responder(partida, jugador, letra), do: answer(partida, jugador, letra)
  def leave(partida, jugador), do: GenServer.call(partida, {:leave, jugador})
  def estado(partida), do: GenServer.call(partida, :estado)

  # ------------ Callbacks de GenServer -----------------

  @impl true
  def init(args) do
    creador = Map.fetch!(args, :creador)
    cliente = Map.fetch!(args, :cliente)

    # Si el cliente se cae, llega un mensaje :DOWN y se aplica la regla de abandono
    Process.monitor(cliente)

    state = %__MODULE__{
      id: Map.fetch!(args, :id),
      creador: creador,
      tema: Map.fetch!(args, :tema),
      nivel: Map.fetch!(args, :nivel),
      total_preguntas: Map.fetch!(args, :total_preguntas),
      tiempo_pregunta: Map.fetch!(args, :tiempo_pregunta),
      cliente: cliente,
      jugadores: [creador],
      destinos: %{creador => cliente},
      puntajes: %{creador => 0},
      sorteo: Map.get(args, :sorteo, &Trivia.BancoPreguntas.sortear/3),
      registrar: Map.get(args, :registrar, &Trivia.Persistencia.registrar_resultado/1),
      gestor: Map.get(args, :gestor, Trivia.GestorPartidas),
      pausa_ms: Map.get(args, :pausa_ms, @pausa_ms)
    }

    # Con cast, no con call: el gestor está esperando al supervisor y se bloquearía
    if state.gestor, do: GenServer.cast(state.gestor, {:partida_lista, state.id, self()})

    {:ok, state}
  end

  @impl true
  def handle_call({:add_bot, dificultad}, _from, state) do
    cond do
      state.estado != :esperando ->
        {:reply, {:error, :partida_iniciada}, state}

      length(state.jugadores) >= @max_jugadores ->
        {:reply, {:error, :partida_llena}, state}

      dificultad not in [:facil, :medio, :dificil] ->
        {:reply, {:error, :dificultad_invalida}, state}

      true ->
        nombre = "bot_#{map_size(state.bots) + 1}"

        # start_link enlaza el bot a la partida: si ella muere, el bot muere con ella
        {:ok, pid} =
          Trivia.Bot.start_link(%{
            nombre: nombre,
            dificultad: dificultad,
            nivel: state.nivel,
            tiempo_pregunta: state.tiempo_pregunta,
            partida: self()
          })

        state = %{
          state
          | jugadores: state.jugadores ++ [nombre],
            destinos: Map.put(state.destinos, nombre, pid),
            bots: Map.put(state.bots, nombre, pid),
            puntajes: Map.put(state.puntajes, nombre, 0)
        }

        {:reply, {:ok, nombre}, state}
    end
  end

  def handle_call(:estado, _from, state), do: {:reply, state, state}
end
