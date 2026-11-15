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
    tiempo_pregunta = Map.get(context, :tiempo_pregunta, 30)

    argumentos = %{
      id: "P-test",
      creador: "carlos",
      tema: "ciencia",
      nivel: :basico,
      total_preguntas: total_preguntas,
      tiempo_pregunta: tiempo_pregunta,
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

  test "valida la apertura de ronda, la letra y las respuestas duplicadas" do
    ronda = %{abierta: true, respuestas: %{}}

    for letra <- ["A", "B", "C", "D"] do
      assert {:ok, ^letra} = Trivia.Partida.validar_respuesta(ronda, "carlos", letra)
    end

    assert {:ok, "A"} = Trivia.Partida.validar_respuesta(ronda, "carlos", " a ")
    assert {:error, :letra_invalida} = Trivia.Partida.validar_respuesta(ronda, "carlos", "E")
    assert {:error, :letra_invalida} = Trivia.Partida.validar_respuesta(ronda, "carlos", nil)

    assert {:error, :ronda_cerrada} =
             Trivia.Partida.validar_respuesta(%{ronda | abierta: false}, "carlos", "A")

    ronda_con_respuesta = %{ronda | respuestas: %{"carlos" => {"A", 30}}}

    assert {:error, :ya_respondio} =
             Trivia.Partida.validar_respuesta(ronda_con_respuesta, "carlos", "B")
  end

  test "una letra inválida no consume el intento de respuesta", %{partida: partida} do
    assert {:ok, "bot_1"} = Trivia.Partida.add_bot(partida, :facil)
    assert {:ok, "bot_2"} = Trivia.Partida.add_bot(partida, :medio)
    assert :ok = Trivia.Partida.start_game(partida)
    assert_receive {:pregunta, %{numero: 1}}, 1_000

    assert {:error, :letra_invalida} = Trivia.Partida.answer(partida, "carlos", "X")
    assert {:ok, :registrada} = Trivia.Partida.answer(partida, "carlos", " a ")
    assert {:error, :ya_respondio} = Trivia.Partida.answer(partida, "carlos", "B")
    assert {"A", _restantes} = Trivia.Partida.ronda(partida).respuestas["carlos"]
  end

  test "los bots esperan al cliente y excluyen su opcion", %{partida: partida} do
    assert {:ok, "bot_1"} = Trivia.Partida.add_bot(partida, :facil)
    assert {:ok, "bot_2"} = Trivia.Partida.add_bot(partida, :medio)
    assert :ok = Trivia.Partida.start_game(partida)
    assert_receive {:pregunta, %{numero: 1}}, 1_000
    assert Trivia.Partida.ronda(partida).respuestas == %{}
    assert {:error, :ronda_cerrada} = Trivia.Partida.answer(partida, "bot_1", "A")

    assert {:ok, :registrada} = Trivia.Partida.answer(partida, "carlos", "B")
    assert_receive {:cierre_ronda, _resultado}, 1_000

    respuestas = Trivia.Partida.ronda(partida).respuestas
    assert {"B", _restantes} = respuestas["carlos"]
    assert {bot_1, _} = respuestas["bot_1"]
    assert {bot_2, _} = respuestas["bot_2"]
    refute bot_1 == "B"
    refute bot_2 == "B"
  end

  @tag tiempo_pregunta: 1
  test "si el cliente no responde, los bots eligen al vencer el tiempo", %{partida: partida} do
    assert {:ok, "bot_1"} = Trivia.Partida.add_bot(partida, :facil)
    assert {:ok, "bot_2"} = Trivia.Partida.add_bot(partida, :medio)
    assert :ok = Trivia.Partida.start_game(partida)
    assert_receive {:pregunta, %{numero: 1}}, 1_000
    assert_receive {:cierre_ronda, _resultado}, 2_000

    respuestas = Trivia.Partida.ronda(partida).respuestas
    refute Map.has_key?(respuestas, "carlos")
    assert {bot_1, _} = respuestas["bot_1"]
    assert {bot_2, _} = respuestas["bot_2"]
    assert bot_1 in ["A", "B", "C", "D"]
    assert bot_2 in ["A", "B", "C", "D"]
  end

  @tag total_preguntas: 2
  test "acumula el puntaje de cada ronda por jugador", %{partida: partida} do
    assert {:ok, "bot_1"} = Trivia.Partida.add_bot(partida, :facil)
    assert {:ok, "bot_2"} = Trivia.Partida.add_bot(partida, :medio)
    assert :ok = Trivia.Partida.start_game(partida)

    assert_receive {:pregunta, %{numero: 1}}, 1_000
    assert {:ok, :registrada} = Trivia.Partida.answer(partida, "carlos", "A")

    assert_receive {:cierre_ronda, primera}, 1_000
    assert primera.puntos_ronda["carlos"] in 10..15
    assert Trivia.Partida.puntajes(partida) == primera.totales

    assert_receive {:pregunta, %{numero: 2}}, 1_000
    assert {:ok, :registrada} = Trivia.Partida.answer(partida, "carlos", "A")

    assert_receive {:cierre_ronda, segunda}, 1_000
    assert segunda.puntos_ronda["carlos"] in 10..15

    for jugador <- ["carlos", "bot_1", "bot_2"] do
      assert segunda.totales[jugador] ==
               primera.puntos_ronda[jugador] + segunda.puntos_ronda[jugador]
    end

    totales_finales = Trivia.Partida.puntajes(partida)
    assert totales_finales["carlos"] == segunda.totales["carlos"]
    assert totales_finales["bot_1"] == segunda.totales["bot_1"]
    assert totales_finales["bot_2"] == segunda.totales["bot_2"]
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
