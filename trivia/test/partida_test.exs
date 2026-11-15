# Autor: Carlos Andres

defmodule Trivia.PartidaTest do
  use ExUnit.Case, async: false

  @pregunta %{
    nivel: :basico,
    enunciado: "Pregunta de prueba",
    opciones: %{"A" => "Correcta", "B" => "Incorrecta", "C" => "Incorrecta", "D" => "Incorrecta"},
    respuesta: "A"
  }

  setup context do
    total_preguntas = Map.get(context, :total_preguntas, 1)

    argumentos = %{
      id: "P-test",
      creador: "carlos",
      tema: "ciencia",
      nivel: :basico,
      total_preguntas: total_preguntas,
      tiempo_pregunta: 30,
      cliente: self(),
      gestor: nil,
      sorteo: fn _tema, _nivel, _total ->
        {:ok, List.duplicate(@pregunta, total_preguntas)}
      end,
      registrar: fn _resultado -> :ok end,
      pausa_ms: 0,
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

  test "calcula el puntaje de ronda por resultado, nivel y tiempo" do
    assert Trivia.Partida.puntos_ronda(:correcto, :basico, 30, 30) == 15
    assert Trivia.Partida.puntos_ronda(:correcto, :intermedio, 15, 30) == 17
    assert Trivia.Partida.puntos_ronda(:incorrecto, :avanzado, 30, 30) == -10
    assert Trivia.Partida.puntos_ronda(:sin_responder, :basico, 30, 30) == 0
    assert Trivia.Partida.bonificacion(-1, 30) == 0
    assert Trivia.Partida.bonificacion(40, 30) == 5
  end

  @tag total_preguntas: 2
  test "acumula el puntaje de cada ronda por jugador", %{partida: partida} do
    assert {:ok, "bot_1"} = Trivia.Partida.add_bot(partida, :facil)
    assert {:ok, "bot_2"} = Trivia.Partida.add_bot(partida, :medio)
    assert :ok = Trivia.Partida.start_game(partida)

    assert_receive {:pregunta, %{numero: 1}}, 1_000
    assert {:ok, :registrada} = Trivia.Partida.answer(partida, "carlos", "A")
    assert {:ok, :registrada} = Trivia.Partida.answer(partida, "bot_1", "B")
    assert {:ok, :registrada} = Trivia.Partida.answer(partida, "bot_2", "B")

    assert_receive {:cierre_ronda, primera}, 1_000
    assert primera.puntos_ronda["carlos"] in 10..15
    assert primera.puntos_ronda["bot_1"] == -5
    assert primera.puntos_ronda["bot_2"] == -5
    assert Trivia.Partida.puntajes(partida) == primera.totales

    assert_receive {:pregunta, %{numero: 2}}, 1_000
    assert {:ok, :registrada} = Trivia.Partida.answer(partida, "carlos", "A")
    assert {:ok, :registrada} = Trivia.Partida.answer(partida, "bot_1", "B")
    assert {:ok, :registrada} = Trivia.Partida.answer(partida, "bot_2", "A")

    assert_receive {:cierre_ronda, segunda}, 1_000
    assert segunda.puntos_ronda["carlos"] in 10..15
    assert segunda.puntos_ronda["bot_1"] == -5
    assert segunda.puntos_ronda["bot_2"] in 10..15

    assert segunda.totales["carlos"] ==
             primera.puntos_ronda["carlos"] + segunda.puntos_ronda["carlos"]

    totales_finales = Trivia.Partida.puntajes(partida)
    assert totales_finales["carlos"] == segunda.totales["carlos"]
    assert totales_finales["bot_1"] == -10

    assert totales_finales["bot_2"] ==
             primera.puntos_ronda["bot_2"] + segunda.puntos_ronda["bot_2"]
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

    for {preguntas, tiempo} <- [{0, 30}, {-1, 30}, {1, 0}, {1, -5}, {1.5, 30}] do
      assert {:error, :parametros_invalidos} =
               Trivia.GestorPartidas.crear(usuario, self(), "ciencia", preguntas, tiempo)
    end

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
        nil ->
          :ok

        pid ->
          ref = Process.monitor(pid)
          Process.exit(pid, :kill)

          receive do
            {:DOWN, ^ref, :process, ^pid, _razon} -> :ok
          end
      end
    end)
  end
end
