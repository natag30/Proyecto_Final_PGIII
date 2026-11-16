# Uso de inteligencia artificial

Proyecto: Trivia Concurrente (Programación III, Universidad del Quindío)

Integrantes: Diego Rincon (rol A), Carlos Andres Ruiz (rol B) y Natalia García Hidalgo (rol C)

Este documento reúne, por integrante, las herramientas de inteligencia artificial que se usaron durante el proyecto, para qué se usaron, cómo ayudaron, qué hizo cada quien por su cuenta y qué conclusiones y aprendizajes quedaron.

## Resumen del equipo

| Integrante | Herramientas | Para qué se usaron |
|---|---|---|
| Diego Rincon | ChatGPT, GitHub Copilot y Claude | Estructurar y revisar `partida.ex` y `bot.ex`, detectar y corregir errores, y entender cómo ejecutar las pruebas |
| Carlos Andres Ruiz | ChatGPT | Base inicial de código para el servidor, el gestor y el supervisor de partidas y el cliente; comprensión de Elixir, GenServer y procesos; solución de errores e integración |
| Natalia García Hidalgo | Claude y GitHub Copilot | Guía para estructurar y desarrollar sus módulos y archivos de pruebas, revisión de errores y sugerencias de mejora, comprensión de Mix y de la integración entre módulos |

---

## Diego Rincon

**Herramientas utilizadas:** ChatGPT, GitHub Copilot y Claude (Anthropic). La bitácora de consultas que aparece abajo corresponde a Claude, usado en el chat web.

**Piezas a mi cargo:** `partida.ex`, `bot.ex` y las pruebas 1 (puntaje de ronda), 3 (validación de respuestas) y 6 (decisión del bot).

**Declaración:** el documento de organización del equipo y los esqueletos iniciales también se prepararon con Claude.

**Para qué las usé:**
Las usé para estructurar mi código, para que me indicaran si había errores y cuáles eran, y para consultar si estaba bien lo que llevaba en `partida.ex` y `bot.ex` y si la estructura que manejamos estaba completa o le faltaba algún punto. Así me indicaron que faltaba el acumulador de cada usuario. Con base en eso empecé a crear el código, y la IA me explicó si se iba realizando bien y, cuando había errores, cuál era el error y su corrección.

**Cómo me ayudaron** (bitácora de consultas):

| # | Pieza | Qué pregunté | Concepto o función nuevos para mí |
|---|---|---|---|
| 1 | Organización | Qué debía hacer y en qué orden | Funciones puras dentro del GenServer; `Process.send_after` |
| 2 | `bot.ex` | Por qué mi bot no compilaba ni se comportaba como pide el enunciado | `@moduledoc`, `end` por función, `start_link` sin `name:`, patrón con variable repetida |
| 3 | `partida.ex` | Dónde estaban los errores y qué le faltaba | `Map.get` frente a `Map.fetch!`, `cond` dentro de funciones, `with`, `handle_call` frente a `handle_info` |
| 4 | Ejecución | Por qué no corrían las pruebas | `mix test` frente a `elixir`, política de ejecución de PowerShell, `mix.bat` |

*Consulta 1: por dónde empezar el núcleo del juego.*
- Qué pregunté: me corresponde realizar el núcleo del juego; necesito saber cómo puedo iniciar sin que se afecte el trabajo de mis compañeros, o si se afecta, que realice cambios en `bot.ex` y `partida.ex`.
- Qué respondió la IA: que mis archivos eran `partida.ex` y `bot.ex`, y que conviene avanzar por capas: primero las funciones puras (puntaje y validación), luego la decisión del bot, después el GenServer con una ronda completa, y al final abandono y reinicio. Explicó que las funciones puras deben recibir los datos por parámetro para poder probarlas sin arrancar procesos.

*Consulta 2: mi `bot.ex` no compilaba.*
- Qué pregunté: si mi código de `bot.ex`, escrito a mi manera, estaba bien, y que me ayudara a ver si en lo que llevaba había errores.
- Qué respondió la IA: la estructura era correcta, pero faltaba el `end` de `decidir`; `@module` no existe (es `@moduledoc`); `name: __MODULE__` impedía tener dos bots; el retardo estaba en segundos y no en milisegundos; las ventanas de tiempo eran mayores a 1, por lo que el bot respondería siempre tarde; y `hadle_info` estaba mal escrito.

*Consulta 3: mi `partida.ex` y lo que le faltaba.*
- Qué pregunté: le envié mi archivo `partida.ex` para que me ayudara a ver si estaba bien y si había errores para continuar.
- Qué respondió la IA:
  - Errores de escritura: `puntos_rond`, `tiemoo`, `map.get` con minúscula, `is binary` sin guion bajo.
  - Un `cond` suelto fuera de una función, y `do:` mezclado con `end`.
  - Un `end` de más que dejaba `init` fuera del módulo.
  - Valores del enunciado: puntos de nivel intermedio {15, -8} y avanzado {20, -10}, máximo 4 jugadores, y la respuesta incorrecta sin bonificación.
  - Diseño: `validar_respuesta` debe decidir si la respuesta se acepta, no si es correcta.

*Consulta 4: por qué no corrían las pruebas.*
- Qué pregunté: cómo ejecutar `partida_test.exs` con la estructura del proyecto, y qué hacer con el error de PowerShell.
- Qué respondió la IA: que en un proyecto Mix las pruebas se corren con `mix test` desde la carpeta `trivia/` y no con `elixir archivo.exs`; que las pruebas no deben llamar a `ExUnit.start()` (ya está en `test_helper.exs`); y que `partida.ex` no debe cargar `bot.exs` a mano. El error de `mix.ps1` era la política de ejecución de PowerShell, y se resuelve con `mix.bat`, con CMD o con `Set-ExecutionPolicy`.

**Qué hice yo y qué corregí:**
Una de mis preguntas fue cómo ejecutar `partida_test.exs` con la estructura del proyecto y qué hacer con el error de PowerShell. La IA me indicó que la solución era usar `mix.bat`, y eso me permitió correr las pruebas de `partida.ex`, `bot.ex` y `partida_test.exs`.

La IA me sugirió manejar el tiempo por medio de `state.tiempo`, porque quería que funcionara con el `state`, pero eso me generaba un error. Lo corregí cambiándolo por solo `tiempo`, y así funcionó al correr el código.

**Conclusiones y aprendizajes:**
Pude observar que, frente a la lógica que he aprendido, la IA maneja conceptos muy avanzados y cambia la metodología, mas no la función, para realizar un mejor proceso. Si nosotros no hacemos la organización frente al manejo de la IA, es imposible generar un proyecto funcional y completo. Frente a las soluciones, se logró un manejo eficaz del código que realizamos en el proyecto, y la IA nos ayuda a detectar errores. Nos ayuda a realizar y adelantar el trabajo, pero no complementa la lógica que pretendemos tener frente a la creación de un proyecto. Es una ayuda para facilitar nuestro trabajo, pero sin una buena estructuración no logramos cumplir con el objetivo previsto.

---

## Carlos Andres Ruiz

**Herramientas utilizadas:** ChatGPT.

**Para qué la usé:**
Usé ChatGPT como herramienta de apoyo durante el desarrollo de mi parte del proyecto Trivia Concurrente. Principalmente, la usé para:
- **Desarrollar el código:** obtener una base inicial para crear los módulos que tenía asignados: `Trivia.Servidor`, `Trivia.GestorPartidas`, `Trivia.SupervisorPartidas` y `Trivia.Cliente`.
- **Comprender Elixir:** entender cómo funcionan los procesos, los GenServer, los mensajes y la comunicación entre módulos.
- **Solucionar errores:** recibir ayuda cuando tenía problemas de lógica, errores en funciones o dificultades al integrar mi código con el de mis compañeros.
- **Comprender las funciones:** solicitar explicaciones línea por línea para entender qué hacía cada instrucción y por qué se utilizaba.

**Cómo me ayudó:**
ChatGPT me ayudó proporcionándome una base inicial del código y mostrándome por qué se hacía de determinada manera y cómo funcionaba cada línea. Esto me dio una guía para saber cómo continuar desarrollando el proyecto.

Cuando tenía problemas de lógica o una función me generaba errores, le pedía que me ayudara a identificar el problema y me explicara por qué sucedía. Primero intentaba corregirlo por mi cuenta, pero si no lo conseguía, le pedía que me orientara y me explicara el código línea por línea.

También me ayudó durante la integración con mis compañeros, porque podía compartir los errores que aparecían y entender cuál era el problema o en qué módulo debía revisar el código.

Por ejemplo, aprendí la diferencia entre `GenServer.call/3`, que permite enviar una solicitud y esperar una respuesta, y `GenServer.cast/2`, que envía un mensaje sin esperar una respuesta.

**Qué hice yo y qué corregí:**
Aunque usé ChatGPT para obtener una base inicial, fui desarrollando mi parte del proyecto paso a paso, revisando las explicaciones y tratando de comprender la lógica de cada función. En concreto:
- Revisé el código propuesto y comprendí su funcionamiento antes de utilizarlo.
- Adapté las soluciones a la estructura y los nombres de los módulos de nuestro proyecto.
- Intenté solucionar los errores por mi cuenta antes de solicitar más ayuda.
- Corregí problemas de lógica y revisé errores de compilación.
- Configuré el entorno de desarrollo cuando Visual Studio Code no reconocía los comandos de Mix.

También tuve que revisar problemas que aparecieron durante la integración. Por ejemplo, algunas pruebas indicaron que faltaban funciones en el módulo de partidas de otro integrante, por lo que fue necesario identificar que el problema estaba relacionado con la conexión entre los módulos.

**Conclusiones y aprendizajes:**
El uso de inteligencia artificial fue de gran ayuda durante el desarrollo del proyecto, especialmente porque me permitió tener una base para comenzar a programar y comprender conceptos de Elixir que inicialmente no dominaba.

Aprendí sobre el funcionamiento de GenServer, la comunicación entre procesos, el uso de supervisores y la diferencia entre las llamadas sincrónicas y asincrónicas.

También comprendí que desarrollar un proyecto en equipo implica más que hacer funcionar cada módulo por separado. Es necesario que todos los integrantes coordinen las funciones, los parámetros y la forma en que se comunican sus módulos.

Entre las principales dificultades estuvieron comprender algunos errores de lógica, solucionar problemas de compilación, configurar el entorno de desarrollo e integrar el código de mis compañeros.

Finalmente, considero que ChatGPT fue una herramienta de apoyo para mi aprendizaje, pero también comprendí que es importante analizar las respuestas, comprobar el código y no aceptar todas las soluciones sin entenderlas. Me permitió fortalecer mis habilidades de programación, resolución de problemas, análisis de errores y trabajo en equipo.

---

## Natalia García Hidalgo

**Herramientas utilizadas:** Claude (Anthropic) y GitHub Copilot (en Visual Studio Code).

**Piezas a mi cargo:** los módulos `errores`, `nivel`, `banco_preguntas`, `persistencia`, `gestor_jugadores` y `receptor`, y sus archivos de pruebas.

**Para qué las usé:**
- **Claude:**
  - Guía para estructurar cada módulo y cada archivo de pruebas, y para saber qué módulos de Elixir usar en cada función.
  - Explicación de conceptos de Elixir.
  - Revisión de errores y sugerencias de mejora del código.
  - Comprender cómo funciona Mix y cómo se conectan los módulos del proyecto.
  - Ayuda con el guion del video y el README.
- **GitHub Copilot:** revisar y corregir mi código dentro del editor, y recibir opciones para mejorarlo. También había escrito unas pruebas, que usé solamente como guía de cómo se escriben.

**Cómo me ayudaron:**
Claude me fue pasando la estructura de cada archivo, y yo fui agregando el desarrollo de cada función, implementando los módulos de Elixir que me recomendaba usar. Me dio sugerencias de mejora para el código. Fue fundamental para entender cómo funciona Mix, cómo se conectaba el proyecto y cómo evitar que nos pisáramos entre compañeros o repitiéramos funciones que ya había hecho otro integrante, como nos pasó en el parcial 2.

También fue fundamental para entender cómo se escriben las pruebas. Aunque ya tenía experiencia con pruebas en Java, en Elixir se manejan comandos distintos, y necesitaba comprender la estructura de los archivos.

Copilot me ayudó en Visual Studio Code a ir revisando y corrigiendo lo que me faltaba o estaba mal, y me ofrecía opciones para mejorar el código.

**Qué hice yo y qué corregí:**
El código de mis módulos lo escribí yo, guiándome con las estructuras que me pasaba Claude para cada archivo, y agregando el desarrollo de cada función. Los archivos de pruebas los construí con la guía que me pasó Claude; las pruebas que había escrito Copilot solo me sirvieron como referencia de cómo se escriben.

Entre mis errores, a veces no daba a las funciones los parámetros que necesitaban, o la salida de mis funciones no era la que esperaban las demás funciones del proyecto. Con la ayuda de Copilot en el editor y las sugerencias de Claude fui revisando y corrigiendo lo que faltaba o estaba mal, y comprobé cada módulo ejecutando sus pruebas con `mix test`.

**Conclusiones y aprendizajes:**
La IA es una herramienta muy importante en esta etapa del avance tecnológico, pero es necesario usarla de forma consciente: sin hacer que realice todo el trabajo, sino como una ayuda para ir construyendo las cosas paso a paso y entendiendo de qué manera se realizan.

Fue primordial para comprender cómo funciona Mix, cómo se conectaba el proyecto y cómo coordinarnos para no pasar unos por encima de otros ni repetir funciones que ya habían hecho los compañeros. También lo fue para entender cómo escribir las pruebas en Elixir y cuál es la estructura de sus archivos.

---

## Reflexión del equipo

**Dónde ayudó más la IA:** en comprender conceptos nuevos de Elixir (procesos, GenServer, supervisores, Mix y pruebas), en detectar y entender errores de compilación y de lógica, y en recibir sugerencias de mejora del código.

**Qué tuvimos que corregir o descartar:** adaptar el código y las sugerencias a los nombres y la estructura de nuestros módulos; corregir parámetros y salidas de funciones que no coincidían entre módulos de distintos integrantes; y resolver problemas de configuración del entorno (Mix en Visual Studio Code y la política de ejecución de PowerShell).

**Cómo verificamos el código:** con las pruebas automáticas (`mix test`) y probando el programa con un servidor y varios clientes en consolas distintas, con partidas simultáneas.

**Organización del equipo:** el documento de organización del equipo y los esqueletos iniciales se prepararon con Claude.

**Redacción de este documento:** Claude ayudó a redactar y organizar este archivo. Toda la información que contiene (herramientas, usos, ayudas, correcciones, conclusiones y aprendizajes) la aportó cada integrante con sus propios textos; Claude solo los ordenó y ajustó la redacción.

**Responsabilidad:** la IA fue una ayuda para entender y avanzar, no un sustituto de nuestro trabajo. El código entregado fue revisado, comprendido y probado por los integrantes del equipo, que respondemos por él.