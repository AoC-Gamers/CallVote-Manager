# Satelite SQL de votaciones

`callvote_sql` es opcional y requiere `callvote_core`. Es dueño de la conexion,
esquema SQLite, consultas, comandos administrativos y persistencia en
`callvote_log`. No expone biblioteca ni natives propios porque no ofrece una
API de runtime a otros plugins.

## Registro

Consume exclusivamente `CallVote_Start` y consulta la instantanea publica del
core. Registra una fila por votacion confirmada, con fecha de inicio, tipo,
AccountID del iniciador y del objetivo. MySQL conserva tambien los SteamID64
derivados localmente de los AccountID capturados; SQLite mantiene el esquema
local minimo existente.
La identidad del objetivo no se vuelve a resolver usando su slot conectado.

Solicitudes bloqueadas, rechazadas por el motor o expiradas sin inicio no
producen filas. Este satelite conserva el registro de inicios existente: no
almacena resultados, mapas ni historial de votantes. La futura analitica de
BanSystem puede consumir `Start`, `BallotCast` y `End` desde su propio satelite.

Las consultas y el bootstrap SQLite usan el worker SQL. Los callbacks de una
configuracion anterior se descartan mediante una generacion de conexion;
las respuestas administrativas usan `userid` para evitar reutilizacion de
slots. Los handles recibidos en callbacks se comparan con
`Database.IsSameConnection`, no por igualdad del identificador del handle.

Si la base no esta lista, se emite un error de registro y se omite esa fila.
No existe cola durable ni recuperacion de votaciones anteriores a la carga del
satelite. Un fallo SQL no decide si una votacion puede comenzar.

## Identidad persistida

El registro usa los AccountID capturados por el
[contrato de identidad del core](README_CORE.md#contrato-de-identidad).
Las representaciones Steam se derivan en el satelite:

| Columna de `callvote_log` | SQLite | MySQL |
|---|---|---|
| `caller_account_id` | Identidad del iniciador. | Identidad del iniciador. |
| `target_account_id` | Identidad del objetivo, 0 si no corresponde o no esta disponible. | Identidad del objetivo, 0 si no corresponde o no esta disponible. |
| `caller_steamid64` | No se almacena. | Representacion derivada para analitica externa. |
| `target_steamid64` | No se almacena. | Representacion derivada para analitica externa. |

`SteamID2` se utiliza para presentacion; no es una clave persistente del registro.
`client` y `userid` sirven al runtime y a las respuestas diferidas, mientras que
las filas se asocian a jugadores mediante AccountID. La persistencia de cuotas
y restricciones pertenece a [Kick Limit](README_KICKLIMIT.md) y
[Bans](README_BANS.md), respectivamente.

## Configuracion

El plugin genera `cfg/sourcemod/callvote/callvote_sql.cfg`.

| ConVar | Predeterminado | Uso |
|---|---|---|
| `sm_cvs_log_flags` | `0` | Tipos que se persisten: dificultad=1, reinicio=2, kick=4, campaña=8, lobby=16, capitulo=32, AllTalk=64; todos=127. |
| `sm_cvs_config` | `callvote` | Entrada de `databases.cfg`. |
| `sm_cvs_log_mode` | `0` | Log del satelite: apagado=0, normal=1, debug=2. |
| `sm_cvs_debug_mask` | `0` | Detalle de almacenamiento=1, SQL=2, ambos=3. |

El archivo propio es `addons/sourcemod/logs/callvote/sql.log`, resuelto desde
`Path_SM` para respetar instalaciones como `sourcemod1`. El modo normal registra
conexion y escrituras; el detalle de consultas requiere debug y su mascara.

Para persistir solo kicks, configurar `sm_cvs_log_flags 4`. Para todos los tipos,
usar `127`. La conexion se reconcilia despues de ejecutar la configuracion y
cuando cambian su entrada o los flags. Deshabilitar los flags cierra la conexion.

SQLite crea tabla e indices de forma asincrona. MySQL requiere el SQL inicial de
`addons/sourcemod/configs/sql-init-callvote/mysql/`; el satelite comprueba la
tabla y no cambia un esquema MySQL existente.

## Administracion

| Comando | Permiso | Uso |
|---|---|---|
| `sm_cvs_stats` | Generic | Total de registros y distribucion por tipo. |
| `sm_cvs_cleanup [dias]` | Root | Elimina registros anteriores al plazo; predeterminado 30, rango 1–365. |
| `sm_cvs_truncate confirm` | Root | Elimina todos los registros de la tabla. |

Los comandos destructivos conservan su alcance explicito sobre `callvote_log`.
El vaciado exige el argumento `confirm`.

## Cambio de ownership

Instalar `callvote_core` 3.0.0 y, si se necesita persistencia, `callvote_sql` 1.0.1
con sus traducciones. Trasladar los valores de `sm_cvc_sql_log_flags` y
`sm_cvc_sql_config` a `sm_cvs_log_flags` y `sm_cvs_config` en la configuracion del
satelite. Retirar las lineas SQL antiguas del archivo de configuracion del core.
Los comandos anteriores `sm_cvc_sql_*` se sustituyen por `sm_cvs_*`.

La tabla, sus registros y la entrada `callvote` de `databases.cfg` se conservan.
Esta separacion no requiere migracion de datos. Evitar ejecutar simultaneamente
un core antiguo con SQL habilitado y el satelite nuevo: registrarian dos filas
por votacion.
