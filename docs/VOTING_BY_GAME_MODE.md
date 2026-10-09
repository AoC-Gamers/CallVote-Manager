# Votaciones de L4D2 por modo de juego

Referencia de la politica implementada por
[`callvote_manager/policy.sp`](../addons/sourcemod/scripting/callvote_manager/policy.sp).

## Clasificacion por modo base

Manager consulta `L4D_GetGameModeType()` de
[`Left4DHooks`](../addons/sourcemod/scripting/include/left4dhooks.inc) en cada
solicitud. Las mutaciones reciben las reglas de su modo base; no se clasifican
por nombre ni por el texto de `mp_gamemode`.

| Constante | Valor | Base |
|---|---:|---|
| `GAMEMODE_COOP` | 1 | Coop |
| `GAMEMODE_VERSUS` | 2 | Versus |
| `GAMEMODE_SURVIVAL` | 4 | Survival |
| `GAMEMODE_SCAVENGE` | 8 | Scavenge |
| `GAMEMODE_UNKNOWN` | 0 | Desconocida; se deja decidir al motor. |

Realism y las mutaciones se evalúan mediante la base devuelta por la biblioteca,
sin categorias adicionales.

## Matriz de reglas

**Si** indica que Manager permite el tipo por su modo base. La aceptacion final
tambien depende de ConVars, argumento, objetivo, equipo, cooldown y reglas del motor.

| Tipo | Coop | Versus | Survival | Scavenge |
|---|---|---|---|---|
| ChangeDifficulty | Si | No | No | No |
| RestartGame | Si | Si | Si | No |
| Kick | Si | Si | Si | Si |
| ChangeMission | Si | Si | No | No |
| ReturnToLobby | Si | Si | Si | Si |
| ChangeChapter | No | No | Si | Si |
| ChangeAllTalk | No | Si | No | Si |

## Integracion y comprobacion

- Manager aplica estas restricciones; el Core correlaciona las señales del motor.
- Separar intento, inicio confirmado y resultado: una solicitud rechazada antes
  del inicio no es una votacion perdida. Un rechazo puede no emitir `VoteStart`
  ni `CallVoteFailed`.
- La matriz describe la politica de la suite; no certifica pruebas de juego en
  cada modo. Verificar las combinaciones relevantes con votaciones reales.

## Referencias

- [Contrato del Core](README_CORE.md) y [procedimiento de diagnostico](README_TESTING.md).
- [Eventos de L4D2](l4d2_game_events.json).
- [Left 4 Voting 2](https://wiki.alliedmods.net/Left_4_Voting_2): protocolo de votacion.
