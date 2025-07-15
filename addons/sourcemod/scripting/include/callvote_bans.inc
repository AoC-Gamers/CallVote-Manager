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
 * @param targetAccountId   AccountID del jugador baneado
 * @param targetSteamId2    SteamID2 del jugador baneado
 * @param banType           Tipos de ban aplicados (máscara de bits)
 * @param durationMinutes   Duración en minutos (0 = permanente)
 * @param adminAccountId    AccountID del admin (0 = CONSOLE)
 * @param adminSteamId2     SteamID2 del admin ("CONSOLE" para consola)
 * @param reason            Razón del ban
 * @noreturn
 */
forward void CVB_OnPlayerBanned(int targetAccountId, const char[] targetSteamId2, int banType, 
                               int durationMinutes, int adminAccountId, const char[] adminSteamId2, 
                               const char[] reason);

/**
 * Se ejecuta cuando se cargan las razones de ban del archivo de configuración
 *
 * @param reasonCount   Número de razones cargadas exitosamente
 * @noreturn
 */
forward void CVB_OnBanReasonsLoaded(int reasonCount);

/*****************************************************************
                    N A T I V E S
*****************************************************************/

/**
 * Verifica si un jugador está baneado para un tipo específico de voto
 *
 * @param client        Índice del cliente
 * @param voteType      Tipo de voto a verificar (usa enum TypeVotes de CallVoteManager)
 * @return              true si está baneado, false si no
 * @error               Cliente inválido
 */
native bool CVB_IsPlayerBanned(int client, int voteType);

/**
 * Obtiene el tipo de ban de un jugador (máscara de bits)
 *
 * @param client        Índice del cliente
 * @return              Máscara de bits con los tipos de ban activos
 * @error               Cliente inválido
 */
native int CVB_GetPlayerBanType(int client);

/**
 * Obtiene el timestamp de expiración del ban de un jugador
 *
 * @param client        Índice del cliente
 * @return              Timestamp de expiración (0 = permanente)
 * @error               Cliente inválido
 */
native int CVB_GetPlayerBanExpiration(int client);

/**
 * Banea a un jugador de tipos específicos de votación
 *
 * @param targetAccountId   AccountID del jugador objetivo
 * @param targetSteamId2    SteamID2 del jugador objetivo
 * @param banType           Tipos de ban (máscara de bits)
 * @param durationMinutes   Duración en minutos (0 = permanente)
 * @param adminAccountId    AccountID del admin (0 = CONSOLE)
 * @param adminSteamId2     SteamID2 del admin ("CONSOLE" para consola)
 * @param reason            Razón del ban
 * @return                  true si se ejecutó correctamente
 */
native bool CVB_BanPlayer(int targetAccountId, const char[] targetSteamId2, int banType, 
                         int durationMinutes, int adminAccountId, const char[] adminSteamId2, 
                         const char[] reason);

/**
 * Remueve el ban de un jugador
 *
 * @param targetAccountId   AccountID del jugador objetivo
 * @param targetSteamId2    SteamID2 del jugador objetivo
 * @param adminAccountId    AccountID del admin (0 = CONSOLE)
 * @param adminSteamId2     SteamID2 del admin ("CONSOLE" para consola)
 * @return                  true si se ejecutó correctamente
 */
native bool CVB_UnbanPlayer(int targetAccountId, const char[] targetSteamId2, 
                           int adminAccountId, const char[] adminSteamId2);

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
native bool CVB_GetBanInfo(int client, int &banType, int &expiration, int &createdTime, 
                          char[] reason, int reasonMaxLen, char[] adminSteamId, int adminMaxLen);

/**
 * Verifica si la información de ban del cliente está cargada
 *
 * @param client        Índice del cliente
 * @return              true si está cargada, false si aún está cargando
 * @error               Cliente inválido
 */
native bool CVB_IsClientLoaded(int client);

/**
 * Banea a un jugador usando índices de cliente (versión simplificada)
 *
 * @param targetClient      Índice del cliente objetivo
 * @param banType           Tipos de ban (máscara de bits)
 * @param durationMinutes   Duración en minutos (0 = permanente)
 * @param adminClient       Índice del cliente admin (0 = CONSOLE)
 * @param reason            Razón del ban
 * @return                  true si se ejecutó correctamente
 * @error                   Cliente objetivo inválido
 */
native bool CVB_BanPlayerByClient(int targetClient, int banType, int durationMinutes, 
                                 int adminClient, const char[] reason);

/**
 * Limpia el cache del sistema
 *
 * @param accountId     AccountID específico a limpiar (0 = limpiar todo el cache)
 * @return              true si se ejecutó correctamente
 */
native bool CVB_ClearCache(int accountId = 0);

/*****************************************************************
                    R E A S O N   S Y S T E M   N A T I V E S
*****************************************************************/

/**
 * Obtiene la cadena traducida para un código de razón de ban
 *
 * @param reasonCode    Código de la razón
 * @param client        Cliente para usar su idioma (0 = idioma del servidor)
 * @param buffer        Buffer para almacenar la cadena traducida
 * @param maxlen        Tamaño máximo del buffer
 * @return              true si se encontró la razón, false si no
 */
native bool CVB_GetBanReasonString(int reasonCode, int client, char[] buffer, int maxlen);

/**
 * Obtiene el ID de código de razón a partir de texto
 *
 * @param reasonText    Texto de la razón a buscar
 * @return              Código de la razón (0 si no se encuentra)
 */
native int CVB_GetReasonIdFromText(const char[] reasonText);

/**
 * Verifica si un código de razón es válido
 *
 * @param reasonCode    Código a verificar
 * @return              true si es válido, false si no
 */
native bool CVB_IsValidReasonCode(int reasonCode);

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
    MarkNativeAsOptional("CVB_GetPlayerBanExpiration");
    MarkNativeAsOptional("CVB_BanPlayer");
    MarkNativeAsOptional("CVB_UnbanPlayer");
    
    // Nuevos natives mejorados
    MarkNativeAsOptional("CVB_GetBanInfo");
    MarkNativeAsOptional("CVB_IsClientLoaded");
    MarkNativeAsOptional("CVB_BanPlayerByClient");
    MarkNativeAsOptional("CVB_ClearCache");
    
    // Natives del sistema de razones
    MarkNativeAsOptional("CVB_GetBanReasonString");
    MarkNativeAsOptional("CVB_GetReasonIdFromText");
    MarkNativeAsOptional("CVB_IsValidReasonCode");
}
#endif
