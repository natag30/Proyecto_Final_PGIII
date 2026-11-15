defmodule Trivia.PersistenciaTest do
  use ExUnit.Case

  alias Trivia.Persistencia

  defp resultado do
    %{
      id: 1,
      tema: "ciencia",
      nivel: :basico,
      jugadores: [
        %{usuario: "ana", puntaje: 40},
        %{usuario: "bot_1", puntaje: 20}
      ]
    }
  end

  describe "formatear_linea/1" do
    test "genera una sola línea de texto sin saltos de línea" do
      linea = resultado() |> Persistencia.formatear_linea()

      refute String.contains?(linea, "\n")
    end

    test "el nivel queda como texto" do
      linea = resultado() |> Persistencia.formatear_linea()

      assert String.contains?(linea, "\"basico\"")
    end
  end

  describe "parsear_linea/1" do
    test "convierte los tres niveles de texto a átomos" do
      for {texto, nivel} <- [
            {"basico", :basico},
            {"intermedio", :intermedio},
            {"avanzado", :avanzado}
          ] do
        linea = ~s({"id":1,"tema":"ciencia","nivel":"#{texto}","jugadores":[]})

        assert Persistencia.parsear_linea(linea) == %{
                 id: 1,
                 tema: "ciencia",
                 nivel: nivel,
                 jugadores: []
               }
      end
    end

    test "ignora espacios y saltos de línea al final" do
      linea = resultado() |> Persistencia.formatear_linea()

      assert Persistencia.parsear_linea(linea <> "\n") == resultado()
    end
  end

  describe "ida y vuelta" do
    test "parsear_linea(formatear_linea(resultado)) devuelve el mismo mapa" do
      assert resultado()
             |> Persistencia.formatear_linea()
             |> Persistencia.parsear_linea() == resultado()
    end
  end

  describe "registrar_resultado/1 y leer_historial/0" do
    setup do
      original = File.read("data/results.log")
      File.rm("data/results.log")
      start_supervised!(Persistencia)

      on_exit(fn ->
        case original do
          {:ok, contenido} -> File.write!("data/results.log", contenido)
          {:error, _} -> File.rm("data/results.log")
        end
      end)

      :ok
    end

    test "un resultado guardado se lee de vuelta" do
      :ok = Persistencia.registrar_resultado(resultado())

      assert Persistencia.leer_historial() == [resultado()]
    end

    test "el ranking en tuplas se guarda como jugadores" do
      entrada = %{
        id: 2,
        tema: "ciencia",
        nivel: :basico,
        ranking: [{"ana", 40}, {"bot_1", 20}]
      }

      :ok = Persistencia.registrar_resultado(entrada)

      assert [registro] = Persistencia.leer_historial()

      assert registro == %{
               id: 2,
               tema: "ciencia",
               nivel: :basico,
               jugadores: [
                 %{usuario: "ana", puntaje: 40},
                 %{usuario: "bot_1", puntaje: 20}
               ]
             }

      refute Map.has_key?(registro, :ranking)
    end

    test "varios resultados se leen en el orden en que se guardaron" do
      primero = resultado()

      segundo = %{
        id: 2,
        tema: "historia",
        nivel: :avanzado,
        jugadores: [%{usuario: "luis", puntaje: 100}]
      }

      :ok = Persistencia.registrar_resultado(primero)
      :ok = Persistencia.registrar_resultado(segundo)

      assert Persistencia.leer_historial() == [primero, segundo]
    end
  end
end
