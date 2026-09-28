IncludeScript("src/Notifiers/Tank/localization");
::NTF_RegisterStrings(::TN_Strings);

::TN_WarnSound <- "ui/pickup_secret01.wav";

::TN_TrackIntervalSec <- 0.1;

::TN_DamageMap <- {};
::TN_LastHealth <- {};
::TN_MaxHealth <- {};

::TN_DifficultyTankHealth <-
{
    easy = 3000,
    normal = 4000,
    hard = 8000,
    impossible = 8000
};

::TN_GetRawHealth <- function (player)
{
    return player.GetBaseEntity().GetHealth();
}

::TN_GetDefaultTankHealth <- function ()
{
    local sMode = ::VSLib.Utils.GetBaseMode();
    if (sMode == "versus" || sMode == "scavenge") return 6000;
    if (sMode == "survival") return 4000;

    local sDiff = ::VSLib.Utils.GetDifficulty();
    return (sDiff in ::TN_DifficultyTankHealth) ? ::TN_DifficultyTankHealth[sDiff] : 4000;
}

::TN_TrackTanks <- function (params)
{
    foreach (tank in ::VSLib.EasyLogic.Players.OfType(Z_TANK))
    {
        if (!::NTF_IsValidPlayer(tank) || tank.IsDead() || tank.IsIncapacitated()) continue;

        local health = ::TN_GetRawHealth(tank);
        if (health <= 0) continue;

        ::TN_LastHealth[tank.GetIndex()] <- health;
    }
}

::TN_ConsumeHealthDelta <- function (tank, params)
{
    local tankIdx = tank.GetIndex();

    local newHealth = ::TN_GetRawHealth(tank);
    if (newHealth < 0)
    {
        newHealth = 0;
    }

    if (!(tankIdx in ::TN_LastHealth))
    {
        ::TN_LastHealth[tankIdx] <- newHealth + params.dmg_health;
    }

    local prevHealth = ::TN_LastHealth[tankIdx];
    ::TN_LastHealth[tankIdx] = newHealth;

    return prevHealth - newHealth;
}

TankEventNotifier <-
{
    function OnGameEvent_tank_spawn(params)
    {
        ::NTF_PlayWarnSound(::TN_WarnSound);

        local tank = ::NTF_GetPlayer(params.userid);
        if (tank != null)
            ::TN_MaxHealth[tank.GetIndex()] <- tank.GetMaxHealth();

        ::NTF_BroadcastInline("tag_system", { key = "tank_spawned", subs = null });
    }

    function OnGameEvent_player_hurt(params)
    {
        local tank = ::NTF_GetPlayer(params.userid);
        if (tank == null || tank.GetPlayerType() != Z_TANK) return;

        local damage = ::TN_ConsumeHealthDelta(tank, params);
        if (damage <= 0 || tank.IsIncapacitated()) return;
        if (::NTF_GetPlayer(params.attacker) == null) return;

        ::NTF_AddDamage(::TN_DamageMap, tank.GetIndex(), params.attacker, damage);
    }

    function OnGameEvent_tank_killed(params)
    {
        local tank = ::NTF_GetPlayer(params.userid);
        local tIntroLines = ::NTF_BuildKillIntro(::NTF_GetPlayer(params.attacker), "tank_killed");

        if (tank == null)
        {
            ::NTF_Broadcast("tag_announcer", tIntroLines);
            return;
        }

        local tankIdx = tank.GetIndex();
        local maxHealth = (tankIdx in ::TN_MaxHealth) ? ::TN_MaxHealth[tankIdx] : ::TN_GetDefaultTankHealth();
        local tStatLines = ::NTF_BuildStatLines(::TN_DamageMap, tankIdx, maxHealth);

        ::NTF_Forget([::TN_DamageMap, ::TN_LastHealth, ::TN_MaxHealth], tankIdx);
        ::NTF_Broadcast("tag_announcer", tIntroLines, tStatLines);
    }
};

__CollectEventCallbacks(TankEventNotifier, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);

::VSLib.EasyLogic.Notifications.OnRoundStart.TN_Reset <- function ()
{
    ::TN_DamageMap.clear();
    ::TN_LastHealth.clear();
    ::TN_MaxHealth.clear();
};

::VSLib.Timers.AddTimerByName("TN_TrackTanks", ::TN_TrackIntervalSec, true, ::TN_TrackTanks);
