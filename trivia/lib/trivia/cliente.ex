#Autor: Carlos Andres

defmodule Trivia.Cliente do

  def iniciar(nodo_servidor) do
    case conectar(nodo_servidor) do
      :ok ->
        Process.put(:nodo_servidor, nodo_servidor)
        IO.puts("Conectado al servidor de Trivia")
        leer_comandos()

      :error ->
        IO.puts("No fue posible conectar con el servidor")
    end
  end

  defp conectar(nodo_servidor) do
    case Node.connect(nodo_servidor) do
      true -> :ok
      false -> :error
      :ignored  -> :error
    end
  end

   defp leer_comandos do
    comando = IO.gets("\nTrivia > ")

    case comando do
      nil ->
        IO.puts("Cerrando cliente...")

      comando ->
        comando
        |> String.trim()
        |> procesar_comando()

        leer_comandos()
    end
  end

  # Procesa el texto ingresado por el jugador.
  defp procesar_comando(comando) do
    case parsear_comando(comando) do
      {:error, :comando_vacio} ->
        IO.puts("Debes escribir un comando.")

      {:error, :comando_desconocido} ->
        IO.puts("El comando no existe.")

      {:error, :uso_incorrecto} ->
        IO.puts("Los argumentos del comando son incorrectos.")

      peticion ->
        IO.inspect(peticion, label: "Petición interpretada")
    end
  end


    def parsear_comando(comando) do
    case String.split(String.trim(comando), ~r/\s+/, trim: true) do

      ["connect", usuario, clave] ->
        {:connect, usuario, clave}

      ["create_game", "tema=" <> tema, "preguntas=" <> preguntas, "tiempo=" <> tiempo] ->
        with {:ok, cantidad} <- convertir_entero(preguntas),
             {:ok, segundos} <- convertir_entero(tiempo) do
          {:create_game, tema, cantidad, segundos}
        else
          _ -> {:error, :uso_incorrecto}
        end

      ["add_bot", dificultad] when dificultad in ["facil", "dificil"] ->
        {:add_bot, dificultad}

      ["start_game"] ->
        {:start_game}

      ["answer", letra] ->
        {:answer, String.upcase(letra)}

      ["score"] ->
        {:score}

      ["ranking"] ->
        {:ranking, nil}

      ["ranking", tema] ->
        {:ranking, tema}

      ["leave_game"] ->
        {:leave_game}

      ["disconnect"] ->
        {:disconnect}

      [] ->
        {:error, :comando_vacio}

      _ ->
        {:error, :comando_desconocido}
    end
  end

  defp convertir_entero(texto) do
    case Integer.parse(texto) do
      {numero, ""} -> {:ok, numero}
      _ -> :error
    end
  end

    def enviar(peticion) do
    GenServer.call(
      {Trivia.Servidor.nombre(), nodo_servidor()},
      peticion
    )
  end

  # Obtiene el nodo del servidor al que está conectado el cliente.
  defp nodo_servidor do
    Process.get(:nodo_servidor)
  end

  def mostrar_respuesta(comando, respuesta) do
    case respuesta do
      {:ok, resultado} ->
        IO.puts("\nOperación realizada correctamente.")
        IO.inspect(resultado, label: comando)

      {:error, motivo} ->
        IO.puts("\nNo se pudo realizar la operación.")
        IO.inspect(motivo, label: "Error")

      otra_respuesta ->
        IO.inspect(otra_respuesta, label: "Respuesta del servidor")
    end
  end

  def mostrar_resumen(resumen) do
    IO.puts("\n========== RESUMEN DE PARTIDA ==========")

    IO.inspect(
      resumen,
      label: "Información de la partida",
      pretty: true
    )

    IO.puts("========================================")
  end

  def mostrar_ranking(ranking) do
    IO.puts("\n========== RANKING DE TRIVIA ==========")

    IO.inspect(
      ranking,
      label: "Clasificación de jugadores",
      pretty: true
    )

    IO.puts("=======================================")
  end
end
