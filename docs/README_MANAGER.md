# CallVote Manager

Satélite opcional de política y mensajes sobre `callvote_core` 3.0.0.
Manager 2.2.1 no mantiene historial, no escribe SQL y no produce el lifecycle.
El contrato compartido pertenece a [`callvote_core.inc`](../addons/sourcemod/scripting/include/callvote_core.inc).

## Flujo

| Callback del core | Responsabilidad de Manager |
|---|---|
| `CallVote_PreStart` | Evaluar reglas, proponer un motivo y vetar con `Plugin_Handled` si corresponde. |
| `CallVote_Blocked` | Dar feedback cuando el motivo final coincide con la regla que Manager vetó en esa sesión. |
| `CallVote_Start` | Registrar el inicio confirmado, preparar el progreso y anunciar la votación. |
| `CallVote_BallotCast` | Presentar respuestas observadas del motor dentro de la sesión confirmada. |
| `CallVote_End` | Liberar el contexto de esa sesión, incluso si terminó bloqueada o sin inicio. |

Manager no escucha `vote_cast_yes/no` directamente ni utiliza `PreExecute` para
anticipar un inicio. Un intento rechazado por el motor no genera anuncios ni
inicia el cooldown propio. El core evalúa todos los consumidores y conserva el
motivo del primer veto real; Manager no envía feedback antes de esa decisión.
El contrato publica el motivo, no el autor del veto: si otro consumidor propone
el mismo motivo, Manager sólo sabe que coincide con su propia regla.

El primer Yes del iniciador se omite del progreso porque el motor lo emite
inicialmente y el anuncio ya presenta al iniciador. La omisión se consume aunque
el progreso esté desactivado; no altera los conteos del core. El No inicial del
objetivo de un kick se presenta como cualquier otro voto observado. El `team`
del forward identifica el alcance de la votación; la etiqueta del mensaje se
obtiene del equipo actual del votante, validando antes el AccountID recibido en el
forward contra el cliente conectado. Los mensajes siguen llegando a todos los
jugadores humanos, como en la experiencia anterior.

## Política

- No iniciar votaciones como espectador.
- Respetar ConVars del motor para dificultad, reinicio, kick y campaña; Manager
  controla lobby, capítulo y AllTalk mediante sus propias ConVars.
- Aplicar la [matriz por modo base](VOTING_BY_GAME_MODE.md), también a mutaciones,
  consultando `L4D_GetGameModeType()` al evaluar cada solicitud. Una base
  desconocida se entrega a las comprobaciones del motor.
- Rechazar cambios a la dificultad que ya está activa.
- Validar el objetivo del kick, equipo e inmunidades configuradas.
- Consultar los permisos administrativos actuales en cada evaluación. No hay
  una caché que sobreviva a cambios de permisos.
- Esperar al menos 5,5 segundos desde el último inicio confirmado que Manager
  observó estando habilitado, o más si `sv_vote_creation_timer` lo exige.
  El primer voto del mapa no recibe un cooldown artificial. El plazo anunciado
  se redondea hacia arriba.
- Si BuiltinVotes está disponible y su soporte está activado, respetar una
  votación activa y el plazo de `CheckBuiltinVoteDelay()`.

Las comprobaciones propias complementan las del motor; aprobar en Manager no
asegura que el motor admita la solicitud. La matriz documenta las cuatro bases
acordadas, sin inspección adicional de propiedades de cada mutación.
Las ConVars del motor de L4D2 se consideran presentes: Manager obtiene sus
handles al iniciar y consulta sus valores sin comprobar de nuevo su existencia.

## Configuración

Configuración generada: `cfg/sourcemod/callvote/callvote_manager.cfg`.

| ConVar | Por defecto | Uso |
|---|---|---|
| `sm_cvm_enable` | `1` | Política y mensajes. Cambiarla limpia el contexto de UX; habilitar a mitad de un voto no reconstruye su inicio. |
| `sm_cvm_announcer` | `1` | Anunciar inicios confirmados. |
| `sm_cvm_progress` | `1` | Mostrar respuestas. |
| `sm_cvm_progress_anonymous` | `0` | Mostrar equipo y respuesta sin nombre. |
| `sm_cvm_builtin_vote` | `1` | Respetar el bloqueo y cooldown de BuiltinVotes. |
| `sm_cvm_lobby`, `sm_cvm_chapter`, `sm_cvm_all_talk` | `1` | Permitir esos tipos cuando corresponden al modo base. |
| `sm_cvm_admin_immunity` | vacío | Cualquier flag administrativo otorga inmunidad; con flags explícitos basta coincidir con uno. Root siempre coincide. Un iniciador con permiso de kick puede votar contra ese objetivo. |
| `sm_cvm_stv_immunity`, `sm_cvm_self_immunity`, `sm_cvm_bot_immunity` | `1` | Inmunidad SourceTV, kick propio y bots. |
| `sm_cvm_debug_mask` | `0` | Core=`1`, Localization=`128`, ambos=`129`. |

`sm_cv_log_mode` es la configuración de logging compartida. El log debug de
Manager reside en `addons/sourcemod/logs/callvote/callvote_manager.log`, según
la raíz SourceMod activa. Las frases SQL y sus comandos pertenecen a
[`callvote_sql`](README_SQL.md).

## Dependencias y seguridad de contexto

Manager necesita el core y Left4DHooks. Confogl no es una dependencia de Manager.
BuiltinVotes es opcional: el inventario se hace en `OnAllPluginsLoaded`, las
altas/bajas sólo actualizan `hasBuiltinVotes`. El registro de la biblioteca
garantiza la disponibilidad de sus natives; Manager consulta ese único flag
junto con `sm_cvm_builtin_vote`, sin sondeos adicionales por native.
La carga tardía no reconstruye una votación previa.

Los mensajes diferidos validan el AccountID del snapshot y los rechazos conservan
seriales de cliente, evitando atribuir mensajes a otra persona que reutilice el
slot. Desconexión, cambio de mapa, final de sesión y cambios de enable limpian el
contexto aplicable. Esto es contexto transitorio de UX; no es historial de votos.

Cada destinatario recibe traducción de Valve cuando existe, o una frase del
plugin en español/inglés. Si falta el nombre traducido de campaña, capítulo o
dificultad, se conserva el código recibido. Un destinatario sin traducción no
queda sin anuncio aunque otro sí tenga una traducción.

## Validación y despliegue

La suite de seis plugins compila sin warnings con SourceMod Linux 1.12.0.7255.
Una prueba aislada de los callbacks de Manager verificó 36 comprobaciones:
disponibilidad de BuiltinVotes, cooldown, rechazo canónico, activación,
reutilización de slots, limpieza y la matriz de 28 combinaciones modo/tipo.
La prueba empleó adaptadores de clientes, motor y core; no ejecutó votaciones
reales ni instaló el nuevo Manager en DEV. El helper se retiró y se verificó la
lista de plugins original.

Para la comprobación de juego pendiente, instalar el core y Manager coordinados
con las frases correspondientes, iniciar un voto permitido y uno rechazado,
responder F1/F2 y verificar que fuera de una votación no aparece progreso.
Comprobar también `sm_cvm_enable 0` y anuncios/progreso por separado. SQL continúa
como satélite opcional independiente.
