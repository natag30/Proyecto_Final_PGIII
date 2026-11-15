defmodule Trivia.ReceptorTest do
  use ExUnit.Case, async: true

  alias Trivia.Receptor

  defp pregunta do
    %{
      numero: 1,
      total: 5,
      tema: "ciencia",
      nivel: :basico,
      enunciado: "¿Cuál es el planeta más grande?",
      opciones: %{"D" => "Neptuno", "A" => "Marte", "C" => "Saturno", "B" => "Júpiter"},
      tiempo: 10
    }
  end

  describe "formatear_pregunta/1" do
    test "el encabezado lleva número, total, tema con mayúscula y nivel en español" do
      lineas = pregunta() |> Receptor.formatear_pregunta() |> String.split("\n")

      assert String.contains?(hd(lineas), "Pregunta 1 de 5")
      assert String.contains?(hd(lineas), "Ciencia")
      assert String.contains?(hd(lineas), "Nivel básico")
    end

    test "las opciones salen ordenadas por letra aunque el mapa las traiga desordenadas" do
      linea_opciones =
        pregunta() |> Receptor.formatear_pregunta() |> String.split("\n") |> Enum.at(2)

      assert linea_opciones == "  A) Marte      B) Júpiter      C) Saturno      D) Neptuno"
    end

    test "termina con el tiempo en segundos" do
      ultima_linea =
        pregunta() |> Receptor.formatear_pregunta() |> String.split("\n") |> List.last()

      assert ultima_linea == "Tiempo: 10 segundos"
    end

    test "traduce los tres niveles" do
      for {nivel, nombre} <- [
            {:basico, "básico"},
            {:intermedio, "intermedio"},
            {:avanzado, "avanzado"}
          ] do
        datos = %{pregunta() | nivel: nivel}

        assert datos |> Receptor.formatear_pregunta() |> String.contains?("Nivel #{nombre}")
      end
    end
  end

  describe "formatear_fin_ronda/2" do
    test "muestra la letra y el texto de la respuesta correcta" do
      lineas =
        cierre_ronda() |> Receptor.formatear_fin_ronda(%{"B" => "Júpiter"}) |> String.split("\n")

      assert hd(lineas) == "Respuesta correcta: B) Júpiter"
    end

    test "sin opciones muestra solo la letra" do
      lineas = cierre_ronda() |> Receptor.formatear_fin_ronda(nil) |> String.split("\n")

      assert hd(lineas) == "Respuesta correcta: B"
    end

    test "los puntajes tienen signo y los jugadores están ordenados con sus totales" do
      lineas =
        cierre_ronda() |> Receptor.formatear_fin_ronda(%{"B" => "Júpiter"}) |> String.split("\n")

      assert Enum.slice(lineas, 1, 2) == [
               "  ana      +15   (total 25)",
               "  bot_1     -5   (total 0)"
             ]
    end
  end

  describe "formatear_fin_partida/1" do
    test "el encabezado lleva id, tema y nivel" do
      lineas = cierre_partida() |> Receptor.formatear_fin_partida() |> String.split("\n")

      assert hd(lineas) == "═══ Fin de la partida 1 (ciencia, nivel básico) ═══"
    end

    test "las filas llevan posición, jugador y puntaje en el orden recibido" do
      lineas = cierre_partida() |> Receptor.formatear_fin_partida() |> String.split("\n")

      assert Enum.slice(lineas, 1, 3) == [
               "#    Jugador   Puntaje",
               "1    ana            40",
               "2    bot_1          20"
             ]
    end

    test "muestra el ganador único" do
      ultima_linea =
        cierre_partida()
        |> Receptor.formatear_fin_partida()
        |> String.split("\n")
        |> List.last()

      assert ultima_linea == "Ganador: ana"
    end

    test "muestra los ganadores empatados" do
      datos = %{cierre_partida() | ganadores: ["ana", "luis"]}

      ultima_linea =
        datos
        |> Receptor.formatear_fin_partida()
        |> String.split("\n")
        |> List.last()

      assert ultima_linea == "Ganadores (empate): ana, luis"
    end
  end

  defp cierre_ronda do
    %{
      correcta: "B",
      puntos_ronda: %{"bot_1" => -5, "ana" => 15},
      totales: %{"ana" => 25, "bot_1" => 0}
    }
  end

  defp cierre_partida do
    %{
      id: 1,
      tema: "ciencia",
      nivel: :basico,
      ranking: [{"ana", 40}, {"bot_1", 20}],
      ganadores: ["ana"]
    }
  end
end
