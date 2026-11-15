IncludeScript("src/Shared/shared");
IncludeScript("src/Notifiers/Common/localization");

const NTF_TAG_INLINE = "[\x01!\x03]";
const NTF_TAG_STATS = "\x03★\x04";

::NTF_SoundDelaySec <- 2;
::NTF_NextSoundTime <- 0;
::NTF_L4D1_SURVIVOR_SET <- 1;

::NTF_RegisterStrings <- function (tStrings)
{
    ::Shared.Localization.Register(::NTF_Locale, tStrings);
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

::NTF_Loc <- function (sMessageKey, sClientLang, tSubs = null)
{
    return ::Shared.Localization.Resolve(::NTF_Locale, sMessageKey, sClientLang, tSubs);
}

::NTF_AppendLocLines <- function (tOut, tLines, sLang)
{
    foreach (line in tLines)
    {
        tOut.append(::NTF_Loc(line.key, sLang, line.subs));
    }
}

::NTF_Broadcast <- function (tIntroLines, tStatLines = null)
{
    foreach (player in ::VSLib.EasyLogic.Players.All())
    {
        if (!::Shared.Players.IsValid(player) || player.IsBot()) continue;

        local sLang = ::Shared.Players.GetLanguage(player);
        local tOut = [];
        ::NTF_AppendLocLines(tOut, tIntroLines, sLang);
        if (tOut.len() > 0)
        {
            tOut[0] = NTF_TAG_STATS + " " + tOut[0];
        }

        if (tStatLines != null && tStatLines.len() > 0)
        {
            tOut.append("");
            ::NTF_AppendLocLines(tOut, tStatLines, sLang);
        }

        ::Shared.Chat.TargetChat(tOut, player.GetBaseEntity(), CHAT_COLOR_LIGHT_GREEN);
    }
}

::NTF_BroadcastInline <- function (line)
{
    foreach (player in ::VSLib.EasyLogic.Players.All())
    {
        if (!::Shared.Players.IsValid(player) || player.IsBot()) continue;

        local sLang = ::Shared.Players.GetLanguage(player);
        local sText = NTF_TAG_INLINE + " " + ::NTF_Loc(line.key, sLang, line.subs);
        player.Print(CHAT_COLOR_LIGHT_GREEN + sText, HUD_PRINTTALK);
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
        local player = ::Shared.Players.GetByUserId(userId);
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
            PERCENT = ::Shared.Strings.FormatPercent(entry.dmg / maxHealth * 100)
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
