#Autor: Carlos Andres

defmodule Trivia.Cliente do

  def iniciar(nodo_servidor) do
    case conectar(nodo_servidor) do
      :ok ->
        IO.puts("Conectado al servidor de Trivia")

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
end
