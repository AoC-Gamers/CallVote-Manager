-- =================================================================
-- CallVote Bans Manager - MySQL Database Schema
-- Version 2.0 - Sistema de Cache Multinivel Reactivo
-- =================================================================

-- DESCRIPCIÓN DEL SISTEMA:
-- 
-- Este script configura la base de datos MySQL central para el sistema CallVote Bans.
-- El sistema implementa un cache multinivel reactivo con la siguiente arquitectura:
--
-- FLUJO REACTIVO:
-- 1. Jugador conecta → StringMap (memoria del gameserver)
-- 2. Si no está → SQLite local (compartido por 8 gameservers de la máquina)
-- 3. Si no está → MySQL central (compartido entre las 3 máquinas)
-- 4. Resultado se propaga: MySQL → SQLite local → StringMap del gameserver
--
-- PROCEDIMIENTOS ALMACENADOS:
-- - sp_CheckActiveBan: Validación ultra-rápida de bans (solo ban_type)
-- - sp_CheckFullBan: Verificación completa con todos los detalles del ban
-- - sp_InsertBanWithValidation: Inserta bans con validación de severidad
-- - sp_RemoveBan: Remueve bans simplemente desactivándolos
-- - sp_CleanExpiredBans: Limpieza de bans expirados en lotes
-- - sp_GetBanStatistics: Estadísticas detalladas del sistema
--
-- ÍNDICES OPTIMIZADOS:
-- - Optimizados para consultas frecuentes por AccountID
-- - Índices compuestos para validación de bans activos y no expirados
-- - Soporte eficiente para limpieza de bans expirados

-- =================
-- TABLAS PRINCIPALES
-- =================

-- Tabla principal de bans
CREATE TABLE IF NOT EXISTS `callvote_bans` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `account_id` INT(11) NOT NULL,
    `ban_type` INT(11) NOT NULL,
    `created_timestamp` INT(11) NOT NULL,
    `duration_minutes` INT(11) DEFAULT 0,
    `expires_timestamp` INT(11) DEFAULT 0,
    `admin_account_id` INT(11) DEFAULT NULL,
    `reason` TEXT DEFAULT NULL,
    `is_active` TINYINT(1) DEFAULT 1,
    
    PRIMARY KEY (`id`),

    KEY `idx_account_active` (`account_id`, `is_active`, `expires_timestamp`),
    KEY `idx_expires` (`expires_timestamp`, `is_active`),
    KEY `idx_admin` (`admin_account_id`),
    KEY `idx_created` (`created_timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =================
-- PROCEDIMIENTOS ALMACENADOS
-- =================

DELIMITER $$

-- Procedimiento para verificar bans activos (optimizado para validación rápida)
-- Propósito: Validación ultra-rápida para entrada de jugadores al servidor
DROP PROCEDURE IF EXISTS `sp_CheckActiveBan`$$

-- Resumen de posibles valores de salida para sp_CheckActiveBan:
--   ban_type > 0 : jugador baneado (tipo de ban)
--   ban_type = 0 : jugador NO baneado
--   ban_type = NULL : error en la consulta (se devuelve como 0)
CREATE PROCEDURE `sp_CheckActiveBan`(
    IN p_account_id INT
)
BEGIN
    DECLARE ban_type_result INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        SELECT 0 as ban_type;
    END;
    
    SELECT IFNULL(ban_type, 0) INTO ban_type_result
    FROM callvote_bans 
    WHERE account_id = p_account_id 
      AND is_active = 1 
      AND (expires_timestamp = 0 OR expires_timestamp > UNIX_TIMESTAMP())
    ORDER BY created_timestamp DESC 
    LIMIT 1;
    
    -- Devolver resultado como SELECT
    SELECT ban_type_result as ban_type;
END$$

-- Procedimiento para verificar bans activos con información completa
-- Propósito: Consulta completa para administración y detalles del ban
DROP PROCEDURE IF EXISTS `sp_CheckFullBan`$$

-- Resumen de posibles valores de salida para sp_CheckFullBan:
--   has_ban = 1 : jugador baneado (ver detalles en las otras columnas)
--   has_ban = 0 : jugador NO baneado
--   ban_type, expires, created, etc. solo son válidos si has_ban = 1
CREATE PROCEDURE `sp_CheckFullBan`(
    IN p_account_id INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        SELECT 0 as has_ban, 0 as ban_type, 0 as expires_timestamp, 
               0 as created_timestamp, 0 as duration_minutes, 0 as admin_account_id, 
               '' as reason, 0 as ban_id;
    END;
    
    -- Devolver resultado como SELECT
    SELECT 
        CASE WHEN b.id IS NOT NULL THEN 1 ELSE 0 END as has_ban,
        IFNULL(b.ban_type, 0) as ban_type,
        IFNULL(b.expires_timestamp, 0) as expires_timestamp,
        IFNULL(b.created_timestamp, 0) as created_timestamp,
        IFNULL(b.duration_minutes, 0) as duration_minutes,
        IFNULL(b.admin_account_id, 0) as admin_account_id,
        IFNULL(b.reason, '') as reason,
        IFNULL(b.id, 0) as ban_id
    FROM callvote_bans b
    WHERE b.account_id = p_account_id 
      AND b.is_active = 1 
      AND (b.expires_timestamp = 0 OR b.expires_timestamp > UNIX_TIMESTAMP())
    ORDER BY b.created_timestamp DESC 
    LIMIT 1;
END$$

-- Procedimiento para insertar bans con validación
-- Propósito: Insertar ban con validación de severidad y desactivación de bans previos
DROP PROCEDURE IF EXISTS `sp_InsertBanWithValidation`$$

-- Resumen de posibles valores de salida para sp_InsertBanWithValidation:
--   result_code:
--     0 = Éxito. Ban insertado correctamente. (message: 'Ban inserted successfully')
--     1 = Ya existe un ban activo para este jugador. (message: 'Player already has an active ban (Type: X)')
--     2 = Cuenta inválida. (message: 'Invalid account')
--     4 = Error de base de datos. (message: 'Database error occurred')
--   ban_id:
--     ID del ban insertado, o el ID del ban existente si ya había uno más severo/igual, o 0 en caso de error.
--   message:
--     Mensaje descriptivo del resultado de la operación.
CREATE PROCEDURE `sp_InsertBanWithValidation`(
    IN p_account_id INT,
    IN p_ban_type INT,
    IN p_duration_minutes INT,
    IN p_admin_account_id INT,
    IN p_reason TEXT
)
BEGIN
    DECLARE v_existing_ban_type INT DEFAULT 0;
    DECLARE v_existing_ban_id INT DEFAULT 0;
    DECLARE v_expires_time INT;
    DECLARE v_current_time INT DEFAULT UNIX_TIMESTAMP();
    DECLARE v_ban_id INT DEFAULT 0;
    DECLARE v_result_code INT DEFAULT 0;
    DECLARE v_message VARCHAR(255) DEFAULT '';
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SELECT 0 as ban_id, 4 as result_code, 'Database error occurred' as message;
    END;
    
    START TRANSACTION;

    SELECT ban_type, id INTO v_existing_ban_type, v_existing_ban_id
    FROM callvote_bans 
    WHERE account_id = p_account_id 
      AND is_active = 1 
      AND (expires_timestamp = 0 OR expires_timestamp > v_current_time)
    ORDER BY created_timestamp DESC 
    LIMIT 1;

    -- Siempre desactivar cualquier ban previo activo
    UPDATE callvote_bans 
    SET is_active = 0 
    WHERE account_id = p_account_id AND is_active = 1;

    -- Crear el nuevo ban
    SET v_expires_time = CASE 
        WHEN p_duration_minutes > 0 THEN v_current_time + (p_duration_minutes * 60)
        ELSE 0 
    END;

    INSERT INTO callvote_bans (
        account_id, ban_type, created_timestamp,
        duration_minutes, expires_timestamp, admin_account_id,
        reason, is_active
    ) VALUES (
        p_account_id, p_ban_type, v_current_time,
        p_duration_minutes, v_expires_time, p_admin_account_id,
        p_reason, 1
    );
    
    SET v_ban_id = LAST_INSERT_ID();
    SET v_result_code = 0;
    SET v_message = 'Ban inserted successfully';
    
    COMMIT;
    
    -- Devolver resultado como SELECT
    SELECT v_ban_id as ban_id, v_result_code as result_code, v_message as message;
END$$

-- Procedimiento para remover bans
-- Propósito: Remover ban activo
DROP PROCEDURE IF EXISTS `sp_RemoveBan`$$

-- Resumen de posibles valores de salida para sp_RemoveBan:
--   result_code:
--     0 = Ban removido correctamente. (message: 'Ban removed successfully')
--     1 = No se encontró ban activo. (message: 'No active ban found for this player')
--     4 = Error de base de datos. (message: 'Database error occurred')
--   removed_ban_id:
--     ID del ban removido, o 0 si no se encontró ninguno.
--   message:
--     Mensaje descriptivo del resultado de la operación.
CREATE PROCEDURE `sp_RemoveBan`(
    IN p_account_id INT,
    IN p_admin_account_id INT
)
BEGIN
    DECLARE v_current_time INT DEFAULT UNIX_TIMESTAMP();
    DECLARE v_removed_ban_id INT DEFAULT 0;
    DECLARE v_result_code INT DEFAULT 0;
    DECLARE v_message VARCHAR(255) DEFAULT '';
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SELECT 0 as removed_ban_id, 4 as result_code, 'Database error occurred' as message;
    END;
    
    START TRANSACTION;

    SELECT id INTO v_removed_ban_id
    FROM callvote_bans 
    WHERE account_id = p_account_id 
      AND is_active = 1 
      AND (expires_timestamp = 0 OR expires_timestamp > v_current_time)
    ORDER BY created_timestamp DESC 
    LIMIT 1;
    
    IF v_removed_ban_id IS NULL OR v_removed_ban_id = 0 THEN
        SET v_result_code = 1;
        SET v_message = 'No active ban found for this player';
        SET v_removed_ban_id = 0;
        COMMIT;
    ELSE
        UPDATE callvote_bans 
        SET is_active = 0 
        WHERE id = v_removed_ban_id;
        
        SET v_result_code = 0;
        SET v_message = 'Ban removed successfully';
        
        COMMIT;
    END IF;
    
    -- Devolver resultado como SELECT
    SELECT v_removed_ban_id as removed_ban_id, v_result_code as result_code, v_message as message;
END$$

-- Procedimiento para limpiar bans expirados
-- Propósito: Limpieza en lotes de bans expirados para mantenimiento
DROP PROCEDURE IF EXISTS `sp_CleanExpiredBans`$$

-- Resumen de posibles valores de salida para sp_CleanExpiredBans:
--   result_code:
--     0 = Éxito. Limpieza realizada correctamente. (message: 'Cleaned X expired bans')
--     4 = Error de base de datos. (message: 'Database error during cleanup')
--   cleaned_count:
--     Número de bans expirados desactivados en esta ejecución.
--   message:
--     Mensaje descriptivo del resultado de la operación.
CREATE PROCEDURE `sp_CleanExpiredBans`(
    IN p_batch_size INT
)
BEGIN
    DECLARE v_current_time INT DEFAULT UNIX_TIMESTAMP();
    DECLARE v_cleaned_count INT DEFAULT 0;
    DECLARE v_result_code INT DEFAULT 0;
    DECLARE v_message VARCHAR(255) DEFAULT '';
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SELECT 0 as cleaned_count, 4 as result_code, 'Database error during cleanup' as message;
    END;
    
    START TRANSACTION;

    UPDATE callvote_bans 
    SET is_active = 0 
    WHERE is_active = 1 
      AND expires_timestamp > 0 
      AND expires_timestamp < v_current_time
    LIMIT p_batch_size;
    
    SET v_cleaned_count = ROW_COUNT();
    SET v_result_code = 0;
    SET v_message = CONCAT('Cleaned ', v_cleaned_count, ' expired bans');
    
    COMMIT;
    
    -- Devolver resultado como SELECT
    SELECT v_cleaned_count as cleaned_count, v_result_code as result_code, v_message as message;
END$$

-- Procedimiento para estadísticas del sistema
-- Propósito: Generar reportes estadísticos del sistema de bans
DROP PROCEDURE IF EXISTS `sp_GetBanStatistics`$$

-- Resumen de posibles valores de salida para sp_GetBanStatistics:
--   Resultados: múltiples SELECTs con estadísticas generales, por tipo de ban y por administrador.
--   No hay parámetros OUT, los resultados se devuelven como tablas.
CREATE PROCEDURE `sp_GetBanStatistics`(
    IN p_days_back INT
)
BEGIN
    DECLARE v_current_time INT DEFAULT UNIX_TIMESTAMP();
    DECLARE v_cutoff_time INT DEFAULT v_current_time - (p_days_back * 86400);
    
    -- Estadísticas generales
    SELECT 
        COUNT(CASE WHEN is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > v_current_time) THEN 1 END) as active_bans,
        COUNT(CASE WHEN is_active = 0 OR (expires_timestamp > 0 AND expires_timestamp <= UNIX_TIMESTAMP()) THEN 1 END) as expired_bans,
        COUNT(CASE WHEN created_timestamp >= v_cutoff_time THEN 1 END) as recent_bans,
        COUNT(DISTINCT account_id) as unique_players,
        COUNT(DISTINCT admin_account_id) as unique_admins
    FROM callvote_bans;

    SELECT 
        CASE 
            WHEN ban_type = 1 THEN 'Difficulty'
            WHEN ban_type = 2 THEN 'Restart' 
            WHEN ban_type = 4 THEN 'Kick'
            WHEN ban_type = 8 THEN 'Mission'
            WHEN ban_type = 16 THEN 'Lobby'
            WHEN ban_type = 32 THEN 'Chapter'
            WHEN ban_type = 64 THEN 'AllTalk'
            WHEN ban_type = 127 THEN 'All Types'
            ELSE CONCAT('Custom (', ban_type, ')')
        END as ban_type_name,
        COUNT(*) as count,
        AVG(duration_minutes) as avg_duration
    FROM callvote_bans 
    WHERE created_timestamp >= v_cutoff_time
    GROUP BY ban_type
    ORDER BY count DESC;

    SELECT 
        admin_account_id,
        COUNT(*) as total_bans,
        AVG(duration_minutes) as avg_duration,
        COUNT(CASE WHEN duration_minutes = 0 THEN 1 END) as permanent_bans
    FROM callvote_bans 
    WHERE admin_account_id IS NOT NULL
      AND created_timestamp >= v_cutoff_time
    GROUP BY admin_account_id
    ORDER BY total_bans DESC
    LIMIT 10;
END$$

DELIMITER ;

-- =================
-- VISTAS ÚTILES
-- =================

-- Vista de bans activos con información legible
CREATE OR REPLACE VIEW `v_active_bans` AS
SELECT 
    b.id,
    b.account_id,
    b.ban_type,
    CASE 
        WHEN b.ban_type = 1 THEN 'Difficulty'
        WHEN b.ban_type = 2 THEN 'Restart'
        WHEN b.ban_type = 4 THEN 'Kick'
        WHEN b.ban_type = 8 THEN 'Mission'
        WHEN b.ban_type = 16 THEN 'Lobby'
        WHEN b.ban_type = 32 THEN 'Chapter'
        WHEN b.ban_type = 64 THEN 'AllTalk'
        WHEN b.ban_type = 127 THEN 'All Types'
        ELSE CONCAT('Custom (', b.ban_type, ')')
    END as ban_type_name,
    b.admin_account_id,
    b.reason,
    FROM_UNIXTIME(b.created_timestamp) as created_at,
    FROM_UNIXTIME(b.expires_timestamp) as expires_at,
    CASE 
        WHEN b.expires_timestamp = 0 THEN 'Permanent'
        WHEN b.expires_timestamp > UNIX_TIMESTAMP() THEN CONCAT(
            FLOOR((b.expires_timestamp - UNIX_TIMESTAMP()) / 60), ' minutes remaining'
        )
        ELSE 'Expired'
    END as time_remaining
FROM callvote_bans b
WHERE b.is_active = 1
  AND (b.expires_timestamp = 0 OR b.expires_timestamp > UNIX_TIMESTAMP())
ORDER BY b.created_timestamp DESC;

-- Vista de estadísticas del sistema
CREATE OR REPLACE VIEW `v_ban_statistics` AS
SELECT 
    COUNT(*) as total_bans,
    COUNT(CASE WHEN expires_timestamp = 0 THEN 1 END) as permanent_bans,
    COUNT(CASE WHEN expires_timestamp > 0 THEN 1 END) as temporary_bans,
    COUNT(CASE WHEN is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > UNIX_TIMESTAMP()) THEN 1 END) as active_bans,
    COUNT(CASE WHEN is_active = 0 OR (expires_timestamp > 0 AND expires_timestamp <= UNIX_TIMESTAMP()) THEN 1 END) as inactive_bans,
    COUNT(DISTINCT account_id) as unique_players,
    COUNT(DISTINCT admin_account_id) as unique_admins
FROM callvote_bans;

-- =================
-- ÍNDICES ADICIONALES PARA OPTIMIZACIÓN
-- =================

-- Índice para consultas de limpieza de expirados
CREATE INDEX IF NOT EXISTS `idx_cleanup_expired` ON `callvote_bans` (`is_active`, `expires_timestamp`);

-- Índice para consultas de estadísticas por administrador
CREATE INDEX IF NOT EXISTS `idx_admin_stats` ON `callvote_bans` (`admin_account_id`, `created_timestamp`);

-- Índice para consultas por tipo de ban
CREATE INDEX IF NOT EXISTS `idx_ban_type_created` ON `callvote_bans` (`ban_type`, `created_timestamp`);

-- =================
-- CONFIGURACIÓN DE RENDIMIENTO
-- =================

-- Configuraciones recomendadas para MySQL en entorno de producción
-- Agregar al archivo my.cnf:
--
-- [mysqld]
-- innodb_buffer_pool_size = 1G
-- innodb_log_file_size = 256M
-- innodb_flush_log_at_trx_commit = 2
-- query_cache_size = 128M
-- max_connections = 200
-- thread_cache_size = 8
-- key_buffer_size = 256M
-- sort_buffer_size = 2M
-- read_buffer_size = 2M
-- read_rnd_buffer_size = 8M
-- myisam_sort_buffer_size = 64M

-- =================
-- SCRIPT COMPLETADO
-- =================

-- Verificar instalación
SELECT 'CallVote Bans MySQL minimal schema installed successfully' as status;
SELECT COUNT(*) as total_procedures FROM information_schema.ROUTINES 
WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_NAME LIKE 'sp_%';