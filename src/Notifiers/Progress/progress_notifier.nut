IncludeScript("src/VSLib");
IncludeScript("src/Notifiers/Progress/localization");

::CPN_Milestones <- [25, 50, 75];
::CPN_Sound <- "Survival.team_record";
::CPN_PollInterval <- 1.0;
::CPN_Reached <- {};

::CPN_ReplaceLiteral <- function (str, needle, value)
{
    if (needle.len() == 0) return str;

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

::CPN_Loc <- function (sMessageKey, sClientLang, tSubs = null)
{
    local sFallback = ::CPN_Locale.fallback;
    local sLangCode = (sClientLang in ::CPN_Locale.languages) ? ::CPN_Locale.languages[sClientLang] : sFallback;

    if (!(sMessageKey in ::CPN_Locale.strings))
    {
        return sMessageKey;
    }

    local tVariants = ::CPN_Locale.strings[sMessageKey];
    local sText = (sLangCode in tVariants) 
                    ? tVariants[sLangCode]
                    : ((sFallback in tVariants) ? tVariants[sFallback] : sMessageKey);

    if (tSubs != null)
    {
        foreach (sName, val in tSubs)
        {
            sText = ::CPN_ReplaceLiteral(sText, "{" + sName + "}", val.tostring());
        }
    }

    return sText;
}

::CPN_AnnounceTo <- function (player, iProgress)
{
    local sMsg = ::CPN_Loc("progress_reached", player.GetClientConvarValue("cl_language"), { P = iProgress });

    player.Print(sMsg, 3);

    if (::CPN_Sound != null)
    {
        player.PlaySound(::CPN_Sound);
    }
}

::CPN_Tick <- function (params)
{
    local sMode = ::VSLib.Utils.GetBaseMode();
    if (sMode == null || sMode.len() == 0) return;
    if (sMode[0] == 's' || sMode[0] == 'v') return;

    foreach (player in ::VSLib.EasyLogic.Players.AllSurvivors())
    {
        if (player == null || !player.IsEntityValid()) continue;
        if (player.IsBot()) continue;

        local sKey = player.GetSteamID();
        if (sKey == null || sKey == "") continue;
        if (!(sKey in ::CPN_Reached))
        {
            ::CPN_Reached[sKey] <- 0;
        }

        local flPercent = player.GetFlowPercent();
        while (::CPN_Reached[sKey] < ::CPN_Milestones.len() && flPercent >= ::CPN_Milestones[::CPN_Reached[sKey]])
        {
            ::CPN_AnnounceTo(player, ::CPN_Milestones[::CPN_Reached[sKey]]);
            ::CPN_Reached[sKey]++;
        }
    }
}

::VSLib.EasyLogic.Notifications.OnRoundStart.CampaignProgressNotifier <- function ()
{
    ::CPN_Reached.clear();
};

::VSLib.Timers.AddTimerByName("CampaignProgressNotifier_Poll", ::CPN_PollInterval, true, ::CPN_Tick);
