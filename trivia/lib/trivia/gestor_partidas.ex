#Autor: Carlos Andres

defmodule Trivia.GestorPartidas do
  use GenServer

  def start_link(_opciones) do
    GenServer.start_link(
      __MODULE__,
      :ok,
      name: __MODULE__
    )
  end

  def crear(usuario, pid_receptor, tema, preguntas, tiempo) do
    GenServer.call(
      __MODULE__,
      {:crear, usuario, pid_receptor, tema, preguntas, tiempo}
    )
  end


  @impl true
  def init(:ok) do
    estado = %{
      partidas: %{},
      por_usuario: %{},
      siguiente_id: 1001
    }

    {:ok, estado}
  end

  @impl true
  def handle_call({:crear, usuario, pid_receptor, tema, preguntas, tiempo}, _from, estado) do

    if Map.has_key?(estado.por_usuario, usuario) do #Revisa si el usuario ya está en una partida

      {:reply, {:error, :ya_en_partida}, estado}

    else

      nivel = Trivia.GestorJugadores.nivel_en_tema(usuario, tema)

      case Trivia.BancoPreguntas.validar_tema(tema, nivel, preguntas) do
        :ok ->

          id = "P-#{estado.siguiente_id}"

          argumentos = %{
            id: id,
            creador: usuario,
            tema: tema,
            nivel: nivel,
            total_preguntas: preguntas,
            tiempo_pregunta: tiempo,
            cliente: pid_receptor
          }

          case Trivia.SupervisorPartidas.iniciar_partida(argumentos) do
            {:ok, pid} ->

              por_usuario = Map.put(estado.por_usuario, usuario, id)  #Conecta al usuario con la partida creada

              datos_partida = %{
                pid: pid,
                creador: usuario,
                jugadores: [usuario],
                pid_receptor: pid_receptor
              }

              partidas = Map.put(estado.partidas, id, datos_partida)

              nuevo_estado = %{
                estado
                |por_usuario: por_usuario,
                partidas: partidas,
                siguiente_id: estado.siguiente_id + 1
              }

              {:reply, {:ok, %{id: id, nivel: nivel}}, nuevo_estado}

            {:error, motivo} ->
              {:reply, {:error, motivo}, estado}
          end
        {:error, :tema_no_disponible} ->
          {:reply, {:error, :tema_no_disponible}, estado}

        otro_error ->
          {:reply, otro_error, estado}
      end
    end
  end


  def partida_de(usuario) do
    GenServer.call(
      __MODULE__,
      {:partida_de, usuario}
    )
  end

  @impl true
  def handle_call({:partida_de, usuario}, _from, estado) do
    case Map.get(estado.por_usuario, usuario) do
      nil ->
        {:reply, {:error, :sin_partida}, estado}

      id_partida ->
        case Map.get(estado.partidas, id_partida) do
          nil ->
            {:reply, {:error, :sin_partida}, estado}

          datos_partida ->
            {:reply, {:ok, datos_partida.pid}, estado}
        end
    end
  end

  def agregar_bot(usuario, dificultad) do
    GenServer.call(
      __MODULE__,
      {:agregar_bot, usuario, dificultad}
    )
  end

  @impl true
  def handle_call({:agregar_bot, usuario, dificultad}, _from, estado) do

    case Map.get(estado.por_usuario, usuario) do
      nil ->
        {:reply, {:error, :sin_partida}, estado}

      id_partida ->
        case Map.get(estado.partidas, id_partida) do
          nil ->
            {:reply, {:error, :sin_partida}, estado}

          datos_partida ->
            dificultad_atom =
              case dificultad do
                "facil" -> :facil
                "medio" -> :medio
                "dificil" -> :dificil
                :facil -> :facil
                :medio -> :medio
                :dificil -> :dificil
                _ -> nil
              end

            resultado =
              if dificultad_atom do
                Trivia.Partida.add_bot(datos_partida.pid, dificultad_atom)
              else
                {:error, :dificultad_invalida}
              end
            {:reply, resultado, estado}
        end
    end
  end

  def iniciar_partida(usuario) do
    GenServer.call(
      __MODULE__,
      {:iniciar_partida, usuario}
    )
  end

  @impl true
  def handle_call({:iniciar_partida, usuario}, _from, estado) do

    case Map.get(estado.por_usuario, usuario) do
      nil ->
        {:reply, {:error, :sin_partida}, estado}

      id_partida ->

        case Map.get(estado.partidas, id_partida) do
          nil ->
            {:reply, {:error, :sin_partida}, estado}

          datos_partida ->
            resultado = Trivia.Partida.start_game(datos_partida.pid)

            {:reply, resultado, estado}
        end
    end
  end

  def responder(usuario, letra) do
    GenServer.call(
      __MODULE__,
      {:responder, usuario, letra}
    )
  end

  @impl true
  def handle_call({:responder, usuario, letra}, _from, estado) do

    case Map.get(estado.por_usuario, usuario) do
      nil ->
        {:reply, {:error, :sin_partida}, estado}

      id_partida ->

        case Map.get(estado.partidas, id_partida) do
          nil ->
            {:reply, {:error, :sin_partida}, estado}

          datos_partida ->
            resultado =
              Trivia.Partida.responder(
                datos_partida.pid,
                usuario,
                letra
              )

            # Devuelve el resultado recibido
            {:reply, resultado, estado}
        end
    end
  end

  def abandonar(usuario) do
    GenServer.call(
      __MODULE__,
      {:abandonar, usuario}
    )
  end

  @impl true
  def handle_call({:abandonar, usuario}, _from, estado) do

    case Map.get(estado.por_usuario, usuario) do
      nil ->
        {:reply, {:error, :sin_partida}, estado}

      id_partida ->

        case Map.get(estado.partidas, id_partida) do
          nil ->
            {:reply, {:error, :sin_partida}, estado}

          datos_partida ->

            resultado =
              Trivia.Partida.leave(
                datos_partida.pid,
                usuario
              )
            {:reply, resultado, estado}
        end
    end
  end


  def cliente_caido(usuario) do
    GenServer.cast(
      __MODULE__,
      {:cliente_caido, usuario}
    )
  end

  @impl true
  def handle_cast({:cliente_caido, usuario}, estado) do
    # Busca la partida del usuario
    case Map.get(estado.por_usuario, usuario) do
      nil ->
        {:noreply, estado}

      id_partida ->
        # Busca los datos de la partida
        case Map.get(estado.partidas, id_partida) do
          nil ->
            {:noreply, estado}

          datos_partida ->
            # Aplica la misma regla de abandono
            Trivia.Partida.leave(
              datos_partida.pid,
              usuario
            )

            {:noreply, estado}
        end
    end
  end

  def registrar_partida(id, pid) do
    GenServer.cast(
      __MODULE__,
      {:partida_lista, id, pid}
    )
  end

  @impl true
  def handle_cast({:partida_lista, id, pid}, estado) do
    case Map.get(estado.partidas, id) do
      nil ->
        # Si la partida no existe, no modifica el estado
        {:noreply, estado}

      datos_partida ->
        # Comprueba si el PID cambió
        if datos_partida.pid == pid do
          # Es el mismo proceso, no hay reinicio
          {:noreply, estado}
        else
          # Actualiza el PID de la partida
          nuevos_datos = %{datos_partida | pid: pid}

          partidas = Map.put(
            estado.partidas,
            id,
            nuevos_datos
          )

          # Notifica al creador que su partida se reinició
          send(
            datos_partida.pid_receptor,
            {:partida_reiniciada, id}
          )

          # Actualiza el estado del gestor
          nuevo_estado = %{estado | partidas: partidas}

          {:noreply, nuevo_estado}
        end
    end
  end

  def partida_terminada(id) do
    GenServer.cast(
      __MODULE__,
      {:partida_terminada, id}
    )
  end

  @impl true
  def handle_cast({:partida_terminada, id}, estado) do
    # Busca los datos de la partida
    case Map.get(estado.partidas, id) do
      nil ->
        {:noreply, estado}

      datos_partida ->
        # Libera a todos los jugadores de esa partida
        por_usuario =
          Enum.reduce(
            datos_partida.jugadores,
            estado.por_usuario,
            fn usuario, acumulador ->
              Map.delete(acumulador, usuario)
            end
          )

        # Elimina la partida del mapa de partidas
        partidas = Map.delete(estado.partidas, id)

        # Actualiza el estado del gestor
        nuevo_estado = %{
          estado
          | por_usuario: por_usuario,
            partidas: partidas
        }

        {:noreply, nuevo_estado}
    end
  end
end
