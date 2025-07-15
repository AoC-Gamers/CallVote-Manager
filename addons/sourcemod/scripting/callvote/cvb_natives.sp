#if defined _cvb_natives_included
	#endinput
#endif
#define _cvb_natives_included

/**
 * Obtiene la cadena traducida para un código de razón
 */
public int Native_GetBanReasonString(Handle plugin, int numParams)
{
	int reasonCode = GetNativeCell(1);
	int client = GetNativeCell(2);
	int maxlen = GetNativeCell(4);
	
	char buffer[256];
	GetBanReasonString_FromConfig(reasonCode, client, buffer, sizeof(buffer));
	
	SetNativeString(3, buffer, maxlen);
	
	BanReasonInfo reason;
	return GetBanReasonByCode(reasonCode, reason);
}

/**
 * Obtiene el ID de razón a partir de texto
 */
public int Native_GetReasonIdFromText(Handle plugin, int numParams)
{
	int maxlen = 256;
	char reasonText[256];
	GetNativeString(1, reasonText, maxlen);
	
	return GetReasonIdFromConfig(reasonText);
}

/**
 * Verifica si un código de razón es válido
 */
public int Native_IsValidReasonCode(Handle plugin, int numParams)
{
	int code = GetNativeCell(1);
	BanReasonInfo reason;
	return GetBanReasonByCode(code, reason) ? 1 : 0;
}
