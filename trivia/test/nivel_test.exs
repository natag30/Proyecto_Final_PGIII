defmodule Trivia.NivelTest do
  use ExUnit.Case, async: true

  alias Trivia.Nivel

  describe "nivel_por_puntaje/1" do
    test "clasifica puntajes en los límites de cada nivel" do
      assert Nivel.nivel_por_puntaje(0) == :basico
      assert Nivel.nivel_por_puntaje(59) == :basico
      assert Nivel.nivel_por_puntaje(60) == :intermedio
      assert Nivel.nivel_por_puntaje(179) == :intermedio
      assert Nivel.nivel_por_puntaje(180) == :avanzado
      assert Nivel.nivel_por_puntaje(100_000) == :avanzado
    end
  end

  describe "puntaje_en_tema/3" do
    test "suma solo los puntajes del usuario en el tema indicado" do
      historial = [
        %{
          tema: "ciencia",
          jugadores: [%{usuario: "ana", puntaje: 40}, %{usuario: "luis", puntaje: 10}]
        },
        %{tema: "ciencia", jugadores: [%{usuario: "ana", puntaje: 30}]},
        %{tema: "historia", jugadores: [%{usuario: "ana", puntaje: 100}]}
      ]

      assert Nivel.puntaje_en_tema(historial, "ana", "ciencia") == 70
    end

    test "devuelve cero si el usuario no tiene partidas en el tema" do
      historial = [%{tema: "ciencia", jugadores: [%{usuario: "ana", puntaje: 40}]}]

      assert Nivel.puntaje_en_tema(historial, "luis", "ciencia") == 0
    end
  end

  describe "nivel_en_tema/3" do
    test "devuelve el nivel básico cuando el historial está vacío" do
      assert Nivel.nivel_en_tema([], "ana", "ciencia") == :basico
    end

    test "determina el nivel con el puntaje acumulado del tema" do
      historial = [
        %{tema: "ciencia", jugadores: [%{usuario: "ana", puntaje: 40}]},
        %{tema: "ciencia", jugadores: [%{usuario: "ana", puntaje: 30}]}
      ]

      assert Nivel.nivel_en_tema(historial, "ana", "ciencia") == :intermedio
    end
  end

  describe "reparto/2" do
    test "reparte diez preguntas según el nivel del jugador" do
      assert Nivel.reparto(:basico, 10) == %{basico: 7, intermedio: 3, avanzado: 0}
      assert Nivel.reparto(:intermedio, 10) == %{basico: 2, intermedio: 6, avanzado: 2}
      assert Nivel.reparto(:avanzado, 10) == %{basico: 0, intermedio: 3, avanzado: 7}
    end

    test "asigna al nivel del jugador el resto de un reparto no exacto" do
      assert Nivel.reparto(:basico, 7) == %{basico: 5, intermedio: 2, avanzado: 0}
      assert Nivel.reparto(:intermedio, 7) == %{basico: 1, intermedio: 5, avanzado: 1}
      assert Nivel.reparto(:avanzado, 7) == %{basico: 0, intermedio: 2, avanzado: 5}
    end

    test "la suma de las cantidades siempre es el total" do
      for nivel <- [:basico, :intermedio, :avanzado], total <- 0..20 do
        assert Nivel.reparto(nivel, total) |> Map.values() |> Enum.sum() == total
      end
    end
  end
end
