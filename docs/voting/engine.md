# Señales de voto del motor

HL2SDK documenta el transporte de eventos y usermessages. La suite se
apoya en señales observadas en Left 4 Dead 2 para correlacionar cada voto.

| Capa | Señales |
|---|---|
| Eventos | `vote_started`, `vote_changed` y `vote_ended`. |
| Usermessages | `VoteStart`, `VotePass`, `VoteFail` y `CallVoteFailed`. |
| Entidad de juego | `vote_controller`. |

El core reúne tipo, argumento, progreso, participantes y resultado en
una sesión de voto. Captura `AccountID` para mantener la identidad cuando
cambia el slot o se desconecta un participante. Consulta el
[contrato público del core](README.md) y las [reglas por modo](by-mode.md).
