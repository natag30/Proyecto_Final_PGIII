# Autor: Diego Rincon

defmodule Trivia.Partida do
  @moduledoc "
  Módulo que representa una partida de trivia.
  Maneja rondas, temporizador, validación de respuestas, puntaje, abandono y ranking final.
  La lógica de puntaje y validación es pura para poder probarla sin arrancar procesos.
  "

  use GenServer, restart: :transient

  @puntos %{basico: {10, -5}, intermedio: {15, -8}, avanzado: {20, -10}}
  @letras ["A", "B", "C", "D"]
  @max_jugadores 4
  @min_bots 2
  @pausa_ms 3_000
  @tiempo_max_partida_ms 5 * 60 * 1000

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
    :timer_partida,
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
  No modifica nada: una letra inválida no anula la respuesta del jugador.
  Si la respuesta es correcta o incorrecta se decide al cerrar la ronda.
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

  defp normalizar_letra(letra) when is_binary(letra),
    do: letra |> String.trim() |> String.upcase()

  defp normalizar_letra(_), do: nil

  # ----------------- API de partida -----------------

  # alias con los nombres que usa gestor_partidas.ex
  def agregar_bot(partida, dificultad), do: add_bot(partida, dificultad)
  def iniciar(partida), do: start_game(partida)
  def abandonar(partida, jugador), do: leave(partida, jugador)

  def start_link(args), do: GenServer.start_link(__MODULE__, args)
  def add_bot(partida, dificultad), do: GenServer.call(partida, {:add_bot, dificultad})
  def start_game(partida), do: GenServer.call(partida, :start_game)
  def answer(partida, jugador, letra), do: GenServer.call(partida, {:answer, jugador, letra})

  # se llama al bot.exs para que responda: como lo va realizando el jugador, no se valida si es correcta o no, solo si es aceptable

  def responder(partida, jugador, letra), do: answer(partida, jugador, letra)
  def leave(partida, jugador), do: GenServer.call(partida, {:leave, jugador})
  def estado(partida), do: GenServer.call(partida, :estado)
  def puntajes(partida), do: GenServer.call(partida, :puntajes)
  def preguntas(partida), do: GenServer.call(partida, :preguntas)
  def ronda(partida), do: GenServer.call(partida, :ronda)
  def notificar_jugadores(partida, mensaje), do: GenServer.cast(partida, {:notificar, mensaje})

  # ----------------- callbacks de GenServer -----------------

  @impl true
  def init(args) do
    creador = Map.fetch!(args, :creador)
    cliente = Map.get(args, :cliente) || Map.fetch!(args, :pid_receptor)
    # si el cliente se cae, llega un mensaje :DOWN y se aplica la regla de abandono
    Process.monitor(cliente)

    state = %__MODULE__{
      id: Map.fetch!(args, :id),
      creador: creador,
      tema: Map.fetch!(args, :tema),
      nivel: args |> Map.fetch!(:nivel) |> a_nivel(),
      total_preguntas: Map.fetch!(args, :total_preguntas),
      tiempo_pregunta: Map.fetch!(args, :tiempo_pregunta),
      cliente: cliente,
      jugadores: [creador],
      destinos: %{creador => cliente},
      puntajes: %{creador => 0},
      sorteo: Map.get(args, :sorteo, &Trivia.BancoPreguntas.sortear_partida/3),
      registrar: Map.get(args, :registrar, &Trivia.Persistencia.registrar_resultado/1),
      gestor: Map.get(args, :gestor, Trivia.GestorPartidas),
      pausa_ms: Map.get(args, :pausa_ms, @pausa_ms)
    }

    # tiempo máximo de la partida completa
    timer_partida =
      Process.send_after(
        self(),
        :tiempo_agotado,
        Map.get(args, :tiempo_max_partida_ms, @tiempo_max_partida_ms)
      )

    state = %{state | timer_partida: timer_partida}

    # con cast, no con call: el gestor esta esperando al supervisor y se bloquearia
    if state.gestor, do: GenServer.cast(state.gestor, {:registrar_partida, state.id, self()})
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

        # start_link enlaza el bot a la partida: si la partida termina, los bots también
        opciones = %{
          nombre: nombre,
          dificultad: dificultad,
          nivel: state.nivel,
          tiempo_pregunta: state.tiempo_pregunta,
          partida: self()
        }

        {:ok, pid} = Trivia.Bot.start_link(opciones)

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

  def handle_call(:start_game, _from, state) do
    cond do
      state.estado != :esperando ->
        {:reply, {:error, :partida_iniciada}, state}

      map_size(state.bots) < @min_bots ->
        {:reply, {:error, :bots_insuficientes}, state}

      true ->
        case state.sorteo.(state.tema, state.nivel, state.total_preguntas) do
          {:ok, preguntas} ->
            state = abrir_ronda(%{state | estado: :en_curso, preguntas: preguntas}, 1)
            {:reply, :ok, state}

          {:error, motivo} ->
            {:reply, {:error, motivo}, state}
        end
    end
  end

  def handle_call({:answer, jugador, letra}, _from, state) do
    with :ok <- participa?(state, jugador),
         {:ok, letra} <- validar_respuesta(state.ronda, jugador, letra) do
      restantes = segundos_restantes(state.ronda.inicio_ms, state.tiempo_pregunta)
      respuestas = Map.put(state.ronda.respuestas, jugador, {letra, restantes})
      state = %{state | ronda: %{state.ronda | respuestas: respuestas}}

      # la ronda se cierra antes de tiempo si ya respondieron todos
      state = if todos_respondieron?(state), do: cerrar_ronda(state), else: state
      {:reply, {:ok, :registrada}, state}
    else
      {:error, _motivo} = error -> {:reply, error, state}
    end
  end

  def handle_call({:leave, jugador}, _from, state) do
    cond do
      jugador != state.creador ->
        {:reply, {:error, :no_participa}, state}

      state.estado == :esperando ->
        if state.gestor, do: Trivia.GestorPartidas.partida_terminada(state.id)
        {:stop, :normal, :ok, state}

      true ->
        {:reply, :ok, terminar_por_abandono(state)}
    end
  end

  def handle_call(:estado, _from, state), do: {:reply, state, state}
  def handle_call(:puntajes, _from, state), do: {:reply, state.puntajes, state}
  def handle_call(:preguntas, _from, state), do: {:reply, state.preguntas, state}
  def handle_call(:ronda, _from, state), do: {:reply, state.ronda, state}

  @impl true
  def handle_cast({:notificar, mensaje}, state) do
    notificar(state, mensaje)
    {:noreply, state}
  end

  @impl true
  # solo cierra si el temporizador es de la ronda abierta (ignora los atrasados)
  def handle_info({:vence_ronda, n}, %{ronda: %{abierta: true, numero: n}} = state),
    do: {:noreply, cerrar_ronda(state)}

  def handle_info({:vence_ronda, _n}, state), do: {:noreply, state}

  def handle_info({:siguiente_ronda, n}, %{estado: :en_curso, pregunta_actual: n} = state),
    do: {:noreply, abrir_ronda(state, n + 1)}

  def handle_info({:siguiente_ronda, _n}, state), do: {:noreply, state}

  def handle_info(:terminar, state) do
    if state.gestor, do: Trivia.GestorPartidas.partida_terminada(state.id)
    {:stop, :normal, state}
  end

  # se agotó el tiempo máximo de la partida
  def handle_info(:tiempo_agotado, %{estado: :en_curso} = state),
    do: {:noreply, terminar_por_abandono(state)}

  def handle_info(:tiempo_agotado, %{estado: :esperando} = state) do
    if state.gestor, do: Trivia.GestorPartidas.partida_terminada(state.id)
    {:stop, :normal, state}
  end

  def handle_info(:tiempo_agotado, state), do: {:noreply, state}

  # el cliente se cayo o se cerro: se aplica la regla de abandono (seccion 6.5)
  def handle_info({:DOWN, _ref, :process, pid, _razon}, %{cliente: pid} = state) do
    case state.estado do
      :esperando ->
        if state.gestor, do: Trivia.GestorPartidas.partida_terminada(state.id)
        {:stop, :normal, state}

      _ ->
        {:noreply, terminar_por_abandono(state)}
    end
  end

  def handle_info(_otro, state), do: {:noreply, state}

  # ----------------- rondas -----------------

  defp abrir_ronda(state, numero) do
    pregunta = Enum.at(state.preguntas, numero - 1)
    # el numero de ronda viaja en el mensaje para ignorar temporizadores atrasados
    timer = Process.send_after(self(), {:vence_ronda, numero}, state.tiempo_pregunta * 1000)

    ronda = %{
      abierta: true,
      numero: numero,
      pregunta: pregunta,
      inicio_ms: System.monotonic_time(:millisecond),
      respuestas: %{},
      timer: timer
    }

    state = %{state | pregunta_actual: numero, ronda: ronda}
    enviar_pregunta(state, pregunta, numero)
    state
  end

  defp cerrar_ronda(%{ronda: %{abierta: true} = ronda} = state) do
    Process.cancel_timer(ronda.timer)

    correcta = campo(ronda.pregunta, :respuesta)
    nivel = a_nivel(campo(ronda.pregunta, :nivel))

    puntos =
      Map.new(state.jugadores, fn jugador ->
        respuesta = Map.get(ronda.respuestas, jugador)
        {jugador, puntos_de(respuesta, correcta, nivel, state.tiempo_pregunta)}
      end)

    totales = Map.merge(state.puntajes, puntos, fn _j, total, extra -> total + extra end)
    state = %{state | puntajes: totales, ronda: %{ronda | abierta: false}}

    notificar(
      state,
      {:cierre_ronda,
       %{numero: ronda.numero, correcta: correcta, puntos_ronda: puntos, totales: totales}}
    )

    if ronda.numero >= state.total_preguntas do
      finalizar(state)
    else
      # durante la pausa no hay ronda abierta: una respuesta tardia se rechaza
      Process.send_after(self(), {:siguiente_ronda, ronda.numero}, state.pausa_ms)
      state
    end
  end

  defp cerrar_ronda(state), do: state

  defp puntos_de(nil, _correcta, nivel, tiempo),
    do: puntos_ronda(:sin_responder, nivel, 0, tiempo)

  defp puntos_de({letra, restantes}, correcta, nivel, tiempo) do
    resultado = if letra == correcta, do: :correcto, else: :incorrecto
    puntos_ronda(resultado, nivel, restantes, tiempo)
  end

  defp segundos_restantes(inicio_ms, tiempo) do
    transcurridos = (System.monotonic_time(:millisecond) - inicio_ms) / 1000
    max(tiempo - transcurridos, 0)
  end

  defp todos_respondieron?(state),
    do: map_size(state.ronda.respuestas) >= length(state.jugadores)

  defp participa?(state, jugador),
    do: if(jugador in state.jugadores, do: :ok, else: {:error, :no_participa})

  # ----------------- fin y abandono -----------------

  defp terminar_por_abandono(%{estado: :en_curso} = state) do
    ronda = state.ronda

    state =
      if ronda && ronda.abierta do
        Process.cancel_timer(ronda.timer)
        %{state | ronda: %{ronda | abierta: false}}
      else
        state
      end

    finalizar(state)
  end

  defp terminar_por_abandono(state), do: state

  defp finalizar(state) do
    if state.timer_partida, do: Process.cancel_timer(state.timer_partida)
    ranking = Enum.sort_by(state.puntajes, fn {jugador, puntos} -> {-puntos, jugador} end)
    {_, mejor} = hd(ranking)

    resultado = %{
      id: state.id,
      tema: state.tema,
      nivel: state.nivel,
      ranking: ranking,
      ganadores: for({jugador, ^mejor} <- ranking, do: jugador),
      fecha: DateTime.utc_now()
    }

    notificar(state, {:fin_partida, resultado})
    state.registrar.(resultado)

    # margen para que las notificaciones salgan antes de que muera el proceso
    Process.send_after(self(), :terminar, 200)
    %{state | estado: :finalizada}
  end

  # ----------------- notificaciones -----------------

  defp notificar(state, mensaje),
    do: Enum.each(state.destinos, fn {_jugador, pid} -> send(pid, mensaje) end)

  defp enviar_pregunta(state, pregunta, numero) do
    nivel = a_nivel(campo(pregunta, :nivel))

    publica = %{
      numero: numero,
      total: state.total_preguntas,
      tema: state.tema,
      nivel: nivel,
      enunciado: campo(pregunta, :enunciado),
      opciones: campo(pregunta, :opciones),
      tiempo: state.tiempo_pregunta
    }

    Enum.each(state.destinos, fn {jugador, pid} ->
      if Map.has_key?(state.bots, jugador) do
        # solo los bots (que viven en el servidor) reciben la respuesta correcta
        send(
          pid,
          {:nueva_ronda,
           %{
             numero: numero,
             correcta: campo(pregunta, :respuesta),
             nivel: nivel,
             tiempo: state.tiempo_pregunta
           }}
        )
      else
        send(pid, {:pregunta, publica})
      end
    end)
  end

  # ----------------- auxiliares -----------------

  # acepta preguntas con llaves atom o string (segun como cargue C el JSON)
  defp campo(pregunta, llave),
    do: Map.get(pregunta, llave) || Map.get(pregunta, Atom.to_string(llave))

  defp a_nivel(nivel) when nivel in [:basico, :intermedio, :avanzado], do: nivel
  defp a_nivel(nivel) when is_binary(nivel), do: String.to_existing_atom(nivel)
end
