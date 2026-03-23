-- ================================================================
-- CallVote Manager - MySQL Base Schema
-- ================================================================

CREATE TABLE IF NOT EXISTS `callvote_log` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `caller_account_id` INT NOT NULL,
    `caller_steamid64` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `created` INT NOT NULL DEFAULT 0,
    `type` INT NOT NULL DEFAULT 0,
    `target_account_id` INT NOT NULL DEFAULT 0,
    `target_steamid64` BIGINT UNSIGNED NOT NULL DEFAULT 0,

    PRIMARY KEY (`id`),
    KEY `idx_callvote_log_created` (`created`),
    KEY `idx_callvote_log_type_created` (`type`, `created`),
    KEY `idx_callvote_log_caller_account_created` (`caller_account_id`, `created`),
    KEY `idx_callvote_log_caller_steamid64_created` (`caller_steamid64`, `created`),
    KEY `idx_callvote_log_target_account_created` (`target_account_id`, `created`),
    KEY `idx_callvote_log_target_steamid64_created` (`target_steamid64`, `created`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SELECT 'CallVote Manager MySQL base schema installed successfully' AS `status`;
