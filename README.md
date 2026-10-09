# CallVote Manager Suite

Suite de plugins SourceMod para controlar votaciones en Left 4 Dead 2.

## Vision

La suite se organiza alrededor de un core:

- `callvote_core`: intercepta, crea sesiones y expone el lifecycle
- `callvote_sql`: persistencia SQL opcional de votaciones confirmadas
- `callvote_manager`: satelite de politica y UX por defecto
- `callvote_kicklimit`: aplica politicas de abuso sobre votekick
- `callvote_bans`: aplica restricciones de voto y expone API administrativa simple

El objetivo actual del proyecto es consolidar el core como una API estable para extensiones externas.

## Direccion actual

- `AccountID` es la identidad canonica interna
- el core entrega pares `client` + `accountId`; las conversiones SteamID2/SteamID64 pertenecen a los satélites
- `callvote_sql` persiste `AccountID` y `SteamID64` en MySQL para analitica externa
- el satelite SQL crea SQLite automaticamente cuando el entry de `databases.cfg` usa ese motor y mantiene el esquema local minimo
- el core expone ciclo de vida de votacion y contexto enriquecido
- las restricciones de voto se mantienen como componente acotado, no como suite general de sanciones

## Componentes

```mermaid
flowchart LR
    Player[Jugador]
    Core[callvote_core]
    Manager[callvote_manager]
    KickLimit[callvote_kicklimit]
    Bans[callvote_bans]
    SQL[callvote_sql]
    External[Suites externas]

    Player --> Core
    Core --> Manager
    Core --> KickLimit
    Core --> Bans
    Core --> SQL
    Core --> External
```


### [CallVote Core](docs/README_CORE.md)

Nucleo reutilizable que correlaciona las señales del motor y expone sesiones,
identidades capturadas y el ciclo de vida. Las politicas, sanciones, conversiones
Steam y persistencia corresponden a sus satelites.

### [CallVote SQL](docs/README_SQL.md)

Satelite opcional de persistencia y administracion SQL. Consume el inicio
confirmado del core y conserva el esquema existente de `callvote_log`.
Configuracion y comandos administrativos independientes del core.

### [CallVote Manager](docs/README_MANAGER.md)

Plugin satélite opcional de política y UX. Evalúa reglas en `CallVote_PreStart`, presenta el rechazo confirmado en `CallVote_Blocked` y muestra inicios y respuestas mediante `CallVote_Start` y `CallVote_BallotCast`. No escucha votos del motor directamente ni conserva historial.

### [CallVote Kick Limit](docs/README_KICKLIMIT.md)

Extension liviana sobre el core. Usa el contrato publico de `callvote_core` para limitar la frecuencia de votekicks por jugador.

Superficie publica principal:

- comandos `sm_cvkl_show` y `sm_cvkl_count`
- convars `sm_cvkl_*`

### [CallVote Bans](docs/README_BANS.md)

Plugin acotado de restricciones de voto. El runtime base queda reducido a API, persistencia y validacion; la UX administrativa puede montarse externamente, por ejemplo con `callvote_bans_adminmenu`.

Superficie publica principal:

- comandos `sm_cvb_ban`, `sm_cvb_unban` y `sm_cvb_status`
- paneles `sm_cvb_ban_panel`, `sm_cvb_unban_panel` y `sm_cvb_status_panel`
- natives `CVB_HasActiveRestriction`, `CVB_GetPlayerRestrictionMask`, `CVB_RestrictPlayer`, `CVB_RemoveRestriction`, `CVB_GetRestrictionInfo`

## Documentos tecnicos

- [Contrato y ciclo de vida del Core](docs/README_CORE.md)
- [Diagnostico de votaciones](docs/README_TESTING.md)
- [Investigacion HL2SDK y Votaciones](docs/HL2SDK_VOTING_RESEARCH.md)
- [Votaciones por modo de juego](docs/VOTING_BY_GAME_MODE.md)
- [Sistema de Build](docs/BUILD_SYSTEM.md)

## Artefactos

La suite se distribuye mediante artefactos zip publicados por CI y releases de GitHub.

Nombre esperado del paquete:

- `callvote-manager-<version>.zip`

Layout instalable del artefacto:

```text
addons/sourcemod/plugins/callvote/
    callvote_core.smx
    callvote_sql.smx
    callvote_manager.smx
    callvote_kicklimit.smx
    callvote_bans.smx
    callvote_bans_adminmenu.smx

addons/sourcemod/scripting/include/
    callvote_core.inc
    callvote_stock.inc
    callvote_bans.inc

addons/sourcemod/scripting/
    callvote_core.sp
    callvote_sql.sp
    callvote_manager.sp
    callvote_kicklimit.sp
    callvote_bans.sp
    callvote_bans_adminmenu.sp
    callvote_core/
    callvote_sql/
    callvote_manager/
    callvote_bans/

addons/sourcemod/configs/
    sql-init-callvote/

addons/sourcemod/translations/
    callvote*.phrases.txt
```

Los binarios publicos de la suite viven en `addons/sourcemod/plugins/callvote/`.

El artefacto no incluye bibliotecas adicionales ajenas a la suite ni requiere limpieza posterior de includes antes de instalarse. El zip ya viene listo para copiar sobre el servidor.

Para integradores como Docker-L4D2-AoC esto significa que el instalador debe consumir el artefacto ya empaquetado y preservar el subdirectorio `callvote` para mantener la suite agrupada.

## Build local

- `make deps-smx`
- `make build-smx`
- `make package-smx`
- `make release`

## Estado

La documentacion principal busca describir arquitectura y contratos. Los detalles operativos finos, comandos y pruebas puntuales quedan fuera del README base.
