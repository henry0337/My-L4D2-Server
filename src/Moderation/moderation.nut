//============================================================================
//  Moderation — Lệnh điều hành qua chat (host-only)
//  ---------------------------------------------------------------------------
//  Lệnh nhắm người chơi theo TÊN NHÂN VẬT survivor (Nick/Coach/Ellis/...):
//    !ban  <nhân_vật>            Ban vĩnh viễn (banid+writeid) + kick.
//    !kick <nhân_vật> [thời_gian] Kick tạm; cảnh báo trước, chặn vào lại trong
//                                 khoảng thời_gian rồi tự mở. Bỏ trống / 0 = kick
//                                 thường, vào lại được ngay.
//  Thời gian: "10m" = 10 phút, "5s" = 5 giây, số trần = giây, 0 = không chặn.
//
//  Thêm lệnh mới: viết handler(host, args, sLang) rồi ::MOD_RegisterCommand(...).
//============================================================================

IncludeScript("src/VSLib");
IncludeScript("src/Moderation/localization");

// --- Cấu hình ---
::MOD_KickWarnSeconds <- 10;            // Cảnh báo người bị kick trước bao nhiêu giây.
::MOD_BanPermanent    <- true;          // true = ban vĩnh viễn (banid 0).
::MOD_BanMinutes      <- 0;             // Số phút ban khi MOD_BanPermanent = false.
::MOD_BlacklistFile   <- "moderation_blacklist"; // VSLib::FileIO tự thêm ".tbl".

// Danh sách đen VĨNH VIỄN, nạp từ đĩa (bền qua map/restart). key = SteamID.
::MOD_Blacklist <- ::VSLib.FileIO.LoadTable(::MOD_BlacklistFile);
if (::MOD_Blacklist == null) ::MOD_Blacklist <- {};

// Chặn TẠM THỜI trong bộ nhớ cho !kick có thời hạn. key = SteamID. Reset mỗi map.
::MOD_TempBlock <- {};

// Sổ đăng ký lệnh: trigger(chữ thường) -> handler(host, args, sLang).
::MOD_Commands <- {};

/**
 * Đăng ký một lệnh chat.
 * @param sTrigger (string)   Ví dụ "!ban".
 * @param fnHandler (function) handler(host, args, sLang).
 */
::MOD_RegisterCommand <- function (sTrigger, fnHandler)
{
    ::MOD_Commands[sTrigger.tolower()] <- fnHandler;
}

//----------------------------------------------------------------------------
// Helper
//----------------------------------------------------------------------------

/**
 * Tìm survivor THẬT (bỏ bot) khớp tên nhân vật; so cả tên hiển thị lẫn tên gốc,
 * không phân biệt hoa thường.
 * @param sQuery (string)
 * @return (VSLib::Player|null)
 */
::MOD_FindSurvivorByCharacter <- function (sQuery)
{
    local sWanted = sQuery.tolower();
    foreach (player in ::VSLib.EasyLogic.Players.AllSurvivors())
    {
        if (player == null || !player.IsEntityValid() || player.IsBot()) continue;
        if (player.GetCharacterName().tolower() == sWanted || player.GetBaseCharacterName().tolower() == sWanted)
            return player;
    }
    return null;
}

/**
 * Phân tích chuỗi thời gian -> số giây. "10m"->600, "5s"->5, "30"->30, lỗi/0 -> 0.
 * @param sToken (string)
 * @return (int) Số giây (>= 0).
 */
::MOD_ParseDuration <- function (sToken)
{
    if (sToken == null || sToken == "") return 0;
    sToken = sToken.tolower();

    local iMult = 1;
    local last = sToken[sToken.len() - 1];
    if (last == 'm') { iMult = 60; sToken = sToken.slice(0, sToken.len() - 1); }
    else if (last == 's') { sToken = sToken.slice(0, sToken.len() - 1); }

    local iVal = sToken.tointeger();
    return (iVal > 0) ? iVal * iMult : 0;
}

/**
 * Định dạng số giây thành chuỗi thời lượng đã localized ("10 phút" / "5 giây").
 * @param iSeconds (int), @param sLang (string)
 * @return (string)
 */
::MOD_FormatDuration <- function (iSeconds, sLang)
{
    if (iSeconds >= 60 && iSeconds % 60 == 0)
        return ::MOD_Loc("dur_minutes", sLang, { V = iSeconds / 60 });
    return ::MOD_Loc("dur_seconds", sLang, { V = iSeconds });
}

//----------------------------------------------------------------------------
// Lệnh: !ban
//----------------------------------------------------------------------------

/**
 * Ban native (banid+writeid) rồi kick khỏi session. writeid lưu SteamID vào
 * banned_user.cfg nên chặn reconnect kể cả khi script không chạy.
 * @param iUserID (int)
 */
::MOD_NativeBanAndKick <- function (iUserID)
{
    local iMinutes = ::MOD_BanPermanent ? 0 : ::MOD_BanMinutes;
    SendToServerConsole("banid " + iMinutes + " " + iUserID);
    SendToServerConsole("writeid");
    SendToServerConsole("kickid " + iUserID);
}

/**
 * Handler lệnh !ban.
 * @param host (VSLib::Player), @param args (array), @param sLang (string)
 */
::MOD_CmdBan <- function (host, args, sLang)
{
    if (args.len() < 1)
    {
        host.Print(::MOD_Loc("ban_usage", sLang), 3);
        return;
    }

    local target = ::MOD_FindSurvivorByCharacter(args[0]);
    if (target == null)
    {
        host.Print(::MOD_Loc("not_found", sLang, { N = args[0] }), 3);
        return;
    }

    local sSteamID = target.GetSteamID();
    if (sSteamID == host.GetSteamID())
    {
        host.Print(::MOD_Loc("cannot_self", sLang), 3);
        return;
    }

    local sName = target.GetName(), sChar = target.GetCharacterName();
    ::MOD_Blacklist[sSteamID] <- { name = sName, character = sChar, reason = "!ban" };
    ::VSLib.FileIO.SaveTable(::MOD_BlacklistFile, ::MOD_Blacklist);
    ::MOD_NativeBanAndKick(target.GetUserID());

    host.Print(::MOD_Loc("ban_done", sLang, { P = sName, N = sChar, S = sSteamID }), 3);
}

//----------------------------------------------------------------------------
// Lệnh: !kick
//----------------------------------------------------------------------------

/**
 * Thực thi kick sau khi hết thời gian cảnh báo. Nếu có thời hạn thì thêm chặn
 * tạm + hẹn giờ tự gỡ.
 * @param data (table) { userid, steamid, seconds }
 */
::MOD_DoKick <- function (data)
{
    if (data.seconds > 0)
    {
        ::MOD_TempBlock[data.steamid] <- true;
        ::VSLib.Timers.AddTimer(data.seconds, false, ::MOD_ClearTempBlock, { steamid = data.steamid });
    }
    SendToServerConsole("kickid " + data.userid);
}

/**
 * Gỡ chặn tạm khi hết hạn.
 * @param data (table) { steamid }
 */
::MOD_ClearTempBlock <- function (data)
{
    if (data.steamid in ::MOD_TempBlock) delete ::MOD_TempBlock[data.steamid];
}

/**
 * Handler lệnh !kick. args[0]=nhân vật, args[1]=thời gian (tùy chọn).
 * @param host (VSLib::Player), @param args (array), @param sLang (string)
 */
::MOD_CmdKick <- function (host, args, sLang)
{
    if (args.len() < 1)
    {
        host.Print(::MOD_Loc("kick_usage", sLang), 3);
        return;
    }

    local target = ::MOD_FindSurvivorByCharacter(args[0]);
    if (target == null)
    {
        host.Print(::MOD_Loc("not_found", sLang, { N = args[0] }), 3);
        return;
    }

    local sSteamID = target.GetSteamID();
    if (sSteamID == host.GetSteamID())
    {
        host.Print(::MOD_Loc("cannot_self", sLang), 3);
        return;
    }

    local iSeconds = (args.len() >= 2) ? ::MOD_ParseDuration(args[1]) : 0;

    // Cảnh báo người bị kick theo ngôn ngữ của họ.
    local sTargetLang = target.GetClientConvarValue("cl_language");
    if (iSeconds > 0)
        target.Print(::MOD_Loc("kick_warn_temp", sTargetLang, { D = ::MOD_FormatDuration(iSeconds, sTargetLang), W = ::MOD_KickWarnSeconds }), 3);
    else
        target.Print(::MOD_Loc("kick_warn_now", sTargetLang, { W = ::MOD_KickWarnSeconds }), 3);

    // Hẹn giờ kick thực sự.
    ::VSLib.Timers.AddTimer(::MOD_KickWarnSeconds, false, ::MOD_DoKick,
        { userid = target.GetUserID(), steamid = sSteamID, seconds = iSeconds });

    // Báo cho host.
    local sDur = (iSeconds > 0) ? ::MOD_FormatDuration(iSeconds, sLang) : ::MOD_Loc("dur_none", sLang);
    host.Print(::MOD_Loc("kick_done", sLang, { P = target.GetName(), N = target.GetCharacterName(), D = sDur, W = ::MOD_KickWarnSeconds }), 3);
}

//----------------------------------------------------------------------------
// Điều phối & thực thi
//----------------------------------------------------------------------------

/**
 * Lắng nghe chat: nhận diện lệnh đã đăng ký, chặn quyền (chỉ host), tách tham số
 * và gọi handler tương ứng.
 */
::VSLib.EasyLogic.Notifications.OnSay.Moderation <- function (player, text, params)
{
    if (typeof player != "instance" || !player.IsEntityValid()) return;

    // Tách token, bỏ rỗng (chống dư khoảng trắng).
    local tokens = [];
    foreach (t in split(text, " "))
        if (t != null && t != "") tokens.append(t);
    if (tokens.len() == 0) return;

    local sCmd = tokens[0].tolower();
    if (!(sCmd in ::MOD_Commands)) return;

    local sLang = player.GetClientConvarValue("cl_language");
    if (!player.IsServerHost())
    {
        player.Print(::MOD_Loc("perm_denied", sLang), 3);
        return;
    }

    local args = [];
    for (local i = 1; i < tokens.len(); i++) args.append(tokens[i]);
    ::MOD_Commands[sCmd](player, args, sLang);
};

/**
 * Lưới chặn phụ: kick lại khi người trong danh sách đen (vĩnh viễn hoặc tạm) vào.
 */
::VSLib.EasyLogic.Notifications.OnPlayerJoined.Moderation <- function (entity, name, ip, steamID, params)
{
    if (steamID == null || steamID == "") return;
    if ((steamID in ::MOD_Blacklist) || (steamID in ::MOD_TempBlock))
    {
        if (entity != null && entity.IsEntityValid())
        {
            SendToServerConsole("kickid " + entity.GetUserID());
        }
    }
};

// --- Đăng ký lệnh ---
::MOD_RegisterCommand("!ban", ::MOD_CmdBan);
::MOD_RegisterCommand("!kick", ::MOD_CmdKick);
