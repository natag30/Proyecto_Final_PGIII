# Autor: Carlos Andres

defmodule Trivia.Servidor do
  use GenServer

  # Nombre del servidor
  def nombre do
    __MODULE__
  end

  def start_link(_opciones) do
    GenServer.start_link(
      __MODULE__,
      :ok,
      name: nombre()
    )
  end

  @impl true
  def init(:ok) do
    estado = %{}

    {:ok, estado}
  end

  def iniciar do
    with :ok <- iniciar_proceso(Trivia.Persistencia),
         :ok <- iniciar_proceso(Trivia.BancoPreguntas),
         :ok <- iniciar_proceso(Trivia.GestorJugadores),
         :ok <- iniciar_proceso(Trivia.SupervisorPartidas),
         :ok <- iniciar_proceso(Trivia.GestorPartidas),
         :ok <- iniciar_proceso(__MODULE__) do
      :ok
    end
  end

  defp iniciar_proceso(modulo) do
    case modulo.start_link([]) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        :ok

      error ->
        error
    end
  end

  @impl true
  def handle_call({:connect, usuario, clave}, {pid_cliente, _referencia}, estado) do
    respuesta =
      Trivia.GestorJugadores.conectar(usuario, clave, pid_cliente)

    {:reply, respuesta, estado}
  end

  @impl true
  def handle_call(
        {:create_game, tema, preguntas, tiempo, pid_receptor},
        {pid_cliente, _referencia},
        estado
      ) do
    # Averigua que usuario esta asociado al proceso que hace la peticion
    case Trivia.GestorJugadores.usuario_de(pid_cliente) do
      {:ok, usuario} ->
        # Solicita al GestorPartidas que cree la partida.
        respuesta =
          Trivia.GestorPartidas.crear(
            usuario,
            pid_receptor,
            tema,
            preguntas,
            tiempo
          )

        {:reply, respuesta, estado}

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call(
        {:add_bot, dificultad},
        {pid_cliente, _referencia},
        estado
      ) do
    # Identifica al usuario que envia la peticion
    case Trivia.GestorJugadores.usuario_de(pid_cliente) do
      {:ok, usuario} ->
        respuesta =
          Trivia.GestorPartidas.agregar_bot(usuario, dificultad)

        {:reply, respuesta, estado}

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call(
        {:start_game},
        {pid_cliente, _referencia},
        estado
      ) do
    # Busca que usuario esta asociado al proceso cliente
    case Trivia.GestorJugadores.usuario_de(pid_cliente) do
      {:ok, usuario} ->
        respuesta =
          Trivia.GestorPartidas.iniciar_partida(usuario)

        {:reply, respuesta, estado}

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call(
        {:answer, letra},
        {pid_cliente, _referencia},
        estado
      ) do
    case Trivia.GestorJugadores.usuario_de(pid_cliente) do
      {:ok, usuario} ->
        respuesta =
          Trivia.GestorPartidas.responder(usuario, letra)

        {:reply, respuesta, estado}

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call(
        {:score},
        {pid_cliente, _referencia},
        estado
      ) do
    # Identifica al usuario que realiza la consulta
    case Trivia.GestorJugadores.usuario_de(pid_cliente) do
      {:ok, usuario} ->
        # Obtiene la partida asociada al usuario
        case Trivia.GestorPartidas.partida_de(usuario) do
          {:ok, pid_partida} ->
            # Consulta el puntaje directamente en la partida
            puntajes = Trivia.Partida.puntajes(pid_partida)

            respuesta = {:ok, Map.get(puntajes, usuario, 0)}

            {:reply, respuesta, estado}

          {:error, motivo} ->
            {:reply, {:error, motivo}, estado}
        end

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call(
        {:ranking, tema},
        _desde,
        estado
      ) do
    # Solicita el ranking general o por tema
    respuesta = Trivia.GestorJugadores.ranking(tema)

    {:reply, respuesta, estado}
  end

  @impl true
  def handle_call(
        {:leave_game},
        {pid_cliente, _referencia},
        estado
      ) do
    case Trivia.GestorJugadores.usuario_de(pid_cliente) do
      {:ok, usuario} ->
        respuesta =
          Trivia.GestorPartidas.abandonar(usuario)

        {:reply, respuesta, estado}

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call(
        {:disconnect},
        {pid_cliente, _referencia},
        estado
      ) do
    # Identifica al usuario asociado al proceso cliente.
    case Trivia.GestorJugadores.usuario_de(pid_cliente) do
      {:ok, usuario} ->
        # Desconecta al usuario y cierra su sesión.
        respuesta =
          Trivia.GestorJugadores.desconectar(usuario)

        {:reply, respuesta, estado}

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end
end
