# Diagnostico de votaciones L4D2

`callvote_testing.sp` es un observador para pruebas privadas. Requiere
`callvote_core.smx`, no bloquea comandos ni modifica votos y queda fuera del
bundle publico. No agrega historial al core ni depende de una base SQL.

## Cobertura

- Eventos: `vote_started`, `vote_ended`, `vote_changed`, `vote_passed`,
  `vote_failed`, `vote_cast_yes` y `vote_cast_no`.
- Usermessages: `VoteStart`, `VotePass`, `VoteFail`, `VoteRegistered` y
  `CallVoteFailed`.
- Comandos: `callvote` y `Vote`; son intentos observados, no prueba de aceptacion.
  F1/F2 puede enviar `Vote Yes/No` sin votacion: si el controlador esta inactivo
  se registra una sola linea con `attempt_only=1 engine_vote_active=0`, sin
  capturas diferidas. -1 significa que no se pudo consultar el controlador.
  Solo `CallVote_BallotCast` representa un voto observado por el core.
- Forwards: `CallVote_PreStart`, `CallVote_PreExecute`, `CallVote_Start`,
  `CallVote_Blocked`, `CallVote_BallotCast` y `CallVote_End`.
- Estado de `vote_controller`: indice activo, votos si/no, votos potenciales y
  equipo habilitado, con origen `send` o `data` de cada propiedad.
- ConVars del motor y controles de los plugins de votacion, solo lectura.
- Limites: inicio/fin de mapa y descarga del tester.

Los hooks de eventos son post-hooks: otros plugins pueden haber modificado los
campos. Los comandos interceptados previamente por otros plugins pueden no
llegar al listener. Un evento declarado no garantiza que el motor lo emita.

Cada linea incluye secuencia local, tick, tiempo del motor, Unix timestamp,
mapa, fuente y la sesion que el core tiene activa en ese instante. Los forwards
incluyen ademas su `forward_session` explicita: no asumir que siempre coincide
con la sesion activa, especialmente con callbacks diferidos.

Los campos enteros y cadenas ausentes se muestran como `<absent>`; los valores
vacios y cero se conservan. `vote_ended` no se interpreta automaticamente como
aprobado o rechazado. `core_result` refleja la interpretacion del core, que debe
contrastarse con las señales del motor.

`CallVote_BallotCast` registra la decision y `voter_accountid` capturado por el
core, además de datos del cliente cuando su identidad conectada sigue
coincidiendo. Un client 0 o un slot reutilizado no reemplaza el AccountID observado. Para verificar el contrato, comprobar que cada sesion tenga un
solo `CallVote_Start` antes del primer `CallVote_BallotCast` y un solo
`CallVote_End` con el resultado y conteos observados.

`VoteRegistered` registra la decision y la identidad de cada destinatario:
client, userid, AccountID y SteamID64 cuando estan disponibles. Los indices
invalidos o desconectados se registran sin resolverlos como jugadores actuales.
El tester registra tambien los destinatarios de los demas usermessages.

`VoteFail` lee solo el equipo. `CallVoteFailed` lee el motivo y el tiempo corto
solo si quedan dos bytes. Los bytes adicionales se muestran en hexadecimal
(hasta 64 bytes, indicando los omitidos). Las cadenas se acotan a 255 bytes y
se informa si llegan al limite o si falta el terminador. El chat se difiere para
no generar mensajes de red desde un hook de usermessage; las identidades se
capturan antes de diferirlo.

## Capturas del controlador y configuracion

`sm_cvt_controller 1` toma una lectura inmediata y dos lecturas diferidas
(temporizadores solicitados a 0 y 100 ms) para cada comando, evento,
usermessage y forward de inicio/fin observado. El runtime decide el momento
real de ejecucion: usar el tick y tiempo de cada linea para medirlo. Cada
lectura conserva `origin_seq`, `origin_tick` y `origin_session` de la señal
original; puede ocurrir despues del cierre o del inicio de otra votacion.
Las entidades se buscan de nuevo y no se retienen indices de jugadores.
Los temporizadores se cancelan al cambiar de mapa o descargar el tester.

Las propiedades ausentes y la ausencia del controlador se indican
explicitamente. El equipo crudo 255 se conserva y se muestra ademas como -1.
`vote_roster` cuenta humanos por equipo, bots y SourceTV por separado. Ni esos
conteos ni los destinatarios de mensajes prueban quienes tienen derecho a votar
o cual es el umbral necesario para aprobar una votacion.

`sm_cvt_convars 1` captura una lista cerrada de variables de votacion al
observar `callvote`, `VoteStart` o `CallVoteFailed`. Las ConVars del motor se
consideran presentes y se leen directamente; las variables de plugins
opcionales que no existan se muestran como `<absent>`. No se cambian valores ni se invocan
comandos de votacion. `sm_cvt_snapshot` (administrador ROOT o consola del
servidor) permite leer controlador y configuracion manualmente.

Las capturas `vote_controller`, `vote_roster` y `vote_convar` solo se emiten
al archivo y la consola, incluso con `sm_cvt_chat 1`, para reducir ruido.

## Compilacion

Desde la raiz del repositorio, con el toolchain Linux disponible:

```sh
make deps-smx
make build-smx
mkdir -p .build/focal
deps/sourcemod-linux/addons/sourcemod/scripting/spcomp \
  addons/sourcemod/scripting/callvote_testing.sp \
  -iaddons/sourcemod/scripting/include \
  -iaddons/sourcemod/scripting \
  -ideps/sourcemod-linux/addons/sourcemod/scripting/include \
  -o.build/focal/callvote_testing.smx
```

El build del bundle omite el tester deliberadamente. Compilar no instala ni
recarga plugins en un servidor.

## Captura en un servidor de pruebas

Con el tester instalado, usar la consola del servidor:

```text
sm_cvt_log_mode 2
sm_cvt_debug_mask 1
sm_cvt_enable 1
sm_cvt_listenervote 1
sm_cvt_listenercallvote 1
sm_cvt_forwardend 1
sm_cvt_forwardballot 1
sm_cvt_chat 0
sm_cvt_controller 1
sm_cvt_convars 1
sm_cvt_status
sm_cvt_snapshot
```

Los selectores `sm_cvt_vote*`, `sm_cvt_callvotefailed` y `sm_cvt_forward*`
permiten apagar señales concretas. Los valores guardados de una instalacion
anterior pueden diferir de los defaults. `sm_cvt_status` muestra el destino del
archivo: `addons/sourcemod/logs/callvote/callvote_testing.log`.

La descarga del tester registra `session=-1` para no invocar un native cuyo
core pueda estar pausado durante el cambio de configuracion.

Las trazas aparecen en consola. El tester usa `sm_cvt_log_mode`, independiente
de `sm_cv_log_mode`: 0 apaga el archivo, 1 registra las señales seleccionadas
y 2 aplica la mascara Core (bit 1). El valor inicial es 2; un cambio de modo de
juego que ajuste la variable de la suite no apaga esta captura. `sm_cvt_chat 1` permite una vista adicional en chat, que puede truncar
lineas largas: usar el archivo para el analisis. No habilitar el chat en un
servidor publico. Guardar los valores anteriores y restaurarlos al finalizar. El tester no
necesita modificar `sm_cv_log_mode`.

## Matriz para investigar el runtime

1. Kick aprobado, rechazado y solicitud bloqueada antes del inicio.
2. Voto inicial del iniciador y voto del objetivo; comprobar eventos y mensajes.
3. F1/F2, repeticion de `Vote Yes/No` e intento de cambiar una decision.
4. Espectador, equipo contrario, bots y participantes no elegibles.
5. Desconexion del iniciador, objetivo o votante, y cambio de equipo.
6. Timeout, cambio de mapa y recarga: buscar cierres ausentes o diferidos.
7. Repetir en vanilla y competitivo y con votaciones de otros plugins.

Conservar la secuencia completa de cada caso, version del servidor, modo y lista
de plugins cargados. Comparar votos individuales con `vote_changed` y comparar
`CallVote_End` con `VotePass/Fail`. No fabricar abstenciones, votos automaticos ni
resultados cuando no existe evidencia suficiente.

## Comprobaciones de intervencion y SQL

Al cambiar los hooks de decision, verificar con dos consumidores controlados:
continuar, vetar con y sin motivo, dos vetos con motivos distintos, motivo de un
consumidor que permite continuar, `Stop`, veto en `PreExecute`, liberacion del
contexto de callback y rechazo de solicitudes anidadas. Repetir con el orden de
carga invertido. Un motivo informado por quien permite no debe atribuirse a
quien veta. Los observers del core deben registrar `Blocked` seguido de un solo
`End`, sin inicio del motor.

Desde el tester 2.3.2, `Start`, `Blocked` y `End` tambien muestran estado y motivo
mediante `CallVoteCore_GetSessionState`; requiere core 3.0.0 y la firma de cinco argumentos de `BallotCast`.

El satelite SQL debe probarse con una base aislada: creacion asincrona de tabla e
indices, una fila por inicio confirmado, flags apagados, identidad congelada,
descarte de callbacks de conexiones anteriores, estadisticas, limpieza por
fecha y vaciado con confirmacion. Una prueba de modulos con datos sinteticos no
sustituye la integracion del contrato publico ni una votacion real del motor.
