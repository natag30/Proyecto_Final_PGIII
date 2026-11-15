# Autor: Carlos Andres

defmodule Trivia.PartidaTest do
  use ExUnit.Case, async: false

  @pregunta %{
    nivel: :basico,
    enunciado: "Pregunta de prueba",
    opciones: %{"A" => "Correcta", "B" => "Incorrecta", "C" => "Incorrecta", "D" => "Incorrecta"},
    respuesta: "A"
  }

  setup do
    argumentos = %{
      id: "P-test",
      creador: "carlos",
      tema: "ciencia",
      nivel: :basico,
      total_preguntas: 1,
      tiempo_pregunta: 30,
      cliente: self(),
      gestor: nil,
      sorteo: fn _tema, _nivel, _total -> {:ok, [@pregunta]} end,
      registrar: fn _resultado -> :ok end,
      tiempo_max_partida_ms: 60_000
    }

    {:ok, partida} = Trivia.Partida.start_link(argumentos)

    on_exit(fn ->
      if Process.alive?(partida) do
        bots = Trivia.Partida.estado(partida).bots |> Map.values()
        GenServer.stop(partida, :normal)

        Enum.each(bots, fn bot ->
          if Process.alive?(bot), do: Process.exit(bot, :kill)
        end)
      end
    end)

    {:ok, partida: partida}
  end

  test "agrega un bot cuando hay espacio", %{partida: partida} do
    assert {:ok, "bot_1"} = Trivia.Partida.add_bot(partida, :facil)
    assert "bot_1" in Trivia.Partida.estado(partida).jugadores
  end

  test "rechaza una dificultad inválida", %{partida: partida} do
    assert {:error, :dificultad_invalida} = Trivia.Partida.add_bot(partida, :experto)
  end

  test "rechaza agregar bots cuando se alcanza el máximo de jugadores", %{partida: partida} do
    assert {:ok, "bot_1"} = Trivia.Partida.add_bot(partida, :facil)
    assert {:ok, "bot_2"} = Trivia.Partida.add_bot(partida, :medio)
    assert {:ok, "bot_3"} = Trivia.Partida.add_bot(partida, :dificil)
    assert {:error, :partida_llena} = Trivia.Partida.add_bot(partida, :facil)
  end

  test "requiere dos bots para iniciar y no admite agregar más después", %{partida: partida} do
    assert {:error, :bots_insuficientes} = Trivia.Partida.start_game(partida)

    assert {:ok, "bot_1"} = Trivia.Partida.add_bot(partida, :facil)
    assert {:ok, "bot_2"} = Trivia.Partida.add_bot(partida, :medio)
    assert :ok = Trivia.Partida.start_game(partida)
    assert {:error, :partida_iniciada} = Trivia.Partida.add_bot(partida, :dificil)
  end

  test "crear una partida registra su proceso sin tumbar al gestor" do
    on_exit(fn -> detener_servicios() end)
    assert :ok = Trivia.Servidor.iniciar()

    usuario = "integracion_#{System.unique_integer([:positive])}"

    assert {:ok, %{id: id}} =
             Trivia.GestorPartidas.crear(usuario, self(), "ciencia", 1, 30)

    gestor = Process.whereis(Trivia.GestorPartidas)
    assert is_pid(gestor)
    assert Process.alive?(gestor)
    assert {:ok, partida} = Trivia.GestorPartidas.partida_de(usuario)
    assert Process.alive?(partida)
    assert Trivia.Partida.estado(partida).id == id
  end

  defp detener_servicios do
    [
      Trivia.Servidor,
      Trivia.GestorPartidas,
      Trivia.SupervisorPartidas,
      Trivia.GestorJugadores,
      Trivia.BancoPreguntas,
      Trivia.Persistencia
    ]
    |> Enum.each(fn nombre ->
      case Process.whereis(nombre) do
        nil -> :ok
        pid -> GenServer.stop(pid, :normal)
      end
    end)
  end
end
