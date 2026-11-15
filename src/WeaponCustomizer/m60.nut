IncludeScript("src/WeaponCustomizer/special_ammo");

::WeaponM60 <- ::SpecialAmmo.Create(
{
    name = "M60",
    className = "weapon_rifle_m60",
    clip = 150,
    reserveMax = 150,
    defaultReserveMax = 0,
    convar = "ammo_m60_max",
    animationSeconds = 2.0,
    guardEmpty = true,
    verbose = true
});
