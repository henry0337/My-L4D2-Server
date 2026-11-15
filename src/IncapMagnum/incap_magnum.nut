IncludeScript("src/Shared/shared");

const INCAP_MAGNUM = "pistol_magnum";
const INCAP_MAGNUM_CLASS = "weapon_pistol_magnum";
const INCAP_PISTOL = "pistol";
const INCAP_PISTOL_CLASS = "weapon_pistol";
const INCAP_MELEE_CLASS = "weapon_melee";
const INCAP_SECONDARY_SLOT = "slot1";
const INCAP_APPLY_DELAY = 0.1;
const INCAP_POLL_SECONDS = 0.2;

::IncapMagnum <-
{
    saved = {},

    OnIncapacitated = function (player, attacker, params)
    {
        if (!::Shared.Mode.IsCampaign()) return;
        if (!::Shared.Players.IsValid(player) || player.GetTeam() != SURVIVORS) return;

        ::VSLib.Timers.AddTimer(INCAP_APPLY_DELAY, false, ::IncapMagnum.Apply, { player = player });
    },

    Apply = function (params)
    {
        local player = params.player;
        if (!::Shared.Players.IsValid(player)) return;
        if (!player.IsIncapacitated() || player.IsHangingFromLedge()) return;

        local userId = player.GetUserID();
        if (userId in ::IncapMagnum.saved) return;

        local weapon = player.GetActiveWeapon();
        if (weapon == null || !weapon.IsEntityValid() || weapon.GetClassname() != INCAP_PISTOL_CLASS) return;

        local record = { dual = weapon.GetNetPropBool("m_hasDualWeapons"), clip = weapon.GetClip(), melee = null };

        local items = player.GetHeldItems();
        if (items != null)
        {
            foreach (item in items)
            {
                if (item.GetClassname() == INCAP_MELEE_CLASS)
                {
                    record.melee = item.GetNetPropString("m_strMapSetScriptName");
                }
            }
        }

        ::IncapMagnum.saved[userId] <- record;

        weapon.Kill();
        player.Give(INCAP_MAGNUM);
        player.SwitchTo(INCAP_MAGNUM_CLASS);
    },

    Restore = function (player, record)
    {
        player.Remove(INCAP_MAGNUM_CLASS);

        if (record.melee != null && record.melee != "")
        {
            player.Give(record.melee);
            return;
        }

        player.Give(INCAP_PISTOL);
        if (record.dual)
        {
            player.Give(INCAP_PISTOL);
        }

        local weapon = ::Shared.Players.GetHeldItemOfClass(player, INCAP_SECONDARY_SLOT, INCAP_PISTOL_CLASS);
        if (weapon != null)
        {
            weapon.SetClip(record.clip);
        }
    },

    Poll = function (params)
    {
        foreach (userId, record in clone ::IncapMagnum.saved)
        {
            local player = ::Shared.Players.GetByUserId(userId);

            if (player != null && player.IsAlive() && player.IsIncapacitated()) continue;

            delete ::IncapMagnum.saved[userId];

            if (player != null && player.IsAlive())
            {
                ::IncapMagnum.Restore(player, record);
            }
        }
    }
};

::VSLib.EasyLogic.Notifications.OnIncapacitated.IncapMagnum <- function (player, attacker, params)
{
    ::IncapMagnum.OnIncapacitated(player, attacker, params);
};

::VSLib.EasyLogic.Notifications.OnRoundStart.IncapMagnum <- function ()
{
    ::IncapMagnum.saved.clear();
};

::VSLib.Timers.AddTimerByName("IncapMagnum_Poll", INCAP_POLL_SECONDS, true, ::IncapMagnum.Poll);
