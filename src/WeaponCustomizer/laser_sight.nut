IncludeScript("src/Shared/shared");

const WEAPON_LASER_SIGHT_BIT = 4;
const WEAPON_LASER_SIGHT_POLL_SECONDS = 0.2;

if (!("WeaponLaserSight" in getroottable()))
{
    ::WeaponLaserSight <-
    {
        Apply = function (player)
        {
            local weapon = ::Shared.Players.GetPrimary(player);
            if (weapon == null) return;

            if (!weapon.HasUpgrade(WEAPON_LASER_SIGHT_BIT))
            {
                weapon.AddUpgrade(WEAPON_LASER_SIGHT_BIT);
            }
        },

        IsEnabled = function ()
        {
            return ::Shared.Mode.IsCompetitive() || ::Shared.Mode.IsTankRun();
        },

        Poll = function (params)
        {
            if (!::WeaponLaserSight.IsEnabled()) return;

            foreach (player in ::VSLib.EasyLogic.Players.AllSurvivors())
            {
                ::WeaponLaserSight.Apply(player);
            }
        }
    };

    ::VSLib.Timers.AddTimerByName("WeaponLaserSight_Poll", WEAPON_LASER_SIGHT_POLL_SECONDS, true, ::WeaponLaserSight.Poll);
}
