IncludeScript("src/VSLib");

::AutoFire_IncludeBots <- false;

::AutoFire_Guns <-
{
    weapon_pistol           = true,
    weapon_pistol_magnum    = true,
    weapon_pumpshotgun      = true,
    weapon_shotgun_chrome   = true,
    weapon_autoshotgun      = true,
    weapon_shotgun_spas     = true,
    weapon_hunting_rifle    = true,
    weapon_sniper_military  = true,
    weapon_sniper_awp       = true,
    weapon_sniper_scout     = true,
    weapon_grenade_launcher = true,
};

::VSLib.EasyLogic.Notifications.OnWeaponFire.AutoFire <- function (player, weapon, params)
{
    if (!(weapon in ::AutoFire_Guns)) return;
    if (player == null || !player.IsEntityValid()) return; 
    if (player.GetTeam() != SURVIVORS) return;
    if (!::AutoFire_IncludeBots && player.IsBot()) return;

    local wep = player.GetActiveWeapon();
    if (wep == null || !wep.IsEntityValid()) return;

    wep.SetNetProp("m_isHoldingFireButton", 0);
};
