# Autora: Natalia García

defmodule Trivia.BancoPreguntas do
  @moduledoc """
  Módulo que representa el banco de preguntas de la aplicación Trivia.
  Contiene funciones para validar temas, sortear preguntas y manejar el estado del banco de preguntas
  """

  use GenServer

  @doc """
  Función que publica una pregunta eliminando la respuesta correcta.
  Esto es útil para enviar la pregunta a los jugadores sin revelar la respuesta.
  """
  def publica(pregunta) do
    Map.delete(pregunta, :respuesta)
  end

  @doc """
  Función que verifica si hay suficientes preguntas en el banco para un tema específico según el reparto solicitado.
  """
  def hay_suficientes?(preguntas, tema, reparto) do
    Enum.all?(reparto, fn {nivel, cantidad_solicitada} ->
      Enum.count(preguntas, fn pregunta ->
        pregunta.tema == tema and pregunta.nivel == nivel
      end) >= cantidad_solicitada
    end)
  end

  @doc """
  Función que sortea preguntas del banco según el tema y el reparto solicitado.
  Recibe la lista de preguntas, el tema y un mapa que indica cuántas preguntas se deben tomar de cada nivel.
  Devuelve una lista de preguntas sorteadas.
  """
  def sortear(preguntas, tema, reparto) do
    preguntas_del_tema = Enum.filter(preguntas, fn pregunta -> pregunta.tema == tema end)

    Enum.flat_map([:basico, :intermedio, :avanzado], fn nivel ->
      preguntas_del_tema
      |> Enum.filter(fn pregunta -> pregunta.nivel == nivel end)
      |> Enum.shuffle()
      |> Enum.take(Map.fetch!(reparto, nivel))
    end)
  end

  # API del genserver

  @doc """
  Inicia el GenServer del banco de preguntas.
  Se puede pasar una lista de opciones, incluyendo la opción :preguntas para cargar un conjunto
  """
  def start_link(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  @doc """
  Valida si un tema tiene suficientes preguntas para un nivel y total de preguntas solicitadas.
  """
  def validar_tema(tema, nivel, total) do
    GenServer.call(__MODULE__, {:validar_tema, tema, nivel, total})
  end

  @doc """
  Sortea una partida de preguntas según el tema, nivel y total de preguntas solicitadas.
  Devuelve {:ok, preguntas} si hay suficientes preguntas, o {:error, :tema_no_disponible} si no hay suficientes preguntas.
  """
  def sortear_partida(tema, nivel, total) do
    GenServer.call(__MODULE__, {:sortear_partida, tema, nivel, total})
  end

  # Callbacks del GenServer

  @impl true
  # Inicializa el estado del GenServer cargando las preguntas desde la persistencia.
  # Se puede pasar una lista de opciones, incluyendo la opción :preguntas para cargar un conjunto
  def init(opciones) do
    preguntas =
      Keyword.get_lazy(opciones, :preguntas, fn ->
        Trivia.Persistencia.cargar_preguntas()
      end)

    {:ok, preguntas}
  end

  @impl true
  # Maneja la llamada para validar si un tema tiene suficientes preguntas para un nivel y total de preguntas solicitadas.
  # Devuelve :ok si hay suficientes preguntas, o {:error, :tema_no_disponible} si no hay suficientes preguntas.
  def handle_call({:validar_tema, tema, nivel, total}, _from, preguntas) do
    respuesta =
      case reparto_disponible(preguntas, tema, nivel, total) do
        {:ok, _reparto} -> :ok
        {:error, _razon} = error -> error
      end

    {:reply, respuesta, preguntas}
  end

  @impl true
  def handle_call({:sortear_partida, tema, nivel, total}, _from, preguntas) do
    respuesta =
      case reparto_disponible(preguntas, tema, nivel, total) do
        {:ok, reparto} -> {:ok, sortear(preguntas, tema, reparto)}
        {:error, _razon} = error -> error
      end

    {:reply, respuesta, preguntas}
  end

  # Función privada que verifica si hay suficientes preguntas en el banco para un tema específico según el reparto solicitado.
  defp reparto_disponible(preguntas, tema, nivel, total) do
    reparto = Trivia.Nivel.reparto(nivel, total)

    if hay_suficientes?(preguntas, tema, reparto) do
      {:ok, reparto}
    else
      {:error, :tema_no_disponible}
    end
  end
end
