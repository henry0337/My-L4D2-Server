IncludeScript("src/Shared/shared");
if (!("NTF_Loc" in getroottable())) IncludeScript("src/Notifiers/Common/common");
IncludeScript("src/SelfHelp/localization");
::NTF_RegisterStrings(::SH_Strings);

::SH_TickInterval <- 0.1;
::SH_DefaultReviveDuration <- 5.0;
::SH_MedkitClass <- "weapon_first_aid_kit";

::SH_Cases <- {};
::SH_CaseOrder <- [];
::SH_Active <- {};
::SH_Warned <- {};

::SH_RegisterCase <- function (sName, tCase)
{
    ::SH_Cases[sName] <- tCase;
    ::SH_CaseOrder.append(tCase);
}

::SH_FindCase <- function (player)
{
    foreach (tCase in ::SH_CaseOrder)
    {
        if (tCase.matches(player)) return tCase;
    }
    return null;
}

::SH_GetBaseDuration <- function ()
{
    return ::Shared.Convar.GetPositiveFloat("survivor_revive_duration", ::SH_DefaultReviveDuration);
}

::SH_DifficultyFactor <-
{
    easy = 1.25,
    normal = 1.5,
    hard = 1.75,
    impossible = 2.0
};
::SH_DefaultFactor <- 1.5;

::SH_GetDifficultyDuration <- function ()
{
    return ::SH_GetBaseDuration() * ::Shared.Difficulty.Pick(::SH_DifficultyFactor, ::SH_DefaultFactor);
}

::SH_GetMedkit <- function (player)
{
    return ::Shared.Players.GetHeldItemOfClass(player, SLOT_HEALTH, ::SH_MedkitClass);
}

::SH_IsSelfOwned <- function (player)
{
    return ::Shared.Players.IsSelfRevived(player);
}

::SH_IsBeingRevived <- function (player)
{
    return ::Shared.Players.IsRevivedByOther(player);
}

::SH_SetBar <- function (player, startTime, duration)
{
    player.SetNetProp(NETPROP_PROGRESS_BAR_START, startTime);
    player.SetNetProp(NETPROP_PROGRESS_BAR_DURATION, duration);
}

::SH_Log <- function (sText)
{
    ::Shared.Chat.Log("[SH] " + sText);
}

::SH_State <- function (player)
{
    return "hang=" + player.IsHangingFromLedge() + " inc=" + player.IsIncapacitated() + " hp=" + player.GetRawHealth() + " rc=" + player.GetReviveCount();
}

::SH_Cancel <- function (idx, bCompleted = false)
{
    if (!(idx in ::SH_Active)) return;

    local tState = ::SH_Active[idx];
    local player = tState.player;
    delete ::SH_Active[idx];

    if (!player.IsPlayerEntityValid()) return;

    ::SH_SetBar(player, 0.0, 0.0);

    if ("onCancel" in tState.tCase)
    {
        tState.tCase.onCancel(player, bCompleted);
    }

    if (::SH_IsSelfOwned(player))
    {
        player.SetNetPropEntity(NETPROP_REVIVE_OWNER, null);
    }
}

::SH_Start <- function (player, idx, tCase)
{
    local now = Time();
    local duration = tCase.duration(player);

    ::SH_Log("start: " + ::SH_State(player) + " duck=" + player.IsPressingDuck() + " dur=" + duration);
    ::SH_Active[idx] <- { player = player, tCase = tCase, start = now, duration = duration };

    if ("onStart" in tCase)
    {
        tCase.onStart(player);
    }

    player.SetNetPropEntity(NETPROP_REVIVE_OWNER, player);
    ::SH_SetBar(player, now, duration);
}

::SH_Restart <- function (player, tState)
{
    local now = Time();
    tState.start = now;
    tState.duration = tState.tCase.duration(player);
    ::SH_SetBar(player, now, tState.duration);
}

::SH_Complete <- function (player, idx)
{
    local tState = ::SH_Active[idx];
    local tCase = tState.tCase;

    if (("roll" in tCase) && !tCase.roll(player))
    {
        ::SH_Log("attempt failed, retrying");
        ::SH_Restart(player, tState);
        return;
    }

    local medkit = ::SH_GetMedkit(player);
    ::SH_Cancel(idx, medkit != null);

    if (medkit == null) return;
    if (!tCase.revive(player)) return;

    if (!("keepMedkit" in tCase))
    {
        medkit.Kill();
    }
}

::SH_Warn <- function (player, idx)
{
    if (idx in ::SH_Warned) return;
    ::SH_Warned[idx] <- true;

    local sLang = ::Shared.Players.GetLanguage(player);
    player.Print(::NTF_Loc("selfhelp_need_medkit", sLang), HUD_PRINTTALK);
}

::SH_Process <- function (player, idx, tCase)
{
    if ((idx in ::SH_Active) && ::SH_Active[idx].tCase != tCase)
    {
        ::SH_Cancel(idx);
    }

    if (!player.IsPressingDuck())
    {
        ::SH_Cancel(idx);
        if (idx in ::SH_Warned) delete ::SH_Warned[idx];
        return;
    }

    if (::SH_IsBeingRevived(player))
    {
        ::SH_Cancel(idx);
        return;
    }

    if (::SH_GetMedkit(player) == null)
    {
        ::SH_Cancel(idx);
        ::SH_Warn(player, idx);
        return;
    }

    if (!(idx in ::SH_Active))
    {
        ::SH_Start(player, idx, tCase);
        return;
    }

    local tState = ::SH_Active[idx];
    if (Time() >= tState.start + tState.duration)
    {
        ::SH_Complete(player, idx);
    }
}

::SH_Tick <- function (params)
{
    local tSeen = {};

    foreach (player in ::VSLib.EasyLogic.Players.Survivors())
    {
        if (player.IsBot() || player.IsDead()) continue;

        local tCase = ::SH_FindCase(player);
        if (tCase == null) continue;

        local idx = player.GetIndex();
        tSeen[idx] <- true;
        ::SH_Process(player, idx, tCase);
    }

    foreach (idx, tState in clone ::SH_Active)
    {
        if (!(idx in tSeen)) ::SH_Cancel(idx);
    }

    foreach (idx, bWarned in clone ::SH_Warned)
    {
        if (!(idx in tSeen)) delete ::SH_Warned[idx];
    }
}

::VSLib.EasyLogic.Notifications.OnRoundStart.SH_Reset <- function ()
{
    foreach (idx, tState in clone ::SH_Active)
    {
        ::SH_Cancel(idx);
    }
    ::SH_Warned.clear();
};

::VSLib.Timers.AddTimerByName("SH_Tick", ::SH_TickInterval, true, ::SH_Tick);
