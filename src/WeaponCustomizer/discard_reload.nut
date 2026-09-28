IncludeScript("src/VSLib");

::WC_DR_Exclude <-
{
    weapon_rifle_m60      = true,
    weapon_chainsaw       = true,
    weapon_pumpshotgun    = true,
    weapon_shotgun_chrome = true,
    weapon_autoshotgun    = true,
    weapon_shotgun_spas   = true
};
::WC_DR_PollInterval <- 0.1;
::WC_DR_Verbose <- true;
::WC_DR_State <- {};

::WC_DR_GetPrimary <- function (player)
{
    local t = player.GetHeldItems();
    if (t == null || !("slot0" in t)) return null;

    local wep = t["slot0"];
    if (wep == null || !wep.IsEntityValid()) return null;

    return wep;
}

::WC_DR_ProcessPlayer <- function (player)
{
    if (player == null || !player.IsPlayerEntityValid()) return;

    local iUid = player.GetUserID();
    local wep = ::WC_DR_GetPrimary(player);

    if (wep == null || (wep.GetClassname() in ::WC_DR_Exclude))
    {
        if (iUid in ::WC_DR_State) 
        {
            delete ::WC_DR_State[iUid];
        }
        return;
    }

    local iWepIdx  = wep.GetIndex();
    local iClipNow = wep.GetClip();
    local iResNow  = wep.GetAmmo();
    if (iClipNow == null || iResNow == null) return;

    if (!(iUid in ::WC_DR_State) || ::WC_DR_State[iUid].wepIdx != iWepIdx)
    {
        ::WC_DR_State[iUid] <- { wepIdx = iWepIdx, clip = iClipNow, reserve = iResNow, pendClip = null, pendReserve = null };
        return;
    }

    local prev = ::WC_DR_State[iUid];

    if (iClipNow == prev.clip && iResNow == prev.reserve) return;

    if (iClipNow > prev.clip && iResNow < prev.reserve)
    {
        local iOldClip        = (prev.pendClip != null) ? prev.pendClip : prev.clip;
        local iReserveBefore  = (prev.pendReserve != null) ? prev.pendReserve : prev.reserve;
        local iMaxClip = wep.GetMaxClip();
        if (iMaxClip == null || iMaxClip <= 0)
        {
            iMaxClip = iClipNow;
        }

        local iTargetClip    = (iReserveBefore < iMaxClip) ? iReserveBefore : iMaxClip;
        local iTargetReserve = iReserveBefore - iTargetClip;

        wep.SetAmmo(iTargetReserve);

        if (iClipNow > iTargetClip)
        {
            wep.SetClip(iTargetClip);
            iClipNow = iTargetClip;
        }

        if (::WC_DR_Verbose && !player.IsBot())
        {
            player.Print("[Reload] Vứt " + iOldClip + " viên dở; băng mới " + iClipNow + ", dự trữ " + iTargetReserve, 3);
        }

        prev.clip = iClipNow;
        prev.reserve = iTargetReserve;
        prev.pendClip = null;
        prev.pendReserve = null;
        return;
    }

    if (iClipNow < prev.clip && iResNow > prev.reserve)
    {
        if (prev.pendClip == null)
        {
            prev.pendClip = prev.clip;
            prev.pendReserve = prev.reserve;
        }
        prev.clip = iClipNow;
        prev.reserve = iResNow;
        return;
    }

    prev.clip = iClipNow;
    prev.reserve = iResNow;
    prev.pendClip = null;
    prev.pendReserve = null;
};

::WC_DR_Tick <- function (params)
{
    foreach (player in ::VSLib.EasyLogic.Players.AllSurvivors())
    {
        ::WC_DR_ProcessPlayer(player);
    }
};

::VSLib.EasyLogic.Notifications.OnRoundStart.WC_DR <- function ()
{
    ::WC_DR_State.clear();
};

::VSLib.Timers.AddTimerByName("WC_DiscardReload_Poll", ::WC_DR_PollInterval, true, ::WC_DR_Tick);
