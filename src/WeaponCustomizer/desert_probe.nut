IncludeScript("src/Shared/shared");

const DESERT_PROBE_CLASS = "weapon_rifle_desert";
const DESERT_PROBE_FULL_CLIP = 60;
const DESERT_PROBE_HOLD_SECONDS = 0.6;
const DESERT_PROBE_POLL_SECONDS = 0.05;
const DESERT_PROBE_BURST_GAP = 0.3;

::DesertProbe <-
{
    mode = 0,
    cycle = 0.075,
    lastFire = {},
    holdStart = {},
    holdReported = {},
    reloadSeen = {},

    candidateProps =
    [
        "m_isHoldingFireButton",
        "m_releasedFireButton",
        "m_flNextPrimaryAttack",
        "m_flNextSecondaryAttack",
        "m_flTimeWeaponIdle",
        "m_iClip1",
        "m_bInReload",
        "m_reloadState",
        "m_reloadNumShells",
        "m_burstCount",
        "m_nBurstCount",
        "m_iBurstCount",
        "m_burstShotsLeft",
        "m_bBurstFire",
        "m_fireMode",
        "m_iFireMode",
        "m_nFireMode",
        "m_bIsBurst",
        "m_burstTimer",
        "m_flBurstEndTime",
        "m_nShotsFired",
        "m_iShotsFired",
        "m_iState"
    ],

    Log = function (text)
    {
        ::Shared.Chat.Log("[DesertProbe] " + text);
    },

    DescribeProps = function (weapon)
    {
        local text = "";
        local missing = 0;
        foreach (name in ::DesertProbe.candidateProps)
        {
            if (!weapon.HasNetProp(name))
            {
                missing++;
                continue;
            }

            local value = weapon.GetNetProp(name);
            text += name + "=" + ((value == null) ? "null" : value.tostring()) + " ";
        }
        return text + "(missing " + missing + ")";
    },

    GetDesertRifle = function (player)
    {
        local weapon = player.GetActiveWeapon();
        if (weapon == null || !weapon.IsEntityValid()) return null;
        return (weapon.GetClassname() == DESERT_PROBE_CLASS) ? weapon : null;
    },

    OnFire = function (player, weaponName, params)
    {
        if (weaponName != DESERT_PROBE_CLASS) return;
        if (!::Shared.Players.IsValid(player) || player.IsBot()) return;

        local weapon = ::DesertProbe.GetDesertRifle(player);
        if (weapon == null) return;

        local userId = player.GetUserID();
        local now = Time();
        local delta = (userId in ::DesertProbe.lastFire) ? now - ::DesertProbe.lastFire[userId] : 0.0;
        ::DesertProbe.lastFire[userId] <- now;

        local remaining = weapon.GetNetPropFloat("m_flNextPrimaryAttack") - now;
        local line = "fire dt=" + format("%.3f", delta)
            + " next=+" + format("%.3f", remaining)
            + " clip=" + weapon.GetClip()
            + " mode=" + ::DesertProbe.mode;

        if (delta == 0.0 || delta > DESERT_PROBE_BURST_GAP)
        {
            line += " | " + ::DesertProbe.DescribeProps(weapon);
        }
        ::DesertProbe.Log(line);

        if (::DesertProbe.mode >= 1)
        {
            weapon.SetNetProp("m_isHoldingFireButton", 0);
        }
        if (::DesertProbe.mode >= 2)
        {
            ::VSLib.Timers.AddTimer(0.01, false, ::DesertProbe.ApplyDeferred, { weapon = weapon, fireTime = now });
        }
    },

    ApplyDeferred = function (params)
    {
        local weapon = params.weapon;
        if (weapon == null || !weapon.IsEntityValid()) return;

        local now = Time();
        local current = weapon.GetNetPropFloat("m_flNextPrimaryAttack");
        local target = params.fireTime + ::DesertProbe.cycle;

        local line = "deferred after=" + format("%.3f", now - params.fireTime)
            + " gameNext=+" + format("%.3f", current - params.fireTime)
            + " target=+" + format("%.3f", target - params.fireTime);

        if (current > target)
        {
            weapon.SetNetProp("m_flNextPrimaryAttack", target);
            line += " SHORTENED";
        }
        ::DesertProbe.Log(line);
    },

    OnReload = function (player, manual, params)
    {
        if (!::Shared.Players.IsValid(player) || player.IsBot()) return;

        local weapon = ::DesertProbe.GetDesertRifle(player);
        if (weapon == null) return;

        ::DesertProbe.reloadSeen[player.GetUserID()] <- true;
        ::DesertProbe.Log("reload event manual=" + manual + " clip=" + weapon.GetClip());
    },

    Poll = function (params)
    {
        local now = Time();
        foreach (player in ::VSLib.EasyLogic.Players.AllSurvivors())
        {
            if (!::Shared.Players.IsValid(player) || player.IsBot()) continue;

            local userId = player.GetUserID();
            local weapon = ::DesertProbe.GetDesertRifle(player);
            local pressing = weapon != null && player.IsPressingReload();

            if (pressing)
            {
                if (!(userId in ::DesertProbe.holdStart))
                {
                    ::DesertProbe.holdStart[userId] <- now;
                    ::DesertProbe.holdReported[userId] <- false;
                    ::DesertProbe.reloadSeen[userId] <- false;
                    ::DesertProbe.Log("R down clip=" + weapon.GetClip());
                }
                else if (!::DesertProbe.holdReported[userId] && now - ::DesertProbe.holdStart[userId] >= DESERT_PROBE_HOLD_SECONDS)
                {
                    ::DesertProbe.holdReported[userId] <- true;
                    ::DesertProbe.Log("R held " + DESERT_PROBE_HOLD_SECONDS + "s TOGGLE_CANDIDATE clip=" + weapon.GetClip()
                        + " full=" + (weapon.GetClip() >= DESERT_PROBE_FULL_CLIP)
                        + " reloadSeen=" + ::DesertProbe.reloadSeen[userId]);
                }
            }
            else if (userId in ::DesertProbe.holdStart)
            {
                ::DesertProbe.Log("R up after " + format("%.2f", now - ::DesertProbe.holdStart[userId])
                    + "s reloadSeen=" + ::DesertProbe.reloadSeen[userId]);
                delete ::DesertProbe.holdStart[userId];
                delete ::DesertProbe.holdReported[userId];
            }
        }
    },

    SetMode = function (value)
    {
        ::DesertProbe.mode = value;
        ::DesertProbe.Log("mode=" + value + " (0 quan sat, 1 + m_isHoldingFireButton=0, 2 + m_flNextPrimaryAttack)");
    },

    SetCycle = function (value)
    {
        ::DesertProbe.cycle = value;
        ::DesertProbe.Log("cycle=" + value);
    },

    OnSay = function (player, text, params)
    {
        ::DesertProbe.Log("say type=" + typeof player + " text=" + text);

        local tokens = split(text, " ");
        if (tokens.len() < 2) return;

        local command = tokens[0].tolower();
        if (command == "!dp")
        {
            ::DesertProbe.SetMode(tokens[1].tointeger());
        }
        else if (command == "!dpc")
        {
            ::DesertProbe.SetCycle(tokens[1].tofloat());
        }
    },

    OnModeTrigger = function (player, args, text)
    {
        ::DesertProbe.Log("trigger dp text=" + text);
        if (0 in args) ::DesertProbe.SetMode(args[0].tointeger());
    },

    OnCycleTrigger = function (player, args, text)
    {
        ::DesertProbe.Log("trigger dpc text=" + text);
        if (0 in args) ::DesertProbe.SetCycle(args[0].tofloat());
    }
};

::VSLib.EasyLogic.Notifications.OnWeaponFire.DesertProbe <- ::DesertProbe.OnFire;
::VSLib.EasyLogic.Notifications.OnWeaponReload.DesertProbe <- ::DesertProbe.OnReload;
::VSLib.EasyLogic.Notifications.OnSay.DesertProbe <- ::DesertProbe.OnSay;
::VSLib.EasyLogic.AddChatTrigger("dp", ::DesertProbe.OnModeTrigger);
::VSLib.EasyLogic.AddChatTrigger("dpc", ::DesertProbe.OnCycleTrigger);

::VSLib.Timers.AddTimerByName("DesertProbe_Poll", DESERT_PROBE_POLL_SECONDS, true, ::DesertProbe.Poll);
