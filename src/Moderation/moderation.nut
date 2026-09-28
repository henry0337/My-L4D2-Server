IncludeScript("src/VSLib");
IncludeScript("src/Moderation/localization");

::MOD_KickWarnSeconds <- 10;
::MOD_BanPermanent    <- true;
::MOD_BanMinutes      <- 0;
::MOD_BlacklistFile   <- "moderation_blacklist";

::MOD_Blacklist <- ::VSLib.FileIO.LoadTable(::MOD_BlacklistFile);
if (::MOD_Blacklist == null)
{
    ::MOD_Blacklist <- {};
}

::MOD_TempBlock <- {};
::MOD_Commands <- {};

::MOD_RegisterCommand <- function (sTrigger, fnHandler)
{
    ::MOD_Commands[sTrigger.tolower()] <- fnHandler;
}

::MOD_FindSurvivorByCharacter <- function (sQuery)
{
    local sWanted = sQuery.tolower();
    foreach (player in ::VSLib.EasyLogic.Players.AllSurvivors())
    {
        if (player == null || !player.IsEntityValid() || player.IsBot()) continue;
        if (player.GetCharacterName().tolower() == sWanted || player.GetBaseCharacterName().tolower() == sWanted)
        {
            return player;
        }
    }
    return null;
}

::MOD_ParseDuration <- function (sToken)
{
    if (sToken == null || sToken == "") return 0;
    sToken = sToken.tolower();

    local iMult = 1;
    local last = sToken[sToken.len() - 1];
    if (last == 'm') 
    { 
        iMult = 60;
        sToken = sToken.slice(0, sToken.len() - 1); 
    }
    else if (last == 's') 
    { 
        sToken = sToken.slice(0, sToken.len() - 1); 
    }

    local iVal = sToken.tointeger();
    return (iVal > 0) ? iVal * iMult : 0;
}

::MOD_FormatDuration <- function (iSeconds, sLang)
{
    if (iSeconds >= 60 && iSeconds % 60 == 0)
    {
        return ::MOD_Loc("dur_minutes", sLang, { V = iSeconds / 60 });
    }
    return ::MOD_Loc("dur_seconds", sLang, { V = iSeconds });
}

::MOD_NativeBanAndKick <- function (iUserID)
{
    local iMinutes = ::MOD_BanPermanent ? 0 : ::MOD_BanMinutes;
    SendToServerConsole("banid " + iMinutes + " " + iUserID);
    SendToServerConsole("writeid");
    SendToServerConsole("kickid " + iUserID);
}

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

::MOD_DoKick <- function (data)
{
    if (data.seconds > 0)
    {
        ::MOD_TempBlock[data.steamid] <- true;
        ::VSLib.Timers.AddTimer(data.seconds, false, ::MOD_ClearTempBlock, { steamid = data.steamid });
    }
    SendToServerConsole("kickid " + data.userid);
}

::MOD_ClearTempBlock <- function (data)
{
    if (data.steamid in ::MOD_TempBlock) 
    {
        delete ::MOD_TempBlock[data.steamid];
    }
}

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

    local sTargetLang = target.GetClientConvarValue("cl_language");
    if (iSeconds > 0)
        target.Print(::MOD_Loc("kick_warn_temp", sTargetLang, { D = ::MOD_FormatDuration(iSeconds, sTargetLang), W = ::MOD_KickWarnSeconds }), 3);
    else
        target.Print(::MOD_Loc("kick_warn_now", sTargetLang, { W = ::MOD_KickWarnSeconds }), 3);

    ::VSLib.Timers.AddTimer(::MOD_KickWarnSeconds, false, ::MOD_DoKick, { userid = target.GetUserID(), steamid = sSteamID, seconds = iSeconds });

    local sDur = (iSeconds > 0) ? ::MOD_FormatDuration(iSeconds, sLang) : ::MOD_Loc("dur_none", sLang);
    host.Print(::MOD_Loc("kick_done", sLang, { P = target.GetName(), N = target.GetCharacterName(), D = sDur, W = ::MOD_KickWarnSeconds }), 3);
}

::VSLib.EasyLogic.Notifications.OnSay.Moderation <- function (player, text, params)
{
    if (typeof player != "instance" || !player.IsEntityValid()) return;

    local tokens = [];
    foreach (t in split(text, " "))
    {
        if (t != null && t != "") 
        {
            tokens.append(t);
        }
    }
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
    for (local i = 1; i < tokens.len(); i++)
    {
        args.append(tokens[i]);
    }
    ::MOD_Commands[sCmd](player, args, sLang);
};

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

::MOD_RegisterCommand("!ban", ::MOD_CmdBan);
::MOD_RegisterCommand("!kick", ::MOD_CmdKick);
