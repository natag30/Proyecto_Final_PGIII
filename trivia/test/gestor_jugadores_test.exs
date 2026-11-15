defmodule Trivia.GestorJugadoresTest do
  use ExUnit.Case

  alias Trivia.GestorJugadores

  # Historial de ejemplo, con un bot y dos temas
  defp historial do
    [
      %{
        tema: "ciencia",
        jugadores: [
          %{usuario: "ana", puntaje: 40},
          %{usuario: "luis", puntaje: 40},
          %{usuario: "bot_1", puntaje: 90}
        ]
      },
      %{tema: "ciencia", jugadores: [%{usuario: "ana", puntaje: 30}]},
      %{tema: "historia", jugadores: [%{usuario: "luis", puntaje: 100}]}
    ]
  end

  # PARTE A: funciones puras

  describe "es_bot?/1" do
    test "reconoce un usuario con prefijo bot_" do
      assert GestorJugadores.es_bot?("bot_1")
    end

    test "no confunde un usuario normal con un bot" do
      refute GestorJugadores.es_bot?("ana")
    end

    test "el prefijo bot_ debe estar al inicio" do
      refute GestorJugadores.es_bot?("robot_1")
    end
  end

  describe "puntaje_acumulado/2" do
    test "suma los puntajes de todos los temas" do
      assert GestorJugadores.puntaje_acumulado(historial(), "ana") == 70
    end

    test "devuelve cero si el usuario no aparece" do
      assert GestorJugadores.puntaje_acumulado(historial(), "usuario_prueba") == 0
    end
  end

  describe "partidas_jugadas/2" do
    test "cuenta las partidas donde participó" do
      assert GestorJugadores.partidas_jugadas(historial(), "ana") == 2
    end

    test "devuelve cero si no participó" do
      assert GestorJugadores.partidas_jugadas(historial(), "usuario_prueba") == 0
    end
  end

  describe "resumen_desde/2" do
    test "arma el resumen del usuario con su total, partidas y nivel por tema" do
      assert GestorJugadores.resumen_desde(historial(), "ana") == %{
               usuario: "ana",
               total: 70,
               partidas: 2,
               niveles: %{"ciencia" => :intermedio}
             }
    end

    test "incluye un nivel por cada tema del usuario" do
      assert GestorJugadores.resumen_desde(historial(), "luis") == %{
               usuario: "luis",
               total: 140,
               partidas: 2,
               niveles: %{"ciencia" => :basico, "historia" => :intermedio}
             }
    end

    test "con historial vacío devuelve ceros y niveles vacíos" do
      assert GestorJugadores.resumen_desde([], "ana") == %{
               usuario: "ana",
               total: 0,
               partidas: 0,
               niveles: %{}
             }
    end
  end

  describe "ranking_desde/2" do
    test "ordena por puntaje descendente y excluye bots" do
      assert GestorJugadores.ranking_desde(historial(), nil) == [
               %{usuario: "luis", puntaje: 140, partidas: 2},
               %{usuario: "ana", puntaje: 70, partidas: 2}
             ]
    end

    test "filtra por tema" do
      assert GestorJugadores.ranking_desde(historial(), "ciencia") == [
               %{usuario: "ana", puntaje: 70, partidas: 2},
               %{usuario: "luis", puntaje: 40, partidas: 1}
             ]
    end

    test "un tema sin partidas devuelve una lista vacía" do
      assert GestorJugadores.ranking_desde(historial(), "geografia") == []
    end

    test "en empate ordena por nombre de usuario" do
      historial = [
        %{
          tema: "ciencia",
          jugadores: [
            %{usuario: "zoe", puntaje: 10},
            %{usuario: "ana", puntaje: 10}
          ]
        }
      ]

      assert GestorJugadores.ranking_desde(historial, nil) == [
               %{usuario: "ana", puntaje: 10, partidas: 1},
               %{usuario: "zoe", puntaje: 10, partidas: 1}
             ]
    end
  end

  # PARTE B: GenServer

  describe "conectar/3, desconectar/1 y usuario_de/1" do
    setup do
      original = File.read("data/users.json")

      start_supervised!(Trivia.Persistencia)
      start_supervised!(GestorJugadores)

      on_exit(fn ->
        case original do
          {:ok, contenido} -> File.write!("data/users.json", contenido)
          {:error, _} -> File.rm("data/users.json")
        end
      end)

      :ok
    end

    test "rechaza usuarios que empiezan con bot_" do
      assert GestorJugadores.conectar("bot_x", "1234", self()) ==
               {:error, :usuario_reservado}
    end

    test "desconectar sin sesión devuelve error" do
      assert GestorJugadores.desconectar("usuario_prueba") == {:error, :sin_sesion}
    end

    test "usuario_de de un pid sin sesión devuelve error" do
      assert GestorJugadores.usuario_de(self()) == {:error, :sin_sesion}
    end

    test "registra un usuario nuevo" do
      assert GestorJugadores.conectar("usuario_prueba", "1234", self()) ==
               {:ok, :registrado}

      assert GestorJugadores.desconectar("usuario_prueba") == :ok
    end

    test "rechaza una segunda conexión del mismo usuario" do
      assert GestorJugadores.conectar("usuario_prueba", "1234", self()) ==
               {:ok, :registrado}

      assert GestorJugadores.conectar("usuario_prueba", "1234", self()) ==
               {:error, :sesion_duplicada}

      assert GestorJugadores.desconectar("usuario_prueba") == :ok
    end

    test "rechaza una clave incorrecta aunque el usuario ya tenga sesión" do
      assert GestorJugadores.conectar("usuario_prueba", "1234", self()) ==
               {:ok, :registrado}

      assert GestorJugadores.conectar("usuario_prueba", "9999", self()) ==
               {:error, :clave_incorrecta}

      assert GestorJugadores.desconectar("usuario_prueba") == :ok
    end

    test "usuario_de y desconectar funcionan después de conectar" do
      assert GestorJugadores.conectar("usuario_prueba", "1234", self()) ==
               {:ok, :registrado}

      assert GestorJugadores.usuario_de(self()) == {:ok, "usuario_prueba"}
      assert GestorJugadores.desconectar("usuario_prueba") == :ok
      assert GestorJugadores.usuario_de(self()) == {:error, :sin_sesion}
    end
  end
end
