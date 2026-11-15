defmodule Trivia.ClienteTest do
  use ExUnit.Case, async: true

  test "acepta crear una partida con preguntas y tiempo positivos" do
    assert {:ok, {:create_game, "ciencia", 3, 30}} =
             Trivia.Cliente.parsear_comando("create_game tema=ciencia preguntas=3 tiempo=30")
  end

  test "rechaza crear partidas con preguntas o tiempo no positivos" do
    for comando <- [
          "create_game tema=ciencia preguntas=0 tiempo=30",
          "create_game tema=ciencia preguntas=-1 tiempo=30",
          "create_game tema=ciencia preguntas=3 tiempo=0",
          "create_game tema=ciencia preguntas=3 tiempo=-5"
        ] do
      assert {:error, :parametros_invalidos} = Trivia.Cliente.parsear_comando(comando)
    end
  end
end
