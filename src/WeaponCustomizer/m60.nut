IncludeScript("src/VSLib");

::WC_M60_Class <- "weapon_rifle_m60";
::WC_M60_Clip <- 200;
::WC_M60_ReserveGrant <- 200;
::WC_M60_ReserveMax <- 200;
::WC_M60_Verbose <- false;
::WC_M60_ReloadUsed <- {};
::WC_M60_Inited <- {};

::WC_M60_IsM60 <- function (sClassname)
{
    return sClassname == ::WC_M60_Class;
}

::WC_M60_Log <- function (player, sMsg)
{
    if (!::WC_M60_Verbose) return;
    if (player == null || !player.IsPlayerEntityValid()) return;
    if (player.IsBot()) return;

    player.Print("[M60] " + sMsg, 3);
}

::WC_M60_IsSurvivor <- function (player)
{
    if (player == null || !player.IsPlayerEntityValid()) return false;
    return player.GetTeam() == SURVIVORS;
}

::WC_M60_InitWeapon <- function (player, wep)
{
    if (!::WC_M60_IsSurvivor(player)) return;
    if (wep == null || !wep.IsEntityValid()) return;
    if (!::WC_M60_IsM60(wep.GetClassname())) return;

    local iWepIdx = wep.GetIndex();
    if (iWepIdx in ::WC_M60_Inited) return;
    ::WC_M60_Inited[iWepIdx] <- true;

    local iUid = player.GetUserID();
    local bUsed = (iUid in ::WC_M60_ReloadUsed) && ::WC_M60_ReloadUsed[iUid];

    wep.SetClip(::WC_M60_Clip);
    wep.SetAmmo(bUsed ? 0 : ::WC_M60_ReserveGrant);

    ::WC_M60_Log(player, "Sẵn sàng: clip=" + ::WC_M60_Clip
        + " dự trữ=" + (bUsed ? 0 : ::WC_M60_ReserveGrant)
        + (bUsed ? " (đã hết lượt nạp chapter)" : " (còn 1 lượt nạp)"));
}

::WC_M60_ReassertClip <- function (params)
{
    local wep = params.wep;
    if (wep == null || !wep.IsEntityValid()) return;
    if (!::WC_M60_IsM60(wep.GetClassname())) return;

    if (wep.GetClip() < ::WC_M60_Clip)
    {
        wep.SetClip(::WC_M60_Clip);
    }
}

::VSLib.EasyLogic.Notifications.OnWeaponReload.WC_M60 <- function (player, manual, params)
{
    if (!::WC_M60_IsSurvivor(player)) return;

    local wep = player.GetActiveWeapon();
    if (wep == null || !wep.IsEntityValid()) return;
    if (!::WC_M60_IsM60(wep.GetClassname())) return;

    local iUid = player.GetUserID();
    local bUsed = (iUid in ::WC_M60_ReloadUsed) && ::WC_M60_ReloadUsed[iUid];

    if (bUsed)
    {
        wep.SetAmmo(0);
        ::WC_M60_Log(player, "Đã hết lượt nạp của chapter này.");
        return;
    }

    ::WC_M60_ReloadUsed[iUid] <- true;
    wep.SetClip(::WC_M60_Clip);
    wep.SetAmmo(0);

    ::VSLib.Timers.AddTimer(0.5, false, ::WC_M60_ReassertClip, { wep = wep });
};

::VSLib.EasyLogic.Notifications.OnWeaponGiven.WC_M60 <- function (player, giver, weapon, params)
{
    ::WC_M60_InitWeapon(player, weapon);
};

::VSLib.EasyLogic.Notifications.OnItemPickup.WC_M60 <- function (player, weapon, params)
{
    if (!::WC_M60_IsM60(weapon)) return;
    ::WC_M60_InitWeapon(player, player.GetActiveWeapon());
};

::WC_M60_Apply <- function ()
{
    Convars.SetValue("ammo_m60_max", ::WC_M60_ReserveMax);
}

::VSLib.EasyLogic.Notifications.OnRoundStart.WC_M60 <- function ()
{
    ::WC_M60_Apply();
    ::WC_M60_ReloadUsed.clear(); 
    ::WC_M60_Inited.clear();
};

::WC_M60_Apply();
