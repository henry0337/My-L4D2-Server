IncludeScript("src/Notifiers/Witch/localization");
::NTF_RegisterStrings(::WN_Strings);

::WN_WarnSound <- "ui/pickup_secret01.wav";
::WN_TrackIntervalSec <- 0.1;
::WN_DefaultWitchHealth <- 1000;
::WN_WanderSpeedThreshold <- 10.0;
::WN_BrideModel <- "models/infected/witch_bride.mdl";

::WN_CrownWeapons <-
{
    weapon_pumpshotgun = true,
    weapon_shotgun_chrome = true,
    weapon_autoshotgun = true,
    weapon_shotgun_spas = true,
    weapon_pistol = true,
    weapon_pistol_magnum = true,
    weapon_melee = true,
    weapon_chainsaw = true,
};

::WN_DamageMap <- {};
::WN_LastHealth <- {};
::WN_MaxHealth <- {};
::WN_Wandering <- {};
::WN_Startled <- {};

::WN_GetDefaultWitchHealth <- function ()
{
    local health = Convars.GetFloat("z_witch_health");
    return (health != null && health > 0) ? health.tointeger() : ::WN_DefaultWitchHealth;
}

::WN_AllMaps <- function ()
{
    return [::WN_DamageMap, ::WN_LastHealth, ::WN_MaxHealth, ::WN_Wandering, ::WN_Startled];
}

::WN_GetVariantName <- function (witchIdx, bBride = null)
{
    if (bBride == null)
    {
        local witch = ::VSLib.Entity(witchIdx);
        bBride = witch.IsEntityValid() && witch.GetModel() == ::WN_BrideModel;
    }

    if (bBride) return { key = "witch_name_bride" };
    if (witchIdx in ::WN_Wandering) return { key = "witch_name_wandering" };
    return { key = "witch_name_normal" };
}

::WN_TrackWitches <- function (params)
{
    local tAlive = {};
    foreach (witch in ::VSLib.EasyLogic.Objects.OfClassname("witch"))
    {
        if (!witch.IsAlive()) continue;

        local health = witch.GetRawHealth();
        if (health <= 0) continue;

        local witchIdx = witch.GetIndex();
        tAlive[witchIdx] <- true;
        ::WN_LastHealth[witchIdx] <- health;

        if (!(witchIdx in ::WN_Startled) && witch.GetVelocity().Length() > ::WN_WanderSpeedThreshold)
        {
            ::WN_Wandering[witchIdx] <- true;
        }
    }

    foreach (witchIdx, health in clone ::WN_LastHealth)
    {
        if (!(witchIdx in tAlive))
        {
            ::NTF_Forget(::WN_AllMaps(), witchIdx);
        }
    }
}

::WN_ConsumeHealthDelta <- function (witch, params)
{
    local witchIdx = witch.GetIndex();

    local newHealth = witch.GetRawHealth();
    if (newHealth < 0)
    {
        newHealth = 0;
    }

    if (!(witchIdx in ::WN_LastHealth))
    {
        ::WN_LastHealth[witchIdx] <- newHealth + params.amount;
    }

    local prevHealth = ::WN_LastHealth[witchIdx];
    ::WN_LastHealth[witchIdx] = newHealth;

    return prevHealth - newHealth;
}

::WN_GetKillKeyBase <- function (killer, params)
{
    if (killer == null) return "witch_killed";

    local weapon = killer.GetActiveWeapon();
    local sWeapon = (weapon != null) ? weapon.GetClassname() : "";

    if (("oneshot" in params) && params.oneshot && (sWeapon in ::WN_CrownWeapons))
    {
        return "witch_crowned";
    }

    if (("melee_only" in params) && params.melee_only)
    {
        return "witch_melee_only";
    }

    return "witch_killed";
}

WitchEventNotifier <-
{
    function OnGameEvent_witch_spawn(params)
    {
        if (!("witchid" in params)) return;

        ::NTF_PlayWarnSound(::WN_WarnSound);

        ::WN_MaxHealth[params.witchid] <- ::WN_GetDefaultWitchHealth();

        ::NTF_BroadcastInline("tag_system", { key = "witch_spawned", subs = { WITCH = ::WN_GetVariantName(params.witchid) } });
    }

    function OnGameEvent_witch_harasser_set(params)
    {
        if ("witchid" in params)
        {
            ::WN_Startled[params.witchid] <- true;
        }
    }

    function OnGameEvent_infected_hurt(params)
    {
        if (!("entityid" in params) || !("amount" in params)) return;

        local witch = ::VSLib.Entity(params.entityid);
        if (!witch.IsEntityValid() || witch.GetClassname() != "witch") return;

        local damage = ::WN_ConsumeHealthDelta(witch, params);
        if (damage <= 0) return;
        if (::NTF_GetPlayer(params.attacker) == null) return;

        ::NTF_AddDamage(::WN_DamageMap, witch.GetIndex(), params.attacker, damage);
    }

    function OnGameEvent_witch_killed(params)
    {
        if (!("witchid" in params)) return;

        local witchIdx = params.witchid;
        local killer = ::NTF_GetPlayer(("userid" in params) ? params.userid : 0);

        local bBride = (("bride" in params) && params.bride) ? true : null;
        local tWitchName = ::WN_GetVariantName(witchIdx, bBride);

        local sKeyBase = ::WN_GetKillKeyBase(killer, params);
        local tIntroLines = ::NTF_BuildKillIntro(killer, sKeyBase, { WITCH = tWitchName });

        local tStatLines = null;
        if (sKeyBase != "witch_crowned")
        {
            local maxHealth = (witchIdx in ::WN_MaxHealth) ? ::WN_MaxHealth[witchIdx] : ::WN_GetDefaultWitchHealth();
            tStatLines = ::NTF_BuildStatLines(::WN_DamageMap, witchIdx, maxHealth);
        }

        ::NTF_Forget(::WN_AllMaps(), witchIdx);
        ::NTF_Broadcast("tag_announcer", tIntroLines, tStatLines);
    }
};

__CollectEventCallbacks(WitchEventNotifier, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);

::VSLib.EasyLogic.Notifications.OnRoundStart.WN_Reset <- function ()
{
    foreach (tMap in ::WN_AllMaps())
    {
        tMap.clear();
    }
};

::VSLib.Timers.AddTimerByName("WN_TrackWitches", ::WN_TrackIntervalSec, true, ::WN_TrackWitches);
