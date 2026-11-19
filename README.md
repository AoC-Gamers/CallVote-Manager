# CallVote Manager

Suite SourceMod para gestionar votaciones en Left 4 Dead 2. El [core](docs/voting/README.md) intercepta las votaciones, captura el contexto de la sesión y expone el ciclo de vida a otros plugins.

| Componente | Función |
|---|---|
| [`callvote_manager`](docs/manager/README.md) | Reglas de votación y avisos a los jugadores. |
| [`callvote_sql`](docs/database/README.md) | Registro de votaciones confirmadas en MySQL o SQLite. |
| [`callvote_kicklimit`](docs/restrictions/kick-limit.md) | Límite de frecuencia de solicitudes de votekick. |
| [`callvote_bans`](docs/restrictions/README.md) | Restricciones de voto y API de administración. |

## Instalación

Extrae el ZIP de [GitHub Releases](https://github.com/AoC-Gamers/CallVote-Manager/releases) en `left4dead2/` y conserva `addons/sourcemod/plugins/callvote/`.
Instala el core y carga los módulos que necesites. Consulta el [índice de documentación](docs/README.md)
para configurar cada componente o diagnosticar votaciones.

## Licencia

El código y los aportes originales de lechuga se distribuyen bajo [GPL-3.0-only](LICENSE). Las atribuciones y los términos de terceros se recogen en [NOTICES.md](NOTICES.md).
