# 🚫 Call Vote Kick Limit - Documentación Completa

[![License](https://img.shields.io/badge/license-GPL%20v3-blue.svg)](LICENSE)
[![SourceMod](https://img.shields.io/badge/SourceMod-1.11%2B-orange.svg)](https://www.sourcemod.net/)
[![Game](https://img.shields.io/badge/game-Left%204%20Dead%202-red.svg)](https://store.steampowered.com/app/550/Left_4_Dead_2/)

**Sistema inteligente de prevención de abuso en votaciones de expulsión (VoteKick).**

[🏠 Volver al índice principal](README.md) | [🎯 CallVote Manager](README_MANAGER.md) | [🔒 CallVote Bans](README_BANS.md)

---

## 🚧 **En Desarrollo**

Esta documentación está en proceso de desarrollo. El plugin CallVote Kick Limit está funcional pero la documentación completa será agregada en una próxima actualización.

### **Características Básicas Disponibles**
- ✅ Control de límites de kicks por jugador/mapa
- ✅ Contador persistente con base de datos
- ✅ Comando `sm_kicks` para ver estadísticas
- ✅ Configuración flexible de límites

### **Configuración Rápida**
```ini
# CVARs principales
sm_ckl_enable "1"           // Activar plugin
sm_ckl_max_kicks "3"        // Máximo kicks por mapa
sm_ckl_reset_time "60"      // Tiempo de reset en minutos
```

### **Comandos Disponibles**
| Comando | Descripción |
|---------|-------------|
| `sm_ckl_sql_install` | Instalar tablas SQL |
| `sm_kicks` | Ver estadísticas de kicks |

---

## 📋 **Pendiente de Documentar**

- [ ] Descripción detallada del sistema
- [ ] Guía completa de instalación
- [ ] Configuración avanzada
- [ ] Lista completa de comandos
- [ ] API para desarrolladores
- [ ] Estructura de base de datos
- [ ] Solución de problemas
- [ ] Ejemplos de uso

---

**Documentación completa próximamente...**

**[🏠 Volver al índice principal](README.md) | [🔒 Siguiente: CallVote Bans →](README_BANS.md)**

---

*Plugin desarrollado por **lechuga16** - Parte del CallVote Manager Suite*
