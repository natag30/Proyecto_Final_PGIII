# Autor: Carlos Andres

defmodule Trivia.Cliente do
  def iniciar(nodo_servidor) do
    case conectar(nodo_servidor) do
      :ok ->
        Process.put(:nodo_servidor, nodo_servidor)
        IO.puts("Conectado al servidor de Trivia")
        leer_comandos()

      :error ->
        IO.puts(Trivia.Errores.mensaje(:servidor_no_disponible))
        {:error, :servidor_no_disponible}
    end
  end

  defp conectar(nodo_servidor) do
    case Node.connect(nodo_servidor) do
      true -> :ok
      false -> :error
      :ignored -> :error
    end
  end

  defp leer_comandos do
    case IO.gets("\nTrivia > ") do
      texto when is_binary(texto) ->
        case texto |> String.trim() |> procesar_comando() do
          :salir -> IO.puts("\nCliente cerrado.")
          _ -> leer_comandos()
        end

      _fin_de_entrada ->
        IO.puts("\nCerrando cliente...")
    end
  end

  # Procesa el texto ingresado por el jugador.
  defp procesar_comando(comando) do
    case parsear_comando(comando) do
      {:error, motivo} ->
        IO.puts("\n" <> Trivia.Errores.mensaje(motivo))

      {:ok, {:create_game, tema, preguntas, tiempo} = peticion} ->
        case iniciar_receptor() do
          {:ok, pid_receptor} ->
            respuesta = enviar({:create_game, tema, preguntas, tiempo, pid_receptor})
            mostrar_respuesta(peticion, respuesta)

          {:error, motivo} ->
            IO.inspect(motivo, label: "Error al iniciar receptor")
        end

      {:ok, peticion} ->
        respuesta = enviar(peticion)
        mostrar_respuesta(peticion, respuesta)

        if peticion == {:disconnect} and respuesta == :ok, do: :salir, else: :continuar
    end
  end

  def parsear_comando(comando) do
    case String.split(comando, ~r/\s+/, trim: true) do
      ["connect", usuario, clave] ->
        {:ok, {:connect, usuario, clave}}

      ["create_game", "tema=" <> tema, "preguntas=" <> preguntas, "tiempo=" <> tiempo] ->
        with {:ok, cantidad} <- convertir_entero(preguntas),
             {:ok, segundos} <- convertir_entero(tiempo) do
          if cantidad > 0 and segundos > 0 do
            {:ok, {:create_game, tema, cantidad, segundos}}
          else
            {:error, :parametros_invalidos}
          end
        else
          _ -> {:error, :comando_invalido}
        end

      ["add_bot", "facil"] ->
        {:ok, {:add_bot, :facil}}

      ["add_bot", "dificil"] ->
        {:ok, {:add_bot, :dificil}}

      ["start_game"] ->
        {:ok, {:start_game}}

      ["answer", letra] ->
        {:ok, {:answer, String.upcase(letra)}}

      ["score"] ->
        {:ok, {:score}}

      ["ranking"] ->
        {:ok, {:ranking, nil}}

      ["ranking", tema] ->
        {:ok, {:ranking, tema}}

      ["leave_game"] ->
        {:ok, {:leave_game}}

      ["disconnect"] ->
        {:ok, {:disconnect}}

      _ ->
        {:error, :comando_invalido}
    end
  end

  defp convertir_entero(texto) do
    case Integer.parse(texto) do
      {numero, ""} -> {:ok, numero}
      _ -> :error
    end
  end

  def enviar(peticion) do
    GenServer.call({Trivia.Servidor.nombre(), nodo_servidor()}, peticion)
  catch
    :exit, _ -> {:error, :servidor_no_disponible}
  end

  # Obtiene el nodo del servidor al que está conectado el cliente.
  defp nodo_servidor do
    Process.get(:nodo_servidor)
  end

  defp iniciar_receptor do
    case Trivia.Receptor.iniciar() do
      {:ok, pid_receptor} ->
        Process.put(:pid_receptor, pid_receptor)
        {:ok, pid_receptor}

      {:error, motivo} ->
        {:error, motivo}
    end
  end

  def mostrar_respuesta(peticion, respuesta) do
    case {peticion, respuesta} do
      {_, {:error, motivo}} ->
        IO.puts("\n" <> Trivia.Errores.mensaje(motivo))

      {{:score}, {:ok, resumen}} ->
        mostrar_resumen(resumen)

      {{:ranking, _tema}, {:ok, filas}} ->
        mostrar_ranking(filas)

      {{:create_game, _, _, _}, {:ok, %{id: id, nivel: nivel}}} ->
        IO.puts(
          "\nPartida #{id} creada (nivel #{nivel}). Agrega bots con add_bot y luego start_game."
        )

      {{:connect, _, _}, {:ok, :registrado}} ->
        IO.puts("\nUsuario nuevo registrado. Sesión iniciada.")

      {{:connect, _, _}, {:ok, :existente}} ->
        IO.puts("\nSesión iniciada.")

      {{:add_bot, _}, {:ok, nombre}} ->
        IO.puts("\nBot #{nombre} agregado a la partida.")

      {{:answer, _}, {:ok, :registrada}} ->
        IO.puts("\nRespuesta registrada.")

      {{:answer, _}, {:ok, :ignorada}} ->
        IO.puts("\nYa habías respondido a esta pregunta; se ignora.")

      {{:start_game}, :ok} ->
        IO.puts("\nLa partida comenzó.")

      {{:leave_game}, :ok} ->
        IO.puts("\nHas abandonado la partida.")

      {{:disconnect}, :ok} ->
        IO.puts("\nSesión cerrada.")

      {_, :ok} ->
        IO.puts("\nListo.")

      {_, {:ok, resultado}} ->
        IO.puts("\nListo: #{inspect(resultado)}")

      {_, otra} ->
        IO.inspect(otra, label: "Respuesta del servidor")
    end
  end

  def mostrar_resumen(resumen) do
    IO.puts("\nJugador: #{resumen.usuario}")
    IO.puts("Puntaje total: #{resumen.total}")
    IO.puts("Partidas jugadas: #{resumen.partidas}")

    case Enum.sort(resumen.niveles) do
      [] ->
        IO.puts("Aún no tienes nivel en ningún tema.")

      niveles ->
        IO.puts("Nivel por tema:")

        Enum.each(niveles, fn {tema, nivel} ->
          IO.puts("  " <> String.pad_trailing(tema, 14) <> "#{nivel}")
        end)
    end

    :ok
  end

  def mostrar_ranking([]), do: IO.puts("\nTodavía no hay partidas en el ranking.")

  def mostrar_ranking(filas) do
    IO.puts(
      "\n" <>
        String.pad_trailing("#", 6) <> String.pad_trailing("Jugador", 15) <> "Puntaje  Partidas"
    )

    filas
    |> Enum.with_index(1)
    |> Enum.each(fn {fila, posicion} ->
      IO.puts(
        String.pad_trailing("#{posicion}", 6) <>
          String.pad_trailing(fila.usuario, 15) <>
          String.pad_leading("#{fila.puntaje}", 7) <>
          String.pad_leading("#{fila.partidas}", 10)
      )
    end)

    :ok
  end
end
