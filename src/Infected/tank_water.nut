IncludeScript("src/Shared/shared");

const TANK_WATER_POLL_SECONDS = 0.2;

if (!("TankWaterSlowdown" in getroottable()))
{
    ::TankWaterSlowdown <-
    {
        suppressed = false,

        IsTankOnField = function ()
        {
            foreach (tank in ::VSLib.EasyLogic.Players.OfType(Z_TANK))
            {
                if (!::Shared.Players.IsValid(tank) || tank.IsDead() || tank.IsGhost()) continue;
                return true;
            }
            return false;
        },

        SetSlowdown = function (enabled)
        {
            DirectorScript.GetDirectorOptions().WaterSlowsMovement <- enabled;

            local rules = ::VSLib.Entity("terror_gamerules");
            if (rules.IsEntityValid())
            {
                rules.SetNetProp("m_bWaterSlowdownEnabled", enabled ? 1 : 0);
            }
        },

        Poll = function (params)
        {
            local wanted = ::Shared.Mode.IsCompetitive() && ::TankWaterSlowdown.IsTankOnField();
            if (wanted == ::TankWaterSlowdown.suppressed) return;

            ::TankWaterSlowdown.suppressed = wanted;
            ::TankWaterSlowdown.SetSlowdown(!wanted);
        }
    };

    ::VSLib.Timers.AddTimerByName("TankWaterSlowdown_Poll", TANK_WATER_POLL_SECONDS, true, ::TankWaterSlowdown.Poll);

    ::VSLib.EasyLogic.Notifications.OnRoundStart.TankWaterSlowdown <- function ()
    {
        if (::TankWaterSlowdown.suppressed)
        {
            ::TankWaterSlowdown.suppressed = false;
            ::TankWaterSlowdown.SetSlowdown(true);
        }
    };
}
