IncludeScript("src/WeaponCustomizer/special_ammo");

::WeaponGrenadeLauncher <- ::SpecialAmmo.Create(
{
    name = "GL",
    className = "weapon_grenade_launcher",
    clip = 1,
    reserveMax = 15,
    defaultReserveMax = 30,
    convar = "ammo_grenadelauncher_max",
    reloadSeconds = 2.0,
    verbose = false
});
