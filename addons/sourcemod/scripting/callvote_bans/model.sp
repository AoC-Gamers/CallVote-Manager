#if defined _cvb_model_included
	#endinput
#endif
#define _cvb_model_included

enum struct PlayerBanInfo
{
	int AccountId;
	int BanType;
	int CreatedTimestamp;
	int DurationMinutes;
	int ExpiresTimestamp;
	int AdminAccountId;
	SourceDB DbSource;
	ReplySource CommandReplySource;
	char Reason[128];

	void Reset(int accountId = 0)
	{
		this.AccountId = accountId;
		this.BanType = 0;
		this.CreatedTimestamp = 0;
		this.DurationMinutes = 0;
		this.ExpiresTimestamp = 0;
		this.AdminAccountId = 0;
		this.DbSource = SourceDB_Unknown;
		this.CommandReplySource = SM_REPLY_TO_CONSOLE;
		this.Reason[0] = '\0';
	}

	void GetReason(char[] buffer, int maxlen)
	{
		strcopy(buffer, maxlen, this.Reason);
	}

	void SetReason(const char[] reason)
	{
		strcopy(this.Reason, sizeof(this.Reason), reason);
	}

	bool IsValid()
	{
		return this.AccountId > 0;
	}

	bool IsBanned()
	{
		return this.BanType > 0 && !this.IsExpired();
	}

	bool IsExpired()
	{
		if (this.IsPermanent())
			return false;

		return GetTime() >= this.ExpiresTimestamp;
	}

	bool IsPermanent()
	{
		return this.ExpiresTimestamp == 0 && this.BanType > 0;
	}

	int GetTimeRemaining()
	{
		if (this.IsPermanent())
			return -1;
		if (this.IsExpired())
			return 0;
		return this.ExpiresTimestamp - GetTime();
	}

	void GetFormattedExpiration(char[] buffer, int maxlen)
	{
		if (this.IsPermanent())
			strcopy(buffer, maxlen, "Permanent");
		else if (this.IsExpired())
			strcopy(buffer, maxlen, "Expired");
		else
			FormatTime(buffer, maxlen, "%Y-%m-%d %H:%M:%S", this.ExpiresTimestamp);
	}

	void GetFormattedDuration(char[] buffer, int maxlen)
	{
		if (this.IsPermanent())
			strcopy(buffer, maxlen, "Permanent");
		else
			Format(buffer, maxlen, "%d minutes", this.DurationMinutes);
	}

	void GetBanTypeString(char[] buffer, int maxlen)
	{
		GetBanTypeString(this.BanType, buffer, maxlen);
	}

	void ApplyBan(int banType, int durationMinutes, const char[] reason, int adminAccountId)
	{
		this.BanType = banType;
		this.DurationMinutes = durationMinutes;
		this.SetReason(reason);
		this.AdminAccountId = adminAccountId;
		this.CreatedTimestamp = GetTime();
		this.ExpiresTimestamp = (durationMinutes > 0) ? (GetTime() + (durationMinutes * 60)) : 0;
	}

	void Clear()
	{
		this.Reset(this.AccountId);
	}

	void ToString(char[] buffer, int maxlen)
	{
		char banTypes[64];
		char expiration[32];
		this.GetBanTypeString(banTypes, sizeof(banTypes));
		this.GetFormattedExpiration(expiration, sizeof(expiration));

		Format(
			buffer,
			maxlen,
			"PlayerBanInfo[AccountID=%d, BanType=%d(%s), Duration=%d, Expires=%s, Reason=%s]",
			this.AccountId,
			this.BanType,
			banTypes,
			this.DurationMinutes,
			expiration,
			this.Reason
		);
	}
}

int CVB_GetExpirationTimestamp(int durationMinutes)
{
	return (durationMinutes <= 0) ? 0 : (GetTime() + (durationMinutes * 60));
}
