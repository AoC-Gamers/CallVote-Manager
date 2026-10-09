# Votaciones de L4D2 por modo de juego

Referencia verificada el 9 de octubre de 2026.

## Alcance y evidencia

Investigación de lectura; sin modificaciones de plugins, recargas ni cambios de mapa.
Los recursos extraídos en /home/lechuga/l4d2_files contienen menús y configuración de modos; no se encontró allí el código C++ de las clases de votación.
Se contrastaron con el binario Linux server_srv.so del contenedor dev_aoc, que conserva símbolos. Versión consultada por netcon: 2.2.4.3, build 10097 (Jun 30 2026).
SHA-256 del binario: fe817d1774130f21fc05579ded84333ffc7cf3f92f84d8166be816be99863831.
La captura completa del desensamblado se conserva localmente en
`tmp/l4d2-vote-mode-engine-20261009.txt`, fuera de Git. Las funciones y
condiciones relevantes se documentan aquí para que esta referencia no dependa
de conservar ese archivo temporal. Las direcciones corresponden únicamente
al binario identificado arriba; deben localizarse de nuevo para otro build.
Es análisis estático de condiciones; no equivale a una prueba de votación en todos los modos.

## Clasificación por modo base

Para la política de esta suite basta con identificar el modo base mediante
`L4D_GetGameModeType()` de
[`left4dhooks.inc`](../addons/sourcemod/scripting/include/left4dhooks.inc).
Las mutaciones usan una de estas bases para definir modos personalizados y
reciben las reglas correspondientes a la base que devuelve Left4DHooks.
No necesitan una tabla por nombre de mutación ni comparar el texto de
`mp_gamemode` con los nombres de los modos estándar.

| Constante de Left4DHooks | Valor | Base |
|---|---:|---|
| `GAMEMODE_COOP` | 1 | Coop |
| `GAMEMODE_VERSUS` | 2 | Versus |
| `GAMEMODE_SURVIVAL` | 4 | Survival |
| `GAMEMODE_SCAVENGE` | 8 | Scavenge |
| `GAMEMODE_UNKNOWN` | 0 | Desconocido o error; no identifica una base |

Realism no constituye una quinta categoría en este contrato. La clasificación
de cualquier modo concreto se obtiene de la biblioteca. Si se conserva una
clasificación en caché, `L4D_OnGameModeChange(int gamemode)` es el forward
documentado para recibir cambios; el manager actual consulta la native al
evaluar cada voto.

## Matriz de reglas por modo base

Sí significa que la política no veta ese tipo por su base; aún se aplican
ConVars, argumento, equipo, cooldown y condiciones generales del motor.

| Tipo | Coop | Versus | Survival | Scavenge |
|---|---|---|---|---|
| ChangeDifficulty | Sí | No | No | No |
| RestartGame | Sí | Sí | Sí | No |
| Kick | Sí | Sí | Sí | Sí |
| ChangeMission | Sí | Sí | No | No |
| ReturnToLobby | Sí | Sí | Sí | Sí |
| ChangeChapter | No | No | Sí | Sí |
| ChangeAllTalk | No | Sí | No | Sí |

## Condiciones encontradas en el binario

Estas comprobaciones describen la evidencia del motor y se conservan como
contexto técnico. No sustituyen la clasificación por modo base de Left4DHooks
para aplicar la política de la suite.

- CChangeDifficultyIssue::CanCallVote (0x9f5590) exige HasConfigurableDifficultySetting (0x4f6ad0). Esta lee hasdifficulty del modo con fallback a la propiedad de su modo base.
- CRestartGameIssue::CanCallVote (0x9f56f0) rechaza IsScavengeMode.
- CChangeMissionIssue::CanCallVote (0x9f5770) rechaza IsSurvivalMode e IsScavengeMode.
- CChangeChapterIssue::CanCallVote (0x9f58d0) exige IsSurvivalMode o IsScavengeMode y valida el mapa mediante la infraestructura de matchmaking.
- CChangeAllTalkIssue::CanCallVote (0x9f59e0) exige HasPlayerControlledZombies (0x4f65f0), que lee playercontrolledzombies.
- CKickIssue::CanCallVote (0x9f5a20) no contiene un veto por modo; tiene comprobaciones de ConVar, objetivo, equipos y particularidades de listen/splitscreen.
- CReturnToLobbyIssue::CanCallVote (0x9f5760) delega en las comprobaciones comunes.

## Archivos locales relacionados

- update/resource/ui/l4d360ui/ingamevoteflyout.res: dificultad/campaña/reinicio/kick/lobby; AllTalk deshabilitado en el recurso.
- update/resource/ui/l4d360ui/ingamevoteflyoutversus.res: campaña/reinicio/kick/lobby/AllTalk; sin dificultad ni capítulo.
- update/resource/ui/l4d360ui/ingamevoteflyoutsurvival.res: capítulo/reinicio/kick/lobby; AllTalk deshabilitado.
- update/resource/ui/l4d360ui/ingamevoteflyoutversussurvival.res: capítulo/reinicio/kick/lobby/AllTalk.
- update/scripts/gamemodes.txt: coop/realism tienen hasdifficulty=1; versus/scavenge tienen playercontrolledzombies=1. Mutaciones pueden declarar propiedades distintas.

## Contraste con el proyecto

La matriz de Coop, Versus, Survival y Scavenge coincide con
`IsVoteAllowedByGameMode` en
[`callvote_manager/policy.sp`](../addons/sourcemod/scripting/callvote_manager/policy.sp).
Ese método ya obtiene la base con `L4D_GetGameModeType()` y aplica el `switch`
sobre las constantes `GAMEMODE_*`. Éste es el criterio acordado también para
las mutaciones; no se requiere añadir inspección de sus propiedades para
decidir la política por modo.
Las restricciones de política pertenecen al manager. Los satélites deben
extraer y conservar la identidad y las estadísticas que necesiten; esta
investigación no propone añadir historial de votantes al core. El core debe distinguir intento de comando, inicio confirmado y resultado; un rechazo por modo puede no producir VoteStart ni CallVoteFailed, como se observó en el intento de dificultad en Versus.

## Internet

- https://wiki.alliedmods.net/Left_4_Voting_2 — describe el protocolo, VoteStart/Registered/Pass/Fail y vote_controller; no publica una matriz completa por modo. Algunos nombres son descripciones del voto, no necesariamente la sintaxis del comando. No se tomó su ejemplo de campañas numéricas como contrato actual.
- https://forums.alliedmods.net/showthread.php?nojs=1&p=2575295 — el autor de Vote difficulty documenta que su plugin proporciona votos de dificultad personalizados y requiere Difficulty Override fuera de Coop; apoyo contextual, no prueba completa de modos.
- https://developer.valvesoftware.com/wiki/List_of_Left_4_Dead_2_console_commands_and_variables — no fue posible leer el contenido con el navegador de investigación; no se usó como evidencia.

## Uso en futuras revisiones

1. Separar un intento de `callvote`, el inicio confirmado y el resultado.
   Un intento rechazado antes del inicio no cuenta como votación perdida.
2. Obtener el modo base con `L4D_GetGameModeType()` y aplicar su fila de reglas
   también a las mutaciones. Las propiedades `hasdifficulty` y
   `playercontrolledzombies` quedan como evidencia de comprobaciones internas
   del motor, no como un clasificador adicional del manager.
3. Mantener separados los controles del motor y la política configurable del
   manager. La matriz no garantiza que el argumento, objetivo o momento de
   la partida sean válidos.
4. Contrastar eventos y mensajes con
   [`l4d2_game_events.json`](l4d2_game_events.json), el
   [contrato del core](README_CORE.md) y el
   [procedimiento de diagnóstico](README_TESTING.md).
5. Verificar las combinaciones relevantes con votaciones reales antes de
   afirmar que están probadas en runtime. La investigación estática no
   ejecutó votaciones ni cambió el modo del servidor.

## Reproducción del análisis estático

En una copia del binario Linux con símbolos, localizar primero las funciones:

```bash
nm -C server_srv.so | rg 'CanCallVote|HasConfigurableDifficultySetting|HasPlayerControlledZombies|IsSurvivalMode|IsScavengeMode'
```

Para el SHA-256 documentado, estos rangos contienen las comprobaciones:

```bash
sha256sum server_srv.so
objdump -d -C --start-address=0x9f5490 --stop-address=0x9f5c50 server_srv.so
objdump -d -C --start-address=0x4f6420 --stop-address=0x4f6660 server_srv.so
objdump -d -C --start-address=0x4f6ad0 --stop-address=0x4f6c00 server_srv.so
objdump -s -j .rodata --start-address=0xc19cc0 --stop-address=0xc19d20 server_srv.so
```

El último rango permite contrastar los nombres de las propiedades
`playercontrolledzombies` y `hasdifficulty`. Estos comandos sólo leen el
archivo; no requieren recargar plugins ni modificar la partida.
