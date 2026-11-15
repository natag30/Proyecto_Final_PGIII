# Autora: Natalia García

defmodule Trivia.Persistencia do
  @moduledoc """
  Módulo que maneja la persistencia de datos en la aplicación Trivia.
  Contiene funciones para guardar y cargar usuarios, preguntas y resultados de partidas.
  """

  use GenServer

  @ruta_preguntas "data/questions.json"
  @ruta_usuarios "data/users.json"
  @ruta_resultados "data/results.log"

  @doc """
  Inicia el proceso único encargado de serializar las escrituras.
  """
  def start_link(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  @doc """
  Registra un usuario y espera a que se guarde en el archivo.
  """
  def guardar_usuario(usuario, clave) do
    GenServer.call(__MODULE__, {:guardar_usuario, usuario, clave})
  end

  @doc """
  Registra el resultado de una partida y espera a que se añada al historial.
  """
  def registrar_resultado(entrada) do
    GenServer.call(__MODULE__, {:registrar_resultado, entrada})
  end

  @doc """
  Carga las preguntas desde el archivo JSON y convierte sus campos al formato interno.
  Devuelve una lista de mapas con las preguntas.
  """
  def cargar_preguntas do
    @ruta_preguntas
    |> File.read!()
    |> Jason.decode!()
    |> Enum.map(&a_pregunta/1)
  end

  @doc """
  Carga los usuarios desde un archivo JSON, o devuelve una lista vacía si aún no existe.
  Devuelve una lista de mapas con los usuarios y sus claves.
  """
  def cargar_usuarios do
    case File.read(@ruta_usuarios) do
      {:ok, texto} -> Jason.decode!(texto, keys: :atoms)
      {:error, :enoent} -> []
    end
  end

  @doc """
  Lee el historial de partidas, o devuelve una lista vacía si aún no existe.
  Devuelve una lista de mapas con los resultados de las partidas.
  """
  def leer_historial do
    case File.read(@ruta_resultados) do
      {:ok, texto} ->
        texto
        |> String.split("\n", trim: true)
        |> Enum.map(&parsear_linea/1)

      {:error, :enoent} ->
        []
    end
  end

  @doc """
  Convierte el resultado de una partida en una línea de texto JSON.
  """
  def formatear_linea(resultado), do: Jason.encode!(resultado)

  @doc """
  Convierte una línea de results.log en el mapa del resultado.
  Devuelve un mapa con los campos del resultado, incluyendo el nivel convertido a átomo.
  """
  def parsear_linea(linea) do
    linea
    |> String.trim()
    |> Jason.decode!(keys: :atoms)
    |> Map.update!(:nivel, &nivel_a_atomo/1)
  end

  # Función privada que convierte el nivel de string a átomo
  defp nivel_a_atomo("basico"), do: :basico
  defp nivel_a_atomo("intermedio"), do: :intermedio
  defp nivel_a_atomo("avanzado"), do: :avanzado

  # Función privada que convierte los datos de una pregunta desde el formato JSON al formato interno
  defp a_pregunta(datos) do
    %{
      tema: Map.fetch!(datos, "tema"),
      nivel: nivel_a_atomo(Map.fetch!(datos, "nivel")),
      enunciado: Map.fetch!(datos, "enunciado"),
      opciones: Map.fetch!(datos, "opciones"),
      respuesta: Map.fetch!(datos, "respuesta")
    }
  end

  @impl true
  def init(_opciones), do: {:ok, :sin_estado}

  @impl true
  def handle_call({:guardar_usuario, usuario, clave}, _from, estado) do
    File.mkdir_p!("data")
    usuarios = cargar_usuarios() ++ [%{usuario: usuario, clave: clave}]
    File.write!(@ruta_usuarios, Jason.encode!(usuarios))

    {:reply, :ok, estado}
  end


  @impl true
  def handle_call({:registrar_resultado, entrada}, _from, estado) do
    File.mkdir_p!("data")
    linea = entrada |> a_registro() |> formatear_linea()
    File.write!(@ruta_resultados, linea <> "\n", [:append])

    {:reply, :ok, estado}
  end

  # Convierte el ranking en la lista de jugadores que espera el historial
  defp a_registro(%{ranking: ranking} = entrada) do
    jugadores =
      Enum.map(ranking, fn {usuario, puntaje} ->
        %{usuario: usuario, puntaje: puntaje}
      end)

    entrada
    |> Map.delete(:ranking)
    |> Map.put(:jugadores, jugadores)
  end

  defp a_registro(entrada), do: entrada
end
