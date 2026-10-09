# Core de votaciones L4D2

`callvote_core` correlaciona solicitudes `callvote` con señales del motor y
expone el ciclo de vida de una sesion. Las politicas, estadisticas de votantes
e identidades extraidas durante cada voto corresponden a los satelites.

## Responsabilidades y modelo de sesion

El core intercepta solicitudes, correlaciona eventos y usermessages del motor,
mantiene la sesion y expone una API comun con diagnostico operativo. Los
consumidores obtienen ese contexto sin reconstruir el ciclo desde señales sueltas.

| Datos de la sesion | Uso |
|---|---|
| `sessionId` | Referencia comun del contexto de una votacion. |
| Iniciador y objetivo | Indices de cliente e identidades AccountID capturadas. |
| Tipo y argumento bruto | Propuesta recibida mediante `callvote`. |
| Estado y motivo de bloqueo | Evolucion del ciclo y rechazo canonico. |
| Resultado y conteos observados | Cierre de la sesion y votos conocidos; -1 indica un conteo desconocido. |
| Señales del motor | Controlador, alcance e informacion de inicio o fallo usada para correlacionar el ciclo. |

El core conserva la sesion actual y la ultima finalizada como instantaneas
temporales. El historial, la analitica y las conversiones Steam corresponden a
los consumidores. Las reglas de modo, equipo e inmunidad pertenecen a
[Manager](README_MANAGER.md); las cuotas a [Kick Limit](README_KICKLIMIT.md);
las restricciones persistentes y su administracion a [Bans](README_BANS.md);
el registro SQL de inicios a [SQL](README_SQL.md). Bans consume el contrato
comun, igual que cualquier otra extension; sus sanciones no definen el modelo
del core.

## Intervencion de consumidores

`CallVote_PreStart` y `CallVote_PreExecute` son puntos de decision sincronos.
El core consulta cada callback de los plugins en ejecucion de forma individual:

- `Plugin_Continue` permite continuar; `Plugin_Changed` no modifica la propuesta.
- `Plugin_Handled` o `Plugin_Stop` veta la solicitud. Todos los consumidores se
  evaluan y ninguno puede anular un veto previo.
- `CallVoteCore_SetPendingRestriction` establece el motivo local del consumidor.
  Su valor se acepta solo si ese mismo callback veta la solicitud.
- El primer veto conserva su motivo; si no lo especifica se usa
  `VoteRestriction_Plugin`. El orden de carga no representa prioridad de reglas.
- El native solo admite motivos positivos del enum y solo puede invocarse por
  el consumidor activo dentro de esos hooks. Usarlo despues, desde otro plugin
  o con `VoteRestriction_None` produce un error de native.
- Un error de ejecucion de un callback bloquea la solicitud con motivo `Plugin`
  y deja un diagnostico del consumidor y del hook.

`PreExecute` se entrega solo cuando `PreStart` permite continuar. Ambos ocurren
antes de que el comando llegue al motor. Un bloqueo entrega `Blocked` y `End`
una sola vez, sin `Start`, votos ni registro SQL.

Ejemplo de politica alojada en un satelite:

```sourcepawn
public Action CallVote_PreStart(int sessionId, int client, int callerAccountId,
    TypeVotes voteType, int target, int targetAccountId, const char[] argument)
{
    if (voteType == Kick && MiPoliticaImpideKick(client, target))
    {
        CallVoteCore_SetPendingRestriction(VoteRestriction_Plugin);
        return Plugin_Handled;
    }
    return Plugin_Continue;
}
```

`MiPoliticaImpideKick` representa la regla del consumidor. El core mantiene el
estado y comunica la decision; las reglas por equipo, modo, inmunidad o limite
pertenecen a los satelites.

Un `callvote` sincrono iniciado desde cualquier callback del core se bloquea
antes de sustituir la sesion. Si un consumidor necesita iniciar otra solicitud,
debe programarla despues del callback y revalidar el cliente y el estado del
motor. No existe API para forzar el resultado ni cancelar una votacion activa.

## Orden de entrega

1. `CallVote_PreStart` y `CallVote_PreExecute` permiten evaluar la solicitud.
2. `VoteStart` o `vote_started` confirma que el motor inicio la votacion.
3. `CallVote_Start` se entrega una sola vez, antes de `CallVote_BallotCast`.
4. Cada `vote_cast_yes/no` compatible emite `CallVote_BallotCast`.
5. `VotePass`, `VoteFail`, `vote_passed` o `vote_failed` cierra la sesion y
   entrega `CallVote_End` una sola vez.

El primer voto puede llegar antes del temporizador de inicio. En ese caso,
el evento del voto entrega primero el forward de inicio y despues el voto.
Los temporizadores llevan el ID de sesion y no pueden iniciar o cerrar una
sesion posterior. La entrega desde usermessages sale del hook de red antes de
invocar los consumidores; no emitir otros usermessages dentro de sus hooks.

`CallVote_BallotCast(int sessionId, int client, int accountId, bool votedYes, int team)`
entrega el client y el AccountID del votante. El AccountID se captura al observar
el evento, antes de invocar consumidores de `Start`; sobrevive a una desconexión
o reutilización del slot durante esos callbacks. El client se resuelve de nuevo
por `userid` y puede ser 0 si ya no está conectado. AccountID 0 significa identidad
no disponible, por ejemplo un bot. El core no agrega un historial de votantes ni
utiliza `VoteRegistered` como otra fuente del mismo voto.
No se inventan votos desde intentos del comando `Vote`.

El equipo representa el alcance de la votacion, no el equipo actual del
jugador; 255 se normaliza a -1. Se incluyen los votos iniciales emitidos por
el motor, aunque no tengan un comando `Vote` asociado.

## Resultados y conteos

Los conteos se leen del `vote_controller` vinculado por referencia de entidad,
indice activo y equipo, o de campos presentes de `vote_changed`. El evento
`vote_cast_*` puede llegar antes del incremento del controlador: no se usa
para sumar un segundo conteo ni reconstruirlo desde los destinatarios.
Al cerrar se toma la lectura disponible antes de diferir el forward.
Un conteo desconocido se representa con -1; no se presenta como cero.

L4D2 declara `vote_ended` sin campos. Ese evento sin `success` no determina
el resultado. Si el runtime proporciona explicitamente `success` 0 o 1,
puede completar la sesion; en caso contrario se espera una señal de resultado.
Señales duplicadas no generan otra finalizacion.

`CallVoteFailed` cancela una solicitud que aun esta en ejecucion. Se lee
su motivo solo si existe un byte y su tiempo solo si existen dos bytes mas;
el tiempo ausente es -1. No se entrega `CallVote_Start` para esa cancelacion.

Si una solicitud no recibe `VoteStart`, `vote_started` ni `CallVoteFailed`
dentro de la ventana de confirmacion de 3 segundos de ejecucion, se cierra
como `CallVoteEnd_Aborted`, sin `CallVote_Start` ni votos individuales y con
conteos -1. Eso indica falta de confirmacion, no un motivo de rechazo
informado por el motor. Los satelites deben separar intentos de votaciones
confirmadas; un `PreStart` por si solo no cuenta como una votacion jugada.
El temporizador comprueba el ID y el estado: no cierra una votacion que ya
comenzo ni una solicitud posterior.

Una solicitud durante una votacion iniciada no reemplaza su sesion: se deja
al motor responder, sin crear otra sesion aceptada. Si una votacion queda
interrumpida al terminar el mapa se cierra como `CallVoteEnd_Aborted`. Un
resultado ya recibido conserva su valor aunque su callback siga pendiente.

## Contrato de identidad

`AccountID` es la identidad canonica del jugador para contratos y memoria de
los satelites. `sessionId` identifica la votacion, no al jugador.

| Identificador | Responsabilidad |
|---|---|
| `client` | Indice transitorio para leer o actuar sobre una conexion vigente; puede reutilizarse. |
| `userid` | Identificador de conexion utilizado para resolver clientes y callbacks; no es una clave persistente del jugador. |
| `AccountID` | Identidad capturada que el consumidor conserva para asociar datos al jugador. |
| `SteamID2` / `SteamID64` | Representaciones derivadas por los satelites para presentacion o persistencia analitica. |

El core 3.0.0 entrega pares `client` + `accountId` en los contratos que contienen
jugadores: `PreStart`, `PreExecute`, `Blocked`, `BallotCast` y el native
`GetSessionInfo`. `GetSessionIssueInfo` también entrega el AccountID del
iniciador informado por el motor, capturado con la señal de inicio. `Start` y `End` identifican la sesión; sus consumidores obtienen
los pares de iniciador/objetivo mediante `CallVoteCore_GetSessionInfo`.
Los AccountID de iniciador y objetivo se capturan al crear la solicitud, sin
mantener representaciones SteamID2/SteamID64 duplicadas en la sesión.

Un client es transitorio: antes de leer equipo, nombre o ejecutar una acción,
comprobar que esté conectado y que su AccountID siga coincidiendo con el
capturado. Guardar el AccountID para trabajo diferido. La conversión a SteamID64
puede hacerse en el satélite desde ese valor, incluso después de desconectarse.
Las conversiones a formatos Steam y la persistencia pertenecen a los satélites;
el log operativo del core utiliza índices y AccountID.

Esta revisión elimina los natives `CallVoteCore_GetClientAccountID`,
`CallVoteCore_GetClientSteamID2` y `CallVoteCore_GetSessionSteamID64Info`.
No hay aliases: recompilar los consumidores y actualizar `BallotCast` a sus cinco
argumentos y `GetSessionIssueInfo` a su salida adicional de AccountID antes de
instalar los binarios coordinados. Manager 2.2.1 y el tester
3.0.0 consumen esa firma; SQL 1.0.1 y Kick Limit 1.6.0 derivan SteamID64 localmente.
Bans 2.1.0 evalúa el AccountID capturado y presenta el veto desde `Blocked`;
Admin Menu 1.1.0 consume la API de Bans y revalida sus acciones diferidas.

## Integracion

El contrato completo esta en
`addons/sourcemod/scripting/include/callvote_core.inc`. Los getters existentes
conservan el acceso a la sesion actual y a la ultima sesion;
`CallVoteCore_GetSessionState` devuelve el estado del ciclo y el motivo canonico
del bloqueo, disponibles tambien durante `Blocked` y `End`. Antes de finalizar
un veto, el motivo de la instantanea sigue siendo `None`. Estos datos no son un historial
analitico. Los consumidores deben tolerar conteos -1 y no conservar un client
para resolver su identidad despues de una desconexion o reutilizacion de slot.

La captura local y la matriz de pruebas reales se describen en
[Diagnostico de votaciones](README_TESTING.md). Compilar y probar callbacks
controlados no sustituye verificar votaciones reales en Coop y competitivo.

La persistencia SQL y su administracion pertenecen a
[callvote_sql](README_SQL.md). El core no abre conexiones SQL, crea tablas ni
registra comandos de historial. Mantiene su diagnostico operativo y las dos
instantaneas temporales del ciclo.
