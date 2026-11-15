defmodule Trivia.BotTest do
  use ExUnit.Case, async: true

  @letras ["A", "B", "C", "D"]

  test "decide sin elegir la opcion seleccionada por el cliente" do
    for excluida <- @letras, _intento <- 1..20 do
      {letra, retardo_ms} =
        Trivia.Bot.decidir(:facil, :basico, "A", 0, excluida)

      assert letra in @letras
      refute letra == excluida
      assert retardo_ms == 0
    end
  end
end
