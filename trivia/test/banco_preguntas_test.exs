defmodule Trivia.BancoPreguntasTest do
  use ExUnit.Case

  alias Trivia.BancoPreguntas

  defp banco do
    [
      %{
        tema: "ciencia",
        nivel: :basico,
        enunciado: "B1",
        opciones: %{"A" => "x"},
        respuesta: "A"
      },
      %{
        tema: "ciencia",
        nivel: :basico,
        enunciado: "B2",
        opciones: %{"A" => "x"},
        respuesta: "A"
      },
      %{
        tema: "ciencia",
        nivel: :intermedio,
        enunciado: "I1",
        opciones: %{"A" => "x"},
        respuesta: "A"
      },
      %{
        tema: "ciencia",
        nivel: :intermedio,
        enunciado: "I2",
        opciones: %{"A" => "x"},
        respuesta: "A"
      },
      %{
        tema: "ciencia",
        nivel: :intermedio,
        enunciado: "I3",
        opciones: %{"A" => "x"},
        respuesta: "A"
      },
      %{
        tema: "ciencia",
        nivel: :avanzado,
        enunciado: "A1",
        opciones: %{"A" => "x"},
        respuesta: "A"
      },
      %{
        tema: "ciencia",
        nivel: :avanzado,
        enunciado: "A2",
        opciones: %{"A" => "x"},
        respuesta: "A"
      },
      %{
        tema: "historia",
        nivel: :basico,
        enunciado: "H1",
        opciones: %{"A" => "x"},
        respuesta: "A"
      }
    ]
  end

  describe "publica/1" do
    test "elimina la respuesta y conserva los datos públicos" do
      pregunta = hd(banco())
      publicada = BancoPreguntas.publica(pregunta)

      refute Map.has_key?(publicada, :respuesta)

      assert Map.take(publicada, [:tema, :enunciado, :opciones]) ==
               Map.take(pregunta, [:tema, :enunciado, :opciones])
    end
  end

  describe "hay_suficientes?/3" do
    test "devuelve verdadero cuando hay suficientes preguntas de cada nivel" do
      reparto = %{basico: 2, intermedio: 1, avanzado: 0}

      assert BancoPreguntas.hay_suficientes?(banco(), "ciencia", reparto)
    end

    test "devuelve falso si falta una pregunta de un nivel solicitado" do
      reparto = %{basico: 3, intermedio: 0, avanzado: 0}

      refute BancoPreguntas.hay_suficientes?(banco(), "ciencia", reparto)
    end

    test "devuelve falso para un tema inexistente con cantidad solicitada" do
      reparto = %{basico: 1, intermedio: 0, avanzado: 0}

      refute BancoPreguntas.hay_suficientes?(banco(), "geografía", reparto)
    end
  end

  describe "sortear/3" do
    test "devuelve la cantidad solicitada por nivel y solo del tema indicado" do
      reparto = %{basico: 1, intermedio: 1, avanzado: 0}
      resultado = BancoPreguntas.sortear(banco(), "ciencia", reparto)

      assert length(resultado) == 2
      assert Enum.all?(resultado, &(&1.tema == "ciencia"))
      assert Enum.count(resultado, &(&1.nivel == :basico)) == 1
      assert Enum.count(resultado, &(&1.nivel == :intermedio)) == 1
      assert Enum.count(resultado, &(&1.nivel == :avanzado)) == 0
    end

    test "no repite preguntas y ordena los niveles de básico a avanzado" do
      reparto = %{basico: 2, intermedio: 2, avanzado: 2}
      resultado = BancoPreguntas.sortear(banco(), "ciencia", reparto)

      assert Enum.uniq(resultado) == resultado

      assert Enum.map(resultado, & &1.nivel) ==
               [:basico, :basico, :intermedio, :intermedio, :avanzado, :avanzado]
    end
  end

  describe "validar_tema/3" do
    setup do
      start_supervised!({BancoPreguntas, preguntas: banco()})
      :ok
    end

    test "devuelve :ok cuando el reparto alcanza" do
      assert BancoPreguntas.validar_tema("ciencia", :basico, 2) == :ok
    end

    test "devuelve un error cuando el reparto excede las preguntas disponibles" do
      assert BancoPreguntas.validar_tema("ciencia", :basico, 3) ==
               {:error, :tema_no_disponible}
    end
  end

  describe "sortear_partida/3" do
    setup do
      start_supervised!({BancoPreguntas, preguntas: banco()})
      :ok
    end

    test "devuelve una lista del tamaño solicitado" do
      assert {:ok, resultado} = BancoPreguntas.sortear_partida("ciencia", :basico, 2)

      assert length(resultado) == 2
      assert Enum.all?(resultado, &(&1.tema == "ciencia"))
      assert Enum.count(resultado, &(&1.nivel == :basico)) == 2
    end

    test "reparte las preguntas entre varios niveles según el nivel del jugador" do
      assert {:ok, resultado} = BancoPreguntas.sortear_partida("ciencia", :intermedio, 5)

      assert length(resultado) == 5
      assert Enum.all?(resultado, &(&1.tema == "ciencia"))
      assert Enum.count(resultado, &(&1.nivel == :basico)) == 1
      assert Enum.count(resultado, &(&1.nivel == :intermedio)) == 3
      assert Enum.count(resultado, &(&1.nivel == :avanzado)) == 1
    end

    test "devuelve un error cuando el tema no tiene suficientes preguntas" do
      assert BancoPreguntas.sortear_partida("ciencia", :basico, 10) ==
               {:error, :tema_no_disponible}
    end
  end
end
