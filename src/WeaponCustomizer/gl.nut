IncludeScript("src/VSLib");

::WC_GL_ReserveMax <- 10;
::WC_GL_Class <- "weapon_grenade_launcher";
::WC_GL_Verbose <- false;

::WC_GL_Apply <- function ()
{
    Convars.SetValue("ammo_grenadelauncher_max", ::WC_GL_ReserveMax);
}

::WC_GL_GetPrimary <- function (player)
{
    if (player == null || !player.IsPlayerEntityValid()) return null;

    local t = player.GetHeldItems();
    if (t == null || !("slot0" in t)) return null;

    return t["slot0"];
}

::VSLib.EasyLogic.Notifications.OnAmmoCantUse.WC_GL <- function (player, params)
{
    if (player == null || !player.IsPlayerEntityValid()) return;
    if (player.GetTeam() != SURVIVORS) return;

    local wep = ::WC_GL_GetPrimary(player);
    if (wep == null || !wep.IsEntityValid()) return;
    if (wep.GetClassname() != ::WC_GL_Class) return;

    wep.SetAmmo(::WC_GL_ReserveMax);

    if (::WC_GL_Verbose && !player.IsBot())
    {
        player.Print("[GL] Đã tiếp đạn từ đống đạn: dự trữ = " + ::WC_GL_ReserveMax, HUD_PRINTTALK);
    }
};

::VSLib.EasyLogic.Notifications.OnRoundStart.WC_GL_Apply <- function ()
{
    ::WC_GL_Apply();
};

::WC_GL_Apply();
