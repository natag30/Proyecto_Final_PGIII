# Autor: Diego Rincon

defmodule Trivia.Bot do
  @moduledoc "
  Jugador automatico. tiene su propio proceso y recibe las mismas notificaciones que el el usuario,
  tiene ventaja por que sabe la respuesta correcta ya que es parte del servidor
  responde con retraso ya que estamos utilizando process.send_after.
  "

  use GenServer

  @letras ["A", "B", "C", "D"]
  @aciertos %{
    facil: %{basico: 0.4, intermedio: 0.3, avanzado: 0.2},
    medio: %{basico: 0.5, intermedio: 0.4, avanzado: 0.3},
    dificil: %{basico: 0.8, intermedio: 0.7, avanzado: 0.6}
  }

  # Ventaja de respuesta para la fraccion de tiempo segun la dificultad
  @ventaja %{facil: {0.4, 0.9}, medio: {0.25, 0.65}, dificil: {0.1, 0.4}}

  # ----------------funciones pruebas -----------------------

  @doc "probabilidad de aciertos segun la dificultad y nivel de pregunta"
  def probabilidad_aciertos(dificultad, nivel) do
    Map.get(@aciertos[dificultad], nivel)
  end

  @doc " Devuelve {letra, retardo_ms}. el retardo cae dentro de la ventana de la dificultad."
  def decidir(dificultad, nivel, correcta, tiempo_pregunta) do
    {ventaja_min, ventaja_max} = @ventaja[dificultad]
    retardo = :rand.uniform() * (ventaja_max - ventaja_min) + ventaja_min
    retardo_ms = trunc(retardo * tiempo_pregunta * 1000)

    if :rand.uniform() <= probabilidad_aciertos(dificultad, nivel) do
      {correcta, retardo_ms}
    else
      incorrectas = @letras -- [correcta]
      letra_incorrecta = Enum.random(incorrectas)
      {letra_incorrecta, retardo_ms}
    end
  end

  def elegir_letra(correcta, true), do: correcta
  def elegir_letra(correcta, false), do: Enum.random(@letras -- [correcta])

  # -------- procesos -------------

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  @impl true
  def init(%{
        nombre: nombre,
        dificultad: dificultad,
        nivel: nivel,
        tiempo_pregunta: tiempo_pregunta,
        partida: partida
      }) do
    {:ok,
     %{
       nombre: nombre,
       dificultad: dificultad,
       nivel: nivel,
       tiempo_pregunta: tiempo_pregunta,
       partida: partida,
       ronda: nil
     }}
  end

  @impl true
  def handle_info({:nueva_ronda, ronda}, state) do
    # decide la ronda y timepo que trae su propio nivel
    nivel = Map.get(ronda, :nivel, state.nivel)
    tiempo = Map.get(ronda, :tiempo, state.tiempo_pregunta)

    # decide la letra a responder y el retardo segun la dificultad y nivel

    {letra, retardo_ms} = decidir(state.dificultad, nivel, ronda.correcta, tiempo)

    # envia la respuesta despues del retardo y definiendo  aque ronda pertenece

    Process.send_after(self(), {:responder, ronda.numero, letra}, retardo_ms)
    {:noreply, %{state | ronda: ronda.numero}}
  end

  # solo responde si sigue en la misma ronda en la que decidio responder, si ya paso a otra ronda no responde
  def handle_info({:responder, numero, letra}, %{ronda: numero} = state) do
    # envia la respuesta a la partida
    Trivia.Partida.responder(state.partida, state.nombre, letra)
    {:noreply, state}
  end

  def handle_info(_otro, state), do: {:noreply, state}
end
