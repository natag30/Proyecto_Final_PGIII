# Autora: Natalia García

defmodule Trivia.GestorJugadores do
  @moduledoc """
  Módulo que gestiona la conexión de jugadores a la aplicación Trivia.
  Contiene funciones para conectar y desconectar jugadores, así como para obtener información sobre los jugadores conectados.
  """

  use GenServer

  @doc """
  Determina si un usuario es un bot según su nombre.
  Un usuario es considerado un bot si su nombre comienza con "bot_".
  """
  def es_bot?(usuario), do: String.starts_with?(usuario, "bot_")

  @doc """
  Calcula el puntaje total de un usuario en todas las partidas del historial.
  """
  def puntaje_acumulado(historial, usuario) do
    historial
    |> Enum.flat_map(fn partida -> partida.jugadores end)
    |> Enum.filter(fn jugador -> jugador.usuario == usuario end)
    |> Enum.map(fn jugador -> jugador.puntaje end)
    |> Enum.sum()
  end

  @doc """
  Cuenta la cantidad de partidas en las que un usuario participó.
  """
  def partidas_jugadas(historial, usuario) do
    Enum.count(historial, &participa?(&1, usuario))
  end

  @doc """
  Genera un resumen de la actividad de un usuario en el historial.
  Devuelve un mapa con el nombre del usuario, la cantidad de partidas jugadas, el puntaje total
  y un mapa con los niveles alcanzados en cada tema.
  """
  def resumen_desde(historial, usuario) do
    temas =
      historial
      |> Enum.flat_map(fn partida ->
        if participa?(partida, usuario) do
          [partida.tema]
        else
          []
        end
      end)
      |> Enum.uniq()

    niveles =
      Map.new(temas, fn tema ->
        {tema, Trivia.Nivel.nivel_en_tema(historial, usuario, tema)}
      end)

    %{
      usuario: usuario,
      total: puntaje_acumulado(historial, usuario),
      partidas: partidas_jugadas(historial, usuario),
      niveles: niveles
    }
  end

  @doc """
  Genera un ranking de jugadores basado en el historial y un tema opcional.
  """
  def ranking_desde(historial, tema) do
    historial_filtrado = filtrar_tema(historial, tema)

    historial_filtrado
    |> Enum.flat_map(fn partida -> partida.jugadores end)
    |> Enum.map(fn jugador -> jugador.usuario end)
    |> Enum.uniq()
    |> Enum.reject(&es_bot?/1)
    |> Enum.map(fn usuario ->
      %{
        usuario: usuario,
        puntaje: puntaje_acumulado(historial_filtrado, usuario),
        partidas: partidas_jugadas(historial_filtrado, usuario)
      }
    end)
    |> Enum.sort_by(fn fila -> {-fila.puntaje, fila.usuario} end)
  end

  @doc """
  Inicia el gestor de jugadores con un mapa de sesiones vacío.
  """
  def start_link(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  @doc """
  Valida las credenciales e inicia una sesión para el proceso cliente.
  """
  def conectar(usuario, clave, pid_cliente) do
    GenServer.call(__MODULE__, {:conectar, usuario, clave, pid_cliente})
  end

  @doc """
  Cierra la sesión de un usuario.
  """
  def desconectar(usuario) do
    GenServer.call(__MODULE__, {:desconectar, usuario})
  end

  @doc """
  Busca el usuario asociado a un proceso cliente.
  """
  def usuario_de(pid_cliente) do
    GenServer.call(__MODULE__, {:usuario_de, pid_cliente})
  end

  @doc """
  Devuelve el resumen de un usuario a partir del historial persistido.
  """
  def resumen(usuario) do
    historial = Trivia.Persistencia.leer_historial()
    resumen_desde(historial, usuario)
  end

  @doc """
  Devuelve el ranking del historial persistido, opcionalmente filtrado por tema.
  """
  def ranking(tema) do
    historial = Trivia.Persistencia.leer_historial()
    ranking_desde(historial, tema)
  end

  @doc """
  Calcula el nivel actual de un usuario en un tema.
  """
  def nivel_en_tema(usuario, tema) do
    historial = Trivia.Persistencia.leer_historial()
    Trivia.Nivel.nivel_en_tema(historial, usuario, tema)
  end

  @impl true
  def init(_opciones), do: {:ok, %{}}

  @impl true
  def handle_call({:conectar, usuario, clave, pid_cliente}, _from, sesiones) do
    case validar_conexion(usuario, clave, sesiones) do
      {:error, motivo} ->
        {:reply, {:error, motivo}, sesiones}

      :registrar ->
        :ok = Trivia.Persistencia.guardar_usuario(usuario, clave)
        abrir_sesion(usuario, pid_cliente, :registrado, sesiones)

      :existente ->
        abrir_sesion(usuario, pid_cliente, :existente, sesiones)
    end
  end

  @impl true
  def handle_call({:desconectar, usuario}, _from, sesiones) do
    case Map.pop(sesiones, usuario) do
      {nil, _sesiones} ->
        {:reply, {:error, :sin_sesion}, sesiones}

      {sesion, nuevas_sesiones} ->
        Process.demonitor(sesion.ref, [:flush])
        {:reply, :ok, nuevas_sesiones}
    end
  end

  @impl true
  def handle_call({:usuario_de, pid_cliente}, _from, sesiones) do
    respuesta =
      case Enum.find(sesiones, fn {_usuario, sesion} -> sesion.pid == pid_cliente end) do
        {usuario, _sesion} -> {:ok, usuario}
        nil -> {:error, :sin_sesion}
      end

    {:reply, respuesta, sesiones}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid_cliente, _razon}, sesiones) do
    case Enum.find(sesiones, fn {_usuario, sesion} -> sesion.ref == ref end) do
      {usuario, _sesion} ->
        nuevas_sesiones = Map.delete(sesiones, usuario)
        Trivia.GestorPartidas.cliente_caido(usuario)
        {:noreply, nuevas_sesiones}

      nil ->
        {:noreply, sesiones}
    end
  end

  # Función privada que filtra el historial por tema, devolviendo el historial completo si no se especifica un tema
  defp filtrar_tema(historial, nil), do: historial

  defp filtrar_tema(historial, tema) do
    Enum.filter(historial, fn partida -> partida.tema == tema end)
  end

  defp validar_conexion(usuario, clave, sesiones) do
    if es_bot?(usuario) do
      {:error, :usuario_reservado}
    else
      usuario_guardado =
        Trivia.Persistencia.cargar_usuarios()
        |> Enum.find(fn registro -> registro.usuario == usuario end)

      cond do
        usuario_guardado != nil and usuario_guardado.clave != clave ->
          {:error, :clave_incorrecta}

        Map.has_key?(sesiones, usuario) ->
          {:error, :sesion_duplicada}

        usuario_guardado == nil ->
          :registrar

        true ->
          :existente
      end
    end
  end

  defp abrir_sesion(usuario, pid_cliente, resultado, sesiones) do
    ref = Process.monitor(pid_cliente)
    sesion = %{pid: pid_cliente, ref: ref}
    nuevas_sesiones = Map.put(sesiones, usuario, sesion)

    {:reply, {:ok, resultado}, nuevas_sesiones}
  end

  # Función privada que determina si un usuario participó en una partida
  defp participa?(partida, usuario) do
    Enum.any?(partida.jugadores, fn jugador -> jugador.usuario == usuario end)
  end
end
