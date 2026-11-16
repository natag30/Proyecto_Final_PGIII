# Trivia Concurrente

Trivia por consola, hecha en Elixir, donde varios jugadores y bots juegan al mismo tiempo en partidas independientes. Proyecto final de Programación III, Universidad del Quindío.

## Integrantes

| Integrante | 
|---|
| Diego Rincon | 
| Carlos Andres Ruiz | 
| Natalia García Hidalgo | 

## Descripción

El sistema tiene un **servidor** y varios **clientes**, cada uno en su propia consola y conectado como un nodo distinto de Erlang.

- El servidor es el único que lee y escribe archivos (usuarios, banco de preguntas e historial). Los clientes solo envían comandos y muestran las respuestas.
- Cada partida es un proceso independiente, supervisado: si una falla, las demás y el servidor siguen funcionando. Cada bot también es un proceso.
- Se pueden jugar varias partidas al mismo tiempo.
- Los datos (usuarios, puntajes, niveles e historial) se conservan al reiniciar el servidor.

## Requisitos

- Elixir 1.20 o superior (con Erlang/OTP incluido).
- Dependencia: `jason` (se instala con `mix deps.get`).

## Compilación

Desde la carpeta `trivia/`:

```
cd trivia
mix deps.get
mix compile
```

## Pruebas

```
mix test
```

## Arranque del servidor

Desde la carpeta `trivia/`, en una terminal:

```
iex --sname servidor -S mix
```

En Windows (PowerShell) se usa `iex.bat --sname servidor -S mix`.

Cuando aparezca el prompt `iex(servidor@NOMBRE-PC)1>`, iniciar el servidor:

```elixir
Trivia.Servidor.iniciar()
```

Debe responder `:ok`. El texto después de la `@` en el prompt (`NOMBRE-PC` en el ejemplo) es el nombre de la máquina; se necesita para conectar los clientes.

> El servidor debe iniciarse desde la carpeta `trivia/`, porque lee y escribe en `data/`.

## Conexión de los clientes

Cada cliente va en **otra terminal**, también desde la carpeta `trivia/`, con un nombre de nodo distinto:

```
iex --sname ana -S mix
```

```
iex --sname luis -S mix
```

(En Windows, `iex.bat`.) Luego, en cada cliente, conectarse al nodo del servidor:

```elixir
Trivia.Cliente.iniciar(:"servidor@NOMBRE-PC")
```

Reemplazar `NOMBRE-PC` por el nombre de la máquina donde corre el servidor. Aparece el prompt `Trivia >`, donde se escriben los comandos.

**Cookie:** el proyecto no define una cookie propia. Si todos los nodos corren en la misma máquina y el mismo usuario, Erlang usa la cookie por defecto (`~/.erlang.cookie`) y no hay que hacer nada. Si los nodos corren en máquinas distintas, todos deben iniciarse con la misma cookie, por ejemplo `iex --sname servidor --cookie trivia -S mix`.

## Comandos del cliente

| Comando | Descripción |
|---|---|
| `connect usuario clave` | Inicia sesión. Si el usuario no existe, lo registra. Los nombres que empiezan por `bot_` están reservados. |
| `disconnect` | Cierra la sesión. |
| `score` | Muestra el puntaje total, las partidas jugadas y el nivel en cada tema. |
| `ranking` | Ranking histórico global. |
| `ranking tema` | Ranking histórico de un tema (por ejemplo `ranking ciencia`). |
| `create_game tema=ciencia preguntas=5 tiempo=15` | Crea una partida: tema, cantidad de preguntas y segundos por ronda. |
| `add_bot facil` / `add_bot dificil` | Agrega un bot a la partida. |
| `start_game` | Inicia la partida. Requiere al menos 2 bots. |
| `answer A` | Responde la pregunta actual. Siempre se escribe `answer` seguido de la letra (A, B, C o D); escribir solo la letra no es un comando válido. |
| `leave_game` | Abandona la partida actual. |

Cada ronda dura los segundos indicados en `tiempo`; se recomienda 15 o más para alcanzar a escribir la respuesta.

Temas disponibles: `ciencia`, `colombia`, `geografia`, `historia` y `programacion`.

### Ejemplo de una partida

```
Trivia > connect ana 1234
Trivia > create_game tema=ciencia preguntas=2 tiempo=10
Trivia > add_bot facil
Trivia > add_bot dificil
Trivia > start_game
Trivia > answer B
Trivia > answer A
Trivia > score
```

## Reglas del juego

### Niveles

El nivel se calcula automáticamente por tema, según el puntaje acumulado en ese tema, y se fija al crear la partida. El jugador no lo elige.

| Nivel | Puntaje en el tema |
|---|---|
| Básico | menos de 60 |
| Intermedio | de 60 a 179 |
| Avanzado | 180 o más |

El nivel decide qué preguntas se sortean:

| Nivel del jugador | Básicas | Intermedias | Avanzadas |
|---|---|---|---|
| Básico | 70 % | 30 % | 0 % |
| Intermedio | 20 % | 60 % | 20 % |
| Avanzado | 0 % | 30 % | 70 % |

Las preguntas se presentan de menor a mayor nivel.

### Puntaje por ronda

| Resultado | Pregunta básica | Intermedia | Avanzada |
|---|---|---|---|
| Correcta | +10 | +15 | +20 |
| Incorrecta | -5 | -8 | -10 |
| Sin responder | 0 | 0 | 0 |

A una respuesta correcta se le suma una bonificación de 0 a 5 puntos según qué tan rápido se respondió. La ronda cierra cuando todos los jugadores responden o se acaba el tiempo.

### Bots

- `facil`: acierta menos y responde más tarde.
- `dificil`: acierta más y responde más rápido.
- Los bots puntúan dentro de la partida y salen en su ranking final, pero no se guardan como usuarios ni entran al ranking histórico.
- Cada partida lleva entre 3 y 4 jugadores; se necesitan al menos 2 bots para iniciar.

## Datos

| Archivo | Contenido |
|---|---|
| `data/questions.json` | Banco de 150 preguntas: 5 temas con 30 preguntas cada uno, con su nivel. |
| `data/users.json` | Usuarios registrados, con su puntaje y nivel por tema. Se crea al registrar el primer usuario. |
| `data/results.log` | Historial de partidas terminadas. |

Para empezar desde cero, detener el servidor y borrar `data/users.json` y `data/results.log`.

## Estructura del código

| Módulo | Función |
|---|---|
| `Trivia.Servidor` | Punto de entrada: recibe los comandos de los clientes. |
| `Trivia.Cliente` | Lee los comandos de la consola y muestra las respuestas. |
| `Trivia.GestorJugadores` | Registro, sesiones y estadísticas de los usuarios. |
| `Trivia.GestorPartidas` / `Trivia.SupervisorPartidas` | Creación y supervisión de las partidas. |
| `Trivia.Partida` | Una partida: rondas, tiempos y puntajes. |
| `Trivia.Bot` | Decisión de los bots. |
| `Trivia.BancoPreguntas` | Carga y sorteo de preguntas. |
| `Trivia.Nivel` | Cálculo de nivel y reparto de preguntas. |
| `Trivia.Persistencia` | Lectura y escritura de los archivos de `data/`. |
| `Trivia.Receptor` | Formato de los mensajes que ve el jugador. |
| `Trivia.Errores` | Mensajes de error. |

## Funcionalidades no implementadas

- Extensión opcional para que varias personas jueguen en una misma partida (`list_games` y `join_game`).

## Uso de inteligencia artificial

La documentación del uso de herramientas de IA está en [USO_IA.md](USO_IA.md).