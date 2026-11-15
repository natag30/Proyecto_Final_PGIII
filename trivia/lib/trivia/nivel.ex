defmodule Trivia.Nivel do
  @doc """
  Función que determina el nivel de un jugador basado en su puntaje total.
  Recibe el puntaje total del jugador y devuelve un átomo que representa su nivel:
  - :basico para puntajes menores a 60
  - :intermedio para puntajes entre 60 y 179
  - :avanzado para puntajes de 180 o más
  """
  def nivel_por_puntaje(puntaje) when puntaje < 60, do: :basico
  def nivel_por_puntaje(puntaje) when puntaje < 180, do: :intermedio
  def nivel_por_puntaje(_puntaje), do: :avanzado

  @doc """
  Función que calcula el puntaje total de un usuario en un tema específico.
  Recibe el historial de partidas, el nombre del usuario y el tema, y devuelve
  la suma de los puntajes obtenidos por el usuario en todas las partidas de ese tema
  """
  def puntaje_en_tema(historial, usuario, tema) do
    historial
    |> Enum.filter(fn partida -> partida.tema == tema end)
    |> Enum.flat_map(fn partida -> partida.jugadores end)
    |> Enum.filter(fn jugador -> jugador.usuario == usuario end)
    |> Enum.map(fn jugador -> jugador.puntaje end)
    |> Enum.sum()
  end

  @doc """
  Función que determina el nivel de un jugador en un tema específico.
  Recibe el historial de partidas, el nombre del usuario y el tema, y devuelve
  el nivel del jugador basado en su puntaje total en ese tema.
  """
  def nivel_en_tema(historial, usuario, tema) do
    puntaje = puntaje_en_tema(historial, usuario, tema)
    nivel_por_puntaje(puntaje)
  end

  @doc """
  Distribuye el total de preguntas entre niveles según el nivel del jugador.
  Las preguntas restantes se asignan al nivel del jugador.
  """
  def reparto(:basico, total) do
    repartir_preguntas(total, :basico, %{intermedio: 30, avanzado: 0})
  end

  def reparto(:intermedio, total) do
    repartir_preguntas(total, :intermedio, %{basico: 20, avanzado: 20})
  end

  def reparto(:avanzado, total) do
    repartir_preguntas(total, :avanzado, %{basico: 0, intermedio: 30})
  end

  # Función privada que reparte las preguntas entre los niveles según los porcentajes dados
  defp repartir_preguntas(total, nivel_jugador, porcentajes) do
    cantidades =
      Map.new(porcentajes, fn {nivel, porcentaje} ->
        {nivel, div(total * porcentaje, 100)}
      end)

    cantidad_nivel_jugador = total - Enum.sum(Map.values(cantidades))
    Map.put(cantidades, nivel_jugador, cantidad_nivel_jugador)
  end
end
