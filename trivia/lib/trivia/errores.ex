# Autora: Natalia García

defmodule Trivia.Errores do
  @moduledoc """
  Módulo que contiene los mensajes de error para la aplicación Trivia.
  Cada función `mensaje/1` recibe un átomo que representa el tipo de error y devuelve un mensaje de error correspondiente.
  """

  @doc """
  Devuelve un mensaje de error basado en el tipo de error proporcionado.
  Cualquier error no reconocido devuelve un mensaje genérico de error inesperado.
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
      "Ya estás en una partida. Por favor, termina la partida actual utilizando el comando leave_game, antes de crear otra."

  def mensaje(:tema_no_disponible),
    do:
      "El tema seleccionado no existe o no contiene suficientes preguntas. Por favor, elige otro tema."

  def mensaje(:sin_partida),
    do:
      "Debes dar inicio a una partida primero. Usa el comando create_game para iniciar una nueva partida."

  def mensaje(:partida_cerrada),
    do: "La partida ya está llena o ya comenzó. No es posible unir más jugadores o bots."

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

  def mensaje(:partida_iniciada),
    do: "La partida ya comenzó. No es posible agregar más bots ni iniciarla de nuevo."

  def mensaje(:partida_llena),
    do: "La partida ya está llena. No es posible agregar más jugadores o bots."

  def mensaje(:ronda_cerrada),
    do: "Espera a la pregunta antes de contestar. No hay una ronda abierta actualmente."

  def mensaje(:ya_respondio),
    do: "Ya respondiste esta pregunta. Espera a la siguiente ronda."

  def mensaje(:no_participa),
    do: "No participas en esta partida."

  def mensaje(:dificultad_invalida),
    do: "La dificultad no es válida. Usa facil o dificil."

  def mensaje(:parametros_invalidos),
    do: "La cantidad de preguntas y el tiempo deben ser enteros mayores que cero."

  def mensaje(_otro), do: "Ocurrió un error inesperado. Por favor, intenta nuevamente más tarde."
end
