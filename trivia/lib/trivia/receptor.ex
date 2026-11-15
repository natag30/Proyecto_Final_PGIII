# Autora: Natalia García

defmodule Trivia.Receptor do
  @moduledoc """
  Módulo que representa el receptor de mensajes de la aplicación Trivia.
  Contiene funciones para manejar los mensajes recibidos del servidor y procesarlos según el tipo de mensaje.
  """

  use GenServer

  @doc """
  Arranca el receptor de mensajes. Devuelve {:ok, pid}; ese pid se entrega al servidor al crear la partida.
  """
  def iniciar, do: GenServer.start_link(__MODULE__, nil)

  @impl true
  def init(nil), do: {:ok, nil}

  @doc """
  Formatea una pregunta para mostrarla al usuario.
  Recibe un mapa con los datos de la pregunta y devuelve un string formateado.
  """
  def formatear_pregunta(datos) do
    encabezado =
      "═══ Pregunta #{datos.numero} de #{datos.total} - #{String.capitalize(datos.tema)} - Nivel #{nombre_nivel(datos.nivel)} ═══"

    opciones =
      datos.opciones
      |> Map.to_list()
      |> Enum.sort()
      |> Enum.map_join("      ", fn {letra, texto} -> "#{letra}) #{texto}" end)

    Enum.join(
      [
        encabezado,
        datos.enunciado,
        "  " <> opciones,
        "Tiempo: #{datos.tiempo} segundos"
      ],
      "\n"
    )
  end

  @doc """
  Formatea el cierre de una ronda junto con los puntajes de sus jugadores.
  """
  def formatear_fin_ronda(datos, opciones) do
    cabecera = "Respuesta correcta: " <> texto_correcta(datos.correcta, opciones)

    lineas =
      datos.puntos_ronda
      |> Enum.sort()
      |> Enum.map(fn {jugador, puntos} ->
        "  " <>
          String.pad_trailing(jugador, 8) <>
          String.pad_leading(con_signo(puntos), 4) <>
          "   (total #{Map.fetch!(datos.totales, jugador)})"
      end)

    Enum.join([cabecera | lineas], "\n")
  end

  @doc """
  Formatea el ranking y los ganadores de una partida terminada.
  """
  def formatear_fin_partida(datos) do
    encabezado =
      "═══ Fin de la partida #{datos.id} (#{datos.tema}, nivel #{nombre_nivel(datos.nivel)}) ═══"

    titulos =
      String.pad_trailing("#", 5) <>
        String.pad_trailing("Jugador", 10) <>
        String.pad_leading("Puntaje", 7)

    filas =
      datos.ranking
      |> Enum.with_index(1)
      |> Enum.map(fn {{jugador, puntaje}, posicion} ->
        String.pad_trailing("#{posicion}", 5) <>
          String.pad_trailing(jugador, 10) <>
          String.pad_leading("#{puntaje}", 7)
      end)

    Enum.join(
      [encabezado, titulos | filas] ++ [linea_ganador(datos.ganadores)],
      "\n"
    )
  end

  @doc """
  Imprime en pantalla una notificación de la partida. Es la única función del módulo que escribe en la terminal.
  """
  def mostrar({:pregunta, datos}, _opciones) do
    IO.puts(formatear_pregunta(datos))
    IO.write("Respuesta > ")
  end

  def mostrar({:cierre_ronda, datos}, opciones) do
    IO.puts("\n" <> formatear_fin_ronda(datos, opciones))
  end

  def mostrar({:fin_partida, datos}, _opciones) do
    IO.puts("\n" <> formatear_fin_partida(datos))
  end

  def mostrar({:partida_reiniciada, id}, _opciones) do
    IO.puts(
      "\nLa partida #{id} falló y se reinició sin su progreso. Agrega los bots y ejecuta start_game para jugar de nuevo."
    )
  end

  # Callback que muestra los mensajes y actualiza las opciones de la pregunta actual.
  @impl true
  def handle_info({:pregunta, datos} = mensaje, opciones) do
    mostrar(mensaje, opciones)
    {:noreply, datos.opciones}
  end

  def handle_info({:cierre_ronda, _datos} = mensaje, opciones) do
    mostrar(mensaje, opciones)
    {:noreply, opciones}
  end

  def handle_info({:fin_partida, _datos} = mensaje, opciones) do
    mostrar(mensaje, opciones)
    {:noreply, opciones}
  end

  def handle_info({:partida_reiniciada, _id} = mensaje, opciones) do
    mostrar(mensaje, opciones)
    {:noreply, opciones}
  end

  def handle_info(_otro, opciones), do: {:noreply, opciones}

  # Función privada que devuelve el nombre del nivel en formato legible.
  defp nombre_nivel(:basico), do: "básico"
  defp nombre_nivel(:intermedio), do: "intermedio"
  defp nombre_nivel(:avanzado), do: "avanzado"

  defp texto_correcta(correcta, nil), do: "#{correcta}"

  defp texto_correcta(correcta, opciones) when is_map(opciones) do
    "#{correcta}) #{Map.get(opciones, correcta)}"
  end

  defp con_signo(puntos) when puntos > 0, do: "+#{puntos}"
  defp con_signo(puntos), do: "#{puntos}"

  defp linea_ganador([ganador]), do: "Ganador: #{ganador}"

  defp linea_ganador(ganadores) do
    "Ganadores (empate): #{Enum.join(ganadores, ", ")}"
  end
end
