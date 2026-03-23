# Investigacion HL2SDK y Votaciones

Resumen tecnico de lo observado en `hl2sdk` y en la documentacion publica de L4D2.

## Pregunta

Que informacion del motor sirve para mejorar el core de votaciones.

## Hallazgo central

El `hl2sdk` disponible explica la infraestructura de:

- game events
- usermessages

Pero no contiene la implementacion concreta del sistema de votaciones de L4D2.

## Consecuencia

Los nombres que usa la suite para integrarse con el juego:

- `vote_started`
- `vote_ended`
- `vote_changed`
- `VoteStart`
- `VotePass`
- `VoteFail`
- `CallVoteFailed`

deben entenderse como contratos observados del runtime de L4D2, no como una API estable definida por el SDK base.

## Lo util del SDK

El SDK si deja claro esto:

- eventos y usermessages son capas separadas
- ambos son mecanismos de transporte del motor
- ninguno entrega por si solo un objeto de dominio listo para plugins

## Lo util de la documentacion de L4D2

Las referencias de AlliedModders completan lo que el SDK no trae:

- el flujo observable de una votacion
- el contenido de `VoteStart`
- el rol de `vote_changed`
- la existencia de `vote_controller`

## Decision de diseño

La suite no debe exponer eventos y usermessages del motor como API publica. Debe:

- consumirlos internamente
- correlacionarlos
- convertirlos en una `VoteSession`
- exponer un contrato propio y mas estable

## Implicaciones para el core

El valor del core no esta en enganchar un evento suelto mas. El valor esta en consolidar:

- caller
- target
- `AccountID`
- tipo
- argumento
- progreso
- cierre

en una sola sesion de voto.

## Decision sobre identidad

Dado que la informacion del motor ya viene fragmentada, usar `AccountID` como identidad canonica simplifica el modelo y reduce dependencia de strings como `SteamID2`.

## Conclusión

La mejora correcta del proyecto no es acercarse mas al motor, sino aislarlo mejor:

- motor como capa de entrada
- core como capa de dominio
- API del core como contrato para terceros
