defmodule Trivia.Errores do
  @moduledoc """
  Módulo que contiene los mensajes de error para la aplicación Trivia.
  Cada función `mensaje/1` recibe un átomo que representa el tipo de error y devuelve un mensaje de error correspondiente.
  """
  def mensaje(:sin_sesion),
    do: "No hay sesión iniciada. Por favor, inicia sesión usando el comando connect."

  def mensaje(:clave_incorrecta),
    do: "La clave proporcionada es incorrecta. Por favor, verifícala e intenta nuevamente."

  def mensaje(:sesion_duplicada),
    do:
      "El usuario ya tiene una sesión activa en otro cliente. Por favor, cierra la sesión en el otro cliente antes de intentar iniciar sesión desde aquí."

  def mensaje(:usuario_reservado),
    do:
      "El nombre de usuario que intentas usar está reservado. Por favor, elige otro nombre de usuario."

  def mensaje(:servidor_no_disponible),
    do: "El servidor no responde. Por favor verifica que esté encendido."

  def mensaje(:ya_en_partida),
    do:
      "Ya estás en una partida. Por favor, termina la partida actual utilizando el comando leave_game, antes de crear a otra."

  def mensaje(:tema_no_disponible),
    do:
      "El tema seleccionado no existe o no contiene suficientes preguntas. Por favor, elige otro tema."

  def mensaje(:sin_partida),
    do:
      "Debes dar inicio a una partida primero. Usa el comando create_game para iniciar una nueva partida."

  def mensaje(:partida_cerrada),
    do: "La partida ya está llena o ya comenzó. No es posible unir más jugadores."

  def mensaje(:bots_insuficientes),
    do:
      "No hay suficientes bots para iniciar la partida. Asegúrate de tener al menos 2 bots agregados (add_bot) antes de iniciar la partida."

  def mensaje(:letra_invalida),
    do:
      "La letra ingresada no es una respuesta válida. Vuelve a intentar ingresando una letra de la A a la D."

  def mensaje(:sin_ronda_abierta),
    do: "Espera a la pregunta antes de contestar. No hay una ronda abierta actualmente."

  def mensaje(:comando_invalido),
    do:
      "El comando ingresado no se reconoce. Por favor, verifica la sintaxis del comando e intenta nuevamente."

  def mensaje(_otro), do: "Ocurrió un error inesperado. Por favor, intenta nuevamente más tarde."
end
