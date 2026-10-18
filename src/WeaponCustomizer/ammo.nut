IncludeScript("src/Shared/shared");
IncludeScript("src/WeaponCustomizer/guard");

const WEAPON_AMMO_MULTIPLIER = 2;
const WEAPON_AMMO_RESERVE_LIMIT = 1000;
const WEAPON_AMMO_POLL_SECONDS = 0.2;

if (!("WeaponAmmo" in getroottable()))
{
    ::WeaponAmmo <-
    {
        types =
        {
            smg = { convar = "ammo_smg_max", defaultReserve = 650 },
            assaultrifle = { convar = "ammo_assaultrifle_max", defaultReserve = 360 },
            shotgun = { convar = "ammo_shotgun_max", defaultReserve = 72 },
            autoshotgun = { convar = "ammo_autoshotgun_max", defaultReserve = 90 },
            huntingrifle = { convar = "ammo_huntingrifle_max", defaultReserve = 150 },
            sniperrifle = { convar = "ammo_sniperrifle_max", defaultReserve = 180 }
        },
        entries = {},
        granted = {},

        Scale = function (defaultReserve)
        {
            local scaled = defaultReserve * WEAPON_AMMO_MULTIPLIER;
            return (scaled > WEAPON_AMMO_RESERVE_LIMIT) ? WEAPON_AMMO_RESERVE_LIMIT : scaled;
        },

        Register = function (className, typeName, reserve = null)
        {
            local ammoType = ::WeaponAmmo.types[typeName];
            local standard = ::WeaponAmmo.Scale(ammoType.defaultReserve);
            ::WeaponAmmo.entries[className] <-
            {
                convar = ammoType.convar,
                defaultReserve = ammoType.defaultReserve,
                standard = standard,
                reserve = (reserve != null) ? reserve : standard
            };
            ::WeaponAmmo.ApplyConvars();
        },

        ApplyConvars = function ()
        {
            foreach (entry in ::WeaponAmmo.entries)
            {
                ::WeaponCustomizer.ApplyConvar(entry.convar, entry.standard, entry.defaultReserve);
            }
        },

        TopUp = function (player)
        {
            if (::WeaponCustomizer.IsDisabled()) return;
            if (!::Shared.Players.IsValid(player) || player.GetTeam() != SURVIVORS) return;

            local weapon = ::Shared.Players.GetPrimary(player);
            if (weapon == null) return;

            local className = weapon.GetClassname();
            if (!(className in ::WeaponAmmo.entries)) return;

            local entry = ::WeaponAmmo.entries[className];
            if (entry.reserve > entry.standard)
            {
                weapon.SetAmmo(entry.reserve);
            }
        },

        Grant = function (player)
        {
            if (!::Shared.Players.IsValid(player) || player.GetTeam() != SURVIVORS) return;

            local weapon = ::Shared.Players.GetPrimary(player);
            if (weapon == null) return;

            local className = weapon.GetClassname();
            if (!(className in ::WeaponAmmo.entries)) return;

            local index = weapon.GetIndex();
            if (index in ::WeaponAmmo.granted) return;
            ::WeaponAmmo.granted[index] <- true;

            local entry = ::WeaponAmmo.entries[className];
            if (weapon.GetAmmo() != entry.standard) return;
            weapon.SetAmmo(entry.reserve);
        },

        Poll = function (params)
        {
            if (::WeaponCustomizer.IsDisabled()) return;

            foreach (player in ::VSLib.EasyLogic.Players.AllSurvivors())
            {
                ::WeaponAmmo.Grant(player);
            }
        }
    };

    ::VSLib.Timers.AddTimerByName("WeaponAmmo_Poll", WEAPON_AMMO_POLL_SECONDS, true, ::WeaponAmmo.Poll);

    ::VSLib.EasyLogic.Notifications.OnAmmoCantUse.WeaponAmmo <- function (player, params)
    {
        ::WeaponAmmo.TopUp(player);
    };

    ::VSLib.EasyLogic.Notifications.OnRoundStart.WeaponAmmo <- function ()
    {
        ::WeaponAmmo.granted.clear();
        ::WeaponAmmo.ApplyConvars();
    };
}
