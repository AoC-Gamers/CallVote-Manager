-- =================================================================
-- CallVote Bans Manager - SQLite Local Cache Schema
-- Version 2.0 - Sistema de Cache Multinivel Reactivo
-- =================================================================

-- DESCRIPCIÓN DEL SISTEMA DE CACHE LOCAL:
-- 
-- Este script configura la base de datos SQLite local que actúa como cache
-- intermedio en el sistema CallVote Bans de cache multinivel reactivo.
--
-- ARQUITECTURA DE CACHE LOCAL:
-- - Cada máquina física tiene UNA base SQLite compartida por 8 gameservers
-- - Esta base actúa como Nivel 2 de cache (entre StringMap y MySQL)
-- - TTL configurable (recomendado: 24-48 horas para multi-máquina)
-- - Optimizada para acceso concurrente de múltiples gameservers
--
-- FLUJO DE CACHE LOCAL:
-- 1. GameServer busca en StringMap (Nivel 1) → no encuentra
-- 2. GameServer busca en SQLite local (Nivel 2) → AQUÍ estamos
-- 3. Si no encuentra → consulta MySQL central (Nivel 3)
-- 4. Resultado de MySQL se guarda aquí para futuras consultas
-- 5. Los otros 7 gameservers de la máquina se benefician del cache
--
-- CARACTERÍSTICAS:
-- - Estructura compatible con MySQL pero optimizada para SQLite
-- - Timestamps en formato UNIX para compatibilidad
-- - Índices optimizados para consultas frecuentes
-- - TTL automático para evitar datos obsoletos
-- - Sin procedimientos almacenados (no soportados en SQLite)
--
-- VENTAJAS:
-- - Acceso ultrarrápido para 8 gameservers de la máquina
-- - Reduce drasticamente consultas a MySQL central
-- - Funciona aunque MySQL esté caído
-- - Auto-limpieza de registros expirados
--
-- GESTIÓN:
-- - Tamaño típico: 1-5 MB por máquina (miles de jugadores cacheados)
-- - Limpieza automática con comando: sm_cvb_sqlite_vacuum
-- - Monitoreo con: sm_cvb_sqlite_stats
-- - Limpieza manual con: sm_cvb_cache_clear

-- =================
-- TABLA PRINCIPAL DE CACHE
-- =================

-- Tabla de cache simplificada (solo bans permanentes)
CREATE TABLE IF NOT EXISTS `callvote_bans_cache` (
    `account_id` INTEGER PRIMARY KEY,
    `ban_type` INTEGER NOT NULL DEFAULT 0,
    
    -- Control básico del cache
    `cached_timestamp` INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    `ttl_expires` INTEGER NOT NULL DEFAULT 0
);

-- =================
-- ÍNDICES OPTIMIZADOS PARA SQLITE
-- =================

-- Índice principal para búsquedas por AccountID (ya incluido como PRIMARY KEY)

-- Índice para limpieza de TTL expirado
CREATE INDEX IF NOT EXISTS `idx_cache_ttl_cleanup` ON `callvote_bans_cache`(`ttl_expires`);

-- =================
-- FUNCIONES SQL PARA MANTENIMIENTO
-- =================

-- LIMPIEZA DE REGISTROS EXPIRADOS:
-- DELETE FROM callvote_bans_cache WHERE ttl_expires <= strftime('%s', 'now');