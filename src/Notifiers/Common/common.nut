IncludeScript("src/VSLib");
IncludeScript("src/Notifiers/Common/localization");

::NTF_LIGHT_GREEN <- "\x03";
::NTF_MaxMessageBytes <- 200;
::NTF_SoundDelaySec <- 2;
::NTF_NextSoundTime <- 0;
::NTF_L4D1_SURVIVOR_SET <- 1;

::NTF_RegisterStrings <- function (tStrings)
{
    foreach (sKey, tVariants in tStrings)
    {
        ::NTF_Locale.strings[sKey] <- tVariants;
    }
}

::NTF_IsValidPlayer <- function (player)
{
    return player != null && player.IsPlayerEntityValid();
}

::NTF_GetPlayer <- function (userId)
{
    if (userId == null || userId == 0) return null;

    local player = ::VSLib.Utils.GetPlayerFromUserID(userId);
    return ::NTF_IsValidPlayer(player) ? player : null;
}

::NTF_GetActiveWeaponKey <- function (player)
{
    local weapon = player.GetActiveWeapon();
    if (weapon == null) return "weapon_unknown";

    local sKey = weapon.GetClassname();
    if (sKey == "weapon_pistol" && player.HasDualPistols())
    {
        sKey += "_dual";
    }

    local sL4D1Key = sKey + "_l4d1";
    if (::VSLib.Utils.GetSurvivorSet() == ::NTF_L4D1_SURVIVOR_SET && (sL4D1Key in ::NTF_Locale.strings))
    {
        return sL4D1Key;
    }

    return sKey;
}

::NTF_GetCharacterSub <- function (player)
{
    local sName = player.GetCharacterName();
    local sKey = "char_" + sName.tolower();
    return (sKey in ::NTF_Locale.strings) ? { key = sKey } : sName;
}

::NTF_FormatPercent <- function (fValue)
{
    local sText = format("%.1f", fValue);
    return (sText.slice(-2) == ".0") ? sText.slice(0, -2) : sText;
}

::NTF_ReplaceLiteral <- function (str, needle, value)
{
    local out = "";
    local start = 0;
    local pos;
    while ((pos = str.find(needle, start)) != null)
    {
        out += str.slice(start, pos) + value;
        start = pos + needle.len();
    }
    out += str.slice(start);
    return out;
}

::NTF_Loc <- function (sMessageKey, sClientLang, tSubs = null)
{
    if (!(sMessageKey in ::NTF_Locale.strings))
    {
        return sMessageKey;
    }

    local sFallback = ::NTF_Locale.fallback;
    local sLangCode = (sClientLang in ::NTF_Locale.languages) ? ::NTF_Locale.languages[sClientLang] : sFallback;

    local tVariants = ::NTF_Locale.strings[sMessageKey];
    local sText = sMessageKey;
    if (sLangCode in tVariants)
    {
        sText = tVariants[sLangCode];
    }
    else if (sFallback in tVariants)
    {
        sText = tVariants[sFallback];
    }

    if (tSubs != null)
    {
        foreach (sName, val in tSubs)
        {
            local sValue = (typeof val == "table") ? ::NTF_Loc(val.key, sClientLang) : val.tostring();
            sText = ::NTF_ReplaceLiteral(sText, "{" + sName + "}", sValue);
        }
    }

    return sText;
}

::NTF_AppendLocLines <- function (tOut, tLines, sLang)
{
    foreach (line in tLines)
    {
        tOut.append(::NTF_Loc(line.key, sLang, line.subs));
    }
}

::NTF_PrintChunked <- function (player, tLines)
{
    local sChunk = null;
    foreach (sLine in tLines)
    {
        if (sChunk != null && sChunk.len() + 1 + sLine.len() > ::NTF_MaxMessageBytes)
        {
            player.Print(::NTF_LIGHT_GREEN + sChunk, HUD_PRINTTALK);
            sChunk = null;
        }
        sChunk = (sChunk == null) ? sLine : sChunk + "\n" + sLine;
    }

    if (sChunk != null)
    {
        player.Print(::NTF_LIGHT_GREEN + sChunk, HUD_PRINTTALK);
    }
}

::NTF_Broadcast <- function (sTagKey, tIntroLines, tStatLines = null)
{
    foreach (player in ::VSLib.EasyLogic.Players.All())
    {
        if (!::NTF_IsValidPlayer(player) || player.IsBot()) continue;

        local sLang = player.GetClientConvarValue("cl_language");
        local tOut = [::NTF_Loc(sTagKey, sLang)];
        ::NTF_AppendLocLines(tOut, tIntroLines, sLang);

        if (tStatLines != null && tStatLines.len() > 0)
        {
            tOut.append("");
            ::NTF_AppendLocLines(tOut, tStatLines, sLang);
        }

        ::NTF_PrintChunked(player, tOut);
    }
}

::NTF_BroadcastInline <- function (sTagKey, line)
{
    foreach (player in ::VSLib.EasyLogic.Players.All())
    {
        if (!::NTF_IsValidPlayer(player) || player.IsBot()) continue;

        local sLang = player.GetClientConvarValue("cl_language");
        local sText = ::NTF_Loc(sTagKey, sLang) + " " + ::NTF_Loc(line.key, sLang, line.subs);
        player.Print(::NTF_LIGHT_GREEN + sText, HUD_PRINTTALK);
    }
}

::NTF_PlayWarnSound <- function (sSound)
{
    if (sSound == null) return;

    local currentTime = Time();
    if (currentTime < ::NTF_NextSoundTime) return;

    ::VSLib.Utils.PlaySoundToAll(sSound);
    ::NTF_NextSoundTime = currentTime + ::NTF_SoundDelaySec;
}

::NTF_AddDamage <- function (tDamageMap, targetIdx, attackerId, damage)
{
    if (!(targetIdx in tDamageMap))
    {
        tDamageMap[targetIdx] <- {};
    }

    local tDamage = tDamageMap[targetIdx];
    if (!(attackerId in tDamage))
    {
        tDamage[attackerId] <- 0;
    }
    tDamage[attackerId] += damage;
}

::NTF_BuildRanking <- function (tDamage, maxHealth)
{
    local totalDamage = 0;
    foreach (dmg in tDamage)
    {
        totalDamage += dmg;
    }

    local scale = (totalDamage > maxHealth) ? maxHealth.tofloat() / totalDamage : 1.0;

    local tRanking = [];
    foreach (userId, dmg in tDamage)
    {
        local player = ::NTF_GetPlayer(userId);
        if (player == null) continue;

        tRanking.append({ name = player.GetName(), dmg = dmg * scale });
    }

    tRanking.sort(function (a, b) { return (a.dmg < b.dmg) ? 1 : ((a.dmg > b.dmg) ? -1 : 0); });
    return tRanking;
}

::NTF_BuildStatLines <- function (tDamageMap, targetIdx, maxHealth)
{
    if (!(targetIdx in tDamageMap)) return [];

    local tLines = [];
    foreach (i, entry in ::NTF_BuildRanking(tDamageMap[targetIdx], maxHealth))
    {
        tLines.append({ key = "stats_line", subs =
        {
            RANK = i + 1,
            NAME = entry.name,
            DMG = (entry.dmg + 0.5).tointeger(),
            PERCENT = ::NTF_FormatPercent(entry.dmg / maxHealth * 100)
        }});
    }

    return tLines;
}

::NTF_BuildKillIntro <- function (killer, sKeyBase, tExtraSubs = null)
{
    local sKey = sKeyBase + "_unknown";
    local tSubs = {};

    if (killer != null)
    {
        tSubs.WEAPON <- { key = ::NTF_GetActiveWeaponKey(killer) };

        tSubs.CHAR <- ::NTF_GetCharacterSub(killer);

        if (killer.IsBot())
        {
            sKey = sKeyBase + "_bot";
        }
        else
        {
            sKey = sKeyBase + "_player";
            tSubs.NAME <- killer.GetName();
        }
    }

    if (tExtraSubs != null)
    {
        foreach (sName, val in tExtraSubs)
        {
            tSubs[sName] <- val;
        }
    }

    return [{ key = sKey, subs = tSubs }];
}

::NTF_Forget <- function (tMaps, targetIdx)
{
    foreach (tMap in tMaps)
    {
        if (targetIdx in tMap)
        {
            delete tMap[targetIdx];
        }
    }
}

::VSLib.EasyLogic.Notifications.OnRoundStart.NTF_Reset <- function ()
{
    ::NTF_NextSoundTime = 0;
};
