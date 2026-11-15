#Autor: Carlos Andres

defmodule Trivia.PartidaTest do
  
  use ExUnit.Case

  test "permite agregar un bot cuando hay espacio" do
    estado = %{
      estado: :esperando,
      jugadores: ["carlos"]
    }

    assert Trivia.Partida.puede_agregar_bot?(estado) == true
  end

  test "no permite agregar un bot cuando hay cuatro jugadores" do
    estado = %{
      estado: :esperando,
      jugadores: ["carlos", "ana", "bot_1", "bot_2"]
    }

    assert Trivia.Partida.puede_agregar_bot?(estado) == false
  end

  test "no permite agregar un bot cuando la partida está en curso" do
    estado = %{
      estado: :en_curso,
      jugadores: ["carlos"]
    }

    assert Trivia.Partida.puede_agregar_bot?(estado) == false
  end

  test "no permite agregar un bot cuando la partida está finalizada" do
    estado = %{
      estado: :finalizada,
      jugadores: ["carlos"]
    }

    assert Trivia.Partida.puede_agregar_bot?(estado) == false
  end

  # ==========================================
  # PRUEBAS DE PUEDE_INICIAR?/1
  # ==========================================

  test "permite iniciar cuando hay dos bots y la partida está esperando" do
    estado = %{
      estado: :esperando,
      jugadores: ["carlos", "bot_1", "bot_2"]
    }

    assert Trivia.Partida.puede_iniciar?(estado) == true
  end

  test "no permite iniciar cuando no hay bots" do
    estado = %{
      estado: :esperando,
      jugadores: ["carlos", "ana"]
    }

    assert Trivia.Partida.puede_iniciar?(estado) == false
  end

  test "no permite iniciar cuando solamente hay un bot" do
    estado = %{
      estado: :esperando,
      jugadores: ["carlos", "bot_1"]
    }

    assert Trivia.Partida.puede_iniciar?(estado) == false
  end

  test "no permite iniciar cuando hay dos bots pero la partida está en curso" do
    estado = %{
      estado: :en_curso,
      jugadores: ["carlos", "bot_1", "bot_2"]
    }

    assert Trivia.Partida.puede_iniciar?(estado) == false
  end

  test "no permite iniciar cuando hay dos bots pero la partida está finalizada" do
    estado = %{
      estado: :finalizada,
      jugadores: ["carlos", "bot_1", "bot_2"]
    }

    assert Trivia.Partida.puede_iniciar?(estado) == false
  end
end
