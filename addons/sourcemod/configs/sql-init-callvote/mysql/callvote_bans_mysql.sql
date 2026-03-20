-- ================================================================
-- CallVote Bans - MySQL Base Schema
-- ================================================================
--
-- Este schema instala solo la tabla principal y sus indices.
-- El plugin ya no usa stored procedures ni vistas runtime.
-- La logica de lectura y escritura vive en SQL directo desde SourceMod.

CREATE TABLE IF NOT EXISTS `callvote_bans` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `account_id` INT(11) NOT NULL,
    `steamid64` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `ban_type` INT(11) NOT NULL,
    `created_timestamp` INT(11) NOT NULL,
    `duration_minutes` INT(11) NOT NULL DEFAULT 0,
    `expires_timestamp` INT(11) NOT NULL DEFAULT 0,
    `active_until_timestamp` INT(11) NOT NULL DEFAULT 2147483647,
    `admin_account_id` INT(11) NOT NULL DEFAULT 0,
    `admin_steamid64` BIGINT UNSIGNED DEFAULT NULL,
    `reason` TEXT DEFAULT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,

    PRIMARY KEY (`id`),

    KEY `idx_account_active_until_created` (`account_id`, `is_active`, `active_until_timestamp`, `created_timestamp`),
    KEY `idx_account_created` (`account_id`, `created_timestamp`),
    KEY `idx_steamid64_active_until` (`steamid64`, `is_active`, `active_until_timestamp`),
    KEY `idx_admin_created` (`admin_account_id`, `created_timestamp`),
    KEY `idx_admin_steamid64_created` (`admin_steamid64`, `created_timestamp`),
    KEY `idx_active_until` (`active_until_timestamp`, `is_active`),
    KEY `idx_created` (`created_timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SELECT 'CallVote Bans MySQL base schema installed successfully' AS `status`;
