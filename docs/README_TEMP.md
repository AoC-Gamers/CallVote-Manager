# CallVote Manager Suite

[![License](https://img.shields.io/badge/license-GPL%20v3-blue.svg)](LICENSE)
[![SourceMod](https://img.shields.io/badge/SourceMod-1.11%2B-orange.svg)](https://www.sourcemod.net/)
[![Version](https://img.shields.io/badge/version-2.0.0--API--Enhanced-green.svg)](https://github.com/lechuga16/callvote_manager/releases)
[![Game](https://img.shields.io/badge/game-Left%204%20Dead%202-red.svg)](https://store.steampowered.com/app/550/Left_4_Dead_2/)
[![API](https://img.shields.io/badge/API-Enhanced--v2.0-brightgreen.svg)](README_BANS.md#api-para-desarrolladores)

[🇪🇸 Español](README_ES.md) | [🇺🇸 English](README.md) | [🌍 Auto-translate](https://translate.google.com/translate?sl=es&tl=en&u=https://github.com/lechuga16/callvote_manager)

**Sistema modular completo para administración avanzada de votaciones en servidores de Left 4 Dead 2 con SourceMod.**

---

## 📦 **Plugins Incluidos**

Este repositorio contiene **3 plugins independientes** que trabajan juntos para proporcionar control total sobre el sistema de votaciones de Left 4 Dead 2:

### 🎯 **[Call Vote Manager](README_MANAGER.md)** - Plugin Principal
El núcleo del sistema que maneja todas las votaciones del servidor.

**Características principales:**
- ✅ **Gestión completa** de aprobación/denegación automática de votaciones
- ✅ **Funciones nativas** para integración con otros plugins 
- ✅ **Registro detallado** de todas las votaciones (local o SQL)
- ✅ **Inmunidad configurable** para administradores y VIPs
- ✅ **Soporte multi-idioma** con traducciones completas
- ✅ **Integración con Mission Manager** para nombres localizados

**[📖 Ver documentación completa →](README_MANAGER.md)**

---

### 🚫 **[Call Vote Kick Limit](README_KICKLIMIT.md)** - Control de Abuso
Previene el spam y abuso de votaciones de expulsión (VoteKick).

**Características principales:**
- ✅ **Límites inteligentes** de kicks por jugador/mapa
- ✅ **Contador persistente** con respaldo en base de datos
- ✅ **Estadísticas detalladas** para administradores
- ✅ **Configuración flexible** por servidor
- ✅ **Anuncios opcionales** de actividad de kicks

**[📖 Ver documentación completa →](README_KICKLIMIT.md)** *(En desarrollo)*

---

### 🔒 **[Call Vote Bans](README_BANS.md)** - Sistema de Restricciones ⭐ **v2.0 API MEJORADA**
Sistema avanzado para banear jugadores de tipos específicos de votaciones.

**Características principales:**
- ✅ **Cache multinivel** optimizado (StringMap + SQLite + MySQL)
- ✅ **Bans selectivos** por tipo de votación (kick, restart, mission, etc.)
- ✅ **API v2.0 expandida** con 12+ natives y forwards automáticos
- ✅ **Procedimientos almacenados** para máximo rendimiento
- ✅ **Sistema de razones** configurable y extensible
- ✅ **Soporte universal** de formatos SteamID
- ✅ **Panel administrativo** interactivo con menús

**[📖 Ver documentación completa →](README_BANS.md)**

---

## 🚀 **Instalación Rápida**

### **1. Descargar Archivos**
```bash
# Clonar repositorio
git clone https://github.com/lechuga16/callvote_manager.git

# O descargar release
wget https://github.com/lechuga16/callvote_manager/releases/latest
```

### **2. Instalar Plugins**
```bash
# Copiar archivos compilados
addons/sourcemod/plugins/callvotemanager.smx     # Plugin principal
addons/sourcemod/plugins/callvote_kicklimit.smx  # Control de kicks  
addons/sourcemod/plugins/callvote_bans.smx       # Sistema de bans

# Copiar configuraciones
addons/sourcemod/configs/callvote_ban_reasons.cfg
addons/sourcemod/translations/callvote_*.phrases.txt
```

### **3. Configurar Base de Datos** *(Opcional - Solo para funciones SQL)*
```ini
# En addons/sourcemod/configs/databases.cfg
"callvote"
{
    "driver"    "mysql"
    "host"      "localhost" 
    "database"  "sourcemod"
    "user"      "root"
    "pass"      "password"
}
```

### **4. Activar Plugins**
```bash
# En consola del servidor
sm plugins load callvotemanager
sm plugins load callvote_kicklimit  
sm plugins load callvote_bans

# Instalar tablas (si usas MySQL)
sm_cvm_sql_install    # Call Vote Manager
sm_ckl_sql_install    # Kick Limit
sm_cvb_install force  # Call Vote Bans
```

---

## ⚙️ **Configuración Básica**

### **Configuración Mínima Recomendada**
```ini
# Call Vote Manager
sm_cvm_enable "1"           // Activar plugin principal
sm_cvm_announce "1"         // Anunciar votaciones

# Kick Limit  
sm_ckl_enable "1"           // Activar control de kicks
sm_ckl_max_kicks "3"        // Máximo 3 kicks por mapa

# Call Vote Bans
sm_cvb_enable "1"           // Activar sistema de bans
sm_cvb_cache_sqlite "1"     // Activar cache para rendimiento
```

### **Enlaces a Configuración Detallada**
- 🎯 **[Configuración Call Vote Manager](README_MANAGER.md#configuración)**
- 🚫 **[Configuración Kick Limit](README_KICKLIMIT.md#configuración)**
- 🔒 **[Configuración Call Vote Bans](README_BANS.md#configuración)**

---

## 🎮 **Comandos Principales**

### **Administración General**
| Plugin | Comando | Descripción |
|--------|---------|-------------|
| Manager | `sm_listmissions` | Listar misiones disponibles |
| Kick Limit | `sm_kicks` | Ver estadísticas de kicks |
| **Bans** | `sm_cvb_ban` | **Panel para banear jugadores** |
| **Bans** | `sm_cvb_check` | **Ver estado de restricciones** |

### **Enlaces a Comandos Completos**
- 🎯 **[Comandos Call Vote Manager](README_MANAGER.md#comandos)**
- 🚫 **[Comandos Kick Limit](README_KICKLIMIT.md#comandos)**
- 🔒 **[Comandos Call Vote Bans](README_BANS.md#comandos)** *(12+ comandos disponibles)*

---

## 🔗 **API para Desarrolladores**

### **Call Vote Bans API v2.0** ⭐ **MEJORADA**
El sistema de bans ofrece una **API completa** para integración con otros plugins:

```sourcepawn
// Verificación de estado
native bool CVB_IsPlayerBanned(int client, int voteType);
native bool CVB_IsClientLoaded(int client);  // NUEVO v2.0

// Información completa  
native bool CVB_GetBanInfo(int client, int &banType, int &expiration, ...);  // NUEVO v2.0

// Gestión simplificada
native bool CVB_BanPlayerByClient(int target, int banType, int duration, ...);  // NUEVO v2.0

// Eventos automáticos
forward void CVB_OnPlayerBanned(int accountId, const char[] steamId, ...);  // NUEVO v2.0
forward void CVB_OnPlayerUnbanned(int accountId, const char[] steamId, ...);  // NUEVO v2.0
```

**[📖 Ver API completa y ejemplos →](README_BANS.md#api-para-desarrolladores)**

---

## 🆕 **Novedades v2.0**

### **Call Vote Bans - API Expandida**
- ✅ **4 nuevos natives** para mayor flexibilidad
- ✅ **Forwards automáticos** para eventos de ban/unban  
- ✅ **Gestión de cache** avanzada con limpieza selectiva
- ✅ **Verificación de estado** previene errores de timing
- ✅ **Compatibilidad total** con plugins existentes

### **Mejoras Técnicas**
- ✅ **Compilación sin warnings** - código completamente limpio
- ✅ **Documentación completa** de API en archivos .inc
- ✅ **Cache multinivel** optimizado para máximo rendimiento
- ✅ **Procedimientos almacenados** para operaciones complejas

---

## 📊 **Compatibilidad y Requisitos**

### **Requisitos Mínimos**
- **SourceMod**: 1.11+
- **Juego**: Left 4 Dead 2
- **SO**: Windows/Linux
- **Base de datos**: MySQL 5.6+ *(opcional)*

### **Plugins Compatibles**
- ✅ **l4d2_mission_manager**: Nombres localizados
- ✅ **BuiltinVotes**: Integración mejorada
- ✅ **Cualquier plugin**: Usando la API nativa

---

## 🤝 **Soporte y Contribución**

### **Enlaces Importantes**
- 📁 **[Repositorio GitHub](https://github.com/lechuga16/callvote_manager)**
- 📋 **[Reportar Issues](https://github.com/lechuga16/callvote_manager/issues)**
- 🚀 **[Releases](https://github.com/lechuga16/callvote_manager/releases)**
- 📖 **[Wiki Detallada](https://github.com/lechuga16/callvote_manager/wiki)**

### **Documentación Individual**
- 🎯 **[Call Vote Manager - Documentación Completa](README_MANAGER.md)**
- 🚫 **[Call Vote Kick Limit - Documentación Completa](README_KICKLIMIT.md)**
- 🔒 **[Call Vote Bans - Documentación Completa](README_BANS.md)**

### **Soporte Técnico**
1. **Revisar documentación** específica del plugin
2. **Buscar en issues** existentes del repositorio
3. **Crear nuevo issue** con logs detallados si es necesario

---

## 📄 **Licencia y Créditos**

- **📜 Licencia**: GPL v3
- **👨‍💻 Autor**: lechuga16  
- **🤝 Colaboradores**: [Ver lista completa](https://github.com/lechuga16/callvote_manager/contributors)

---

*🎯 **CallVote Manager Suite** - Control total sobre las votaciones de tu servidor L4D2*
