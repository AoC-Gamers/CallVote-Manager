#if defined _callvote_bans_included
    #endinput
#endif
#define _callvote_bans_included

#include <callvote_stock>

/*****************************************************************
                    F O R W A R D S
*****************************************************************/

/**
 * Se ejecuta cuando un voto es bloqueado por el sistema de bans
 *
 * @param client        Cliente que intentó iniciar el voto
 * @param voteType      Tipo de voto que fue bloqueado
 * @param target        Objetivo del voto (si aplica)
 * @param banType       Tipo de ban que causó el bloqueo
 * @noreturn
 */
forward void CVB_OnVoteBlocked(int client, int voteType, int target, int banType);

/**
 * Se ejecuta cuando un jugador es baneado
 *
 * @param target            Índice del cliente baneado
 * @param banType           Tipos de ban aplicados (máscara de bits)
 * @param durationMinutes   Duración en minutos (0 = permanente)
 * @param admin             Índice del cliente admin (0 = CONSOLE)
 * @param reason            Razón del ban
 * @noreturn
 */
forward void CVB_OnPlayerBanned(int target, int banType, int durationMinutes, int admin, const char[] reason);

/*****************************************************************
                    N A T I V E S
*****************************************************************/

/**
 * Verifica si un jugador está baneado para un tipo específico de voto
 *
 * @param client        Índice del cliente
 * @return              true si está baneado, false si no
 * @error               Cliente inválido
 */
native bool CVB_IsPlayerBanned(int client);

/**
 * Obtiene el tipo de ban de un jugador (máscara de bits)
 *
 * @param client        Índice del cliente
 * @return              Máscara de bits con los tipos de ban activos
 * @error               Cliente inválido
 */
native int CVB_GetPlayerBanType(int client);

/**
 * Banea a un jugador usando índices de cliente
 *
 * @param target            Índice del cliente objetivo
 * @param banType           Tipos de ban (máscara de bits)
 * @param duration          Duración en minutos (0 = permanente)
 * @param admin             Índice del cliente admin (0 = CONSOLE)
 * @param reason            Razón del ban
 * @return                  true si se ejecutó correctamente
 * @error                   Cliente objetivo inválido
 */
native bool CVB_BanPlayer(int target, int banType, int duration, int admin, const char[] reason);

/**
 * Remueve el ban de un jugador
 *
 * @param target            Índice del cliente objetivo
 * @param admin             Índice del cliente admin (0 = CONSOLE)
 * @return                  true si se ejecutó correctamente
 */
native bool CVB_UnbanPlayer(int target, int admin);

/**
 * Obtiene información completa del ban de un jugador
 *
 * @param client            Índice del cliente
 * @param banType           Variable para almacenar el tipo de ban
 * @param expiration        Variable para almacenar timestamp de expiración
 * @param createdTime       Variable para almacenar timestamp de creación
 * @param reason            Buffer para almacenar la razón
 * @param reasonMaxLen      Tamaño máximo del buffer de razón
 * @param adminSteamId      Buffer para almacenar SteamID del admin
 * @param adminMaxLen       Tamaño máximo del buffer de admin
 * @return                  true si la información está disponible
 * @error                   Cliente inválido
 */
native bool CVB_GetBanInfo(int client, int &banType, int &expiration, int &createdTime,char[] reason, int reasonMaxLen, char[] adminSteamId, int adminMaxLen);

public SharedPlugin __pl_callvote_bans =
{
    name = "callvote_bans",
    file = "callvote_bans.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_callvote_bans_SetNTVOptional()
{
    MarkNativeAsOptional("CVB_IsPlayerBanned");
    MarkNativeAsOptional("CVB_GetPlayerBanType");
    MarkNativeAsOptional("CVB_BanPlayer");
    MarkNativeAsOptional("CVB_UnbanPlayer");
    MarkNativeAsOptional("CVB_GetBanInfo");
}
#endif
