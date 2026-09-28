IncludeScript("src/VSLib");

::SmokerShoveMelee <- {};
::SmokerShoveMelee.ATTACK2_BUTTON <- 2048;
::SmokerShoveMelee.SHOVE_RANGE <- 120.0;
::SmokerShoveMelee.SOUND_RANGE <- 115.0;
::SmokerShoveMelee.VIEW_TOLERANCE <- 50.0;
::SmokerShoveMelee.Verbose <- true;
::SmokerShoveMelee.State <- {};

::SmokerShoveMelee.GetRecord <- function (idx)
{
    if (!(idx in ::SmokerShoveMelee.State))
    {
        ::SmokerShoveMelee.State[idx] <- { choke = false, dummy = null };
    }
    return ::SmokerShoveMelee.State[idx];
};

::SmokerShoveMelee.StopThink <- function (idx)
{
    if (!(idx in ::SmokerShoveMelee.State)) return;

    local dummy = ::SmokerShoveMelee.State[idx].dummy;
    if (dummy != null && dummy.IsEntityValid())
    {
        dummy.Kill();
    }

    delete ::SmokerShoveMelee.State[idx];
};

::SmokerShoveMelee.ViewCheck <- function (surv, target)
{
    local startpos = surv.GetEyePosition();
    local target_pos = target.GetOrigin() + Vector(0, 0, 30);

    local targetNorm = Vector(target_pos.x - startpos.x,
                              target_pos.y - startpos.y,
                              target_pos.z - startpos.z);
    local len = targetNorm.Norm();
    if (len <= 0.0) return true;
    targetNorm.x = targetNorm.x / len;
    targetNorm.y = targetNorm.y / len;
    targetNorm.z = targetNorm.z / len;

    local viewerAng = surv.GetEyeAngles().Forward();
    local angle = 180.0 / PI * acos(viewerAng.Dot(targetNorm));
    return (angle < ::SmokerShoveMelee.VIEW_TOLERANCE);
};

::SmokerShoveMelee.RetryStagger <- function (params)
{
    local surv = params.surv;
    local smoker = params.smoker;

    if (surv == null || !surv.IsPlayerEntityValid()) return;
    if (smoker == null || !smoker.IsPlayerEntityValid()) return;

    local idx = surv.GetIndex();
    if (idx in ::SmokerShoveMelee.State && ::SmokerShoveMelee.State[idx].choke) return;
    if (surv.GetSequenceActivityName(surv.GetSequence()) == "ACT_TERROR_DRAGGING_FROM_TONGUE") return;
    if (::SmokerShoveMelee.ViewCheck(surv, smoker))
    {
        smoker.StaggerAwayFromLocation(surv.GetOrigin());
        surv.EmitSound("Weapon.HitInfected");
    }
};

::VSLib.EasyLogic.Notifications.OnSmokerChokeBegin.SmokerShoveMelee <- function (smoker, victim, params)
{
    if (victim == null || !victim.IsPlayerEntityValid()) return;
    if (victim.IsBot()) return;

    ::SmokerShoveMelee.GetRecord(victim.GetIndex()).choke = true;
};

::VSLib.EasyLogic.Notifications.OnSmokerTongueGrab.SmokerShoveMelee <- function (smoker, victim, params)
{
    if (victim == null || !victim.IsPlayerEntityValid()) return;
    if (smoker == null || !smoker.IsPlayerEntityValid()) return;
    if (victim.IsBot()) return;

    local idx = victim.GetIndex();
    local record = ::SmokerShoveMelee.GetRecord(idx);

    if (record.dummy != null && record.dummy.IsEntityValid()) return;
    record.choke = false;

    local dummy = ::VSLib.Utils.CreateEntity("logic_script");
    if (dummy == null) return;
    record.dummy = dummy;

    dummy.AddThinkFunction(function ()
    {
        if (victim == null || !victim.IsPlayerEntityValid())
        {
            ::SmokerShoveMelee.StopThink(idx);
            return -1;
        }

        if (victim.IsIncapacitated() || victim.IsHangingFromLedge() || victim.IsDying())
        {
            ::SmokerShoveMelee.StopThink(idx);
            return -1;
        }

        if (smoker == null || !smoker.IsPlayerEntityValid()
            || victim.GetNetPropEntity("m_tongueOwner") == null)
        {
            ::SmokerShoveMelee.StopThink(idx);
            return -1;
        }

        if (::SmokerShoveMelee.State[idx].choke)
        {
            ::SmokerShoveMelee.StopThink(idx);
            return -1;
        }

        if (victim.GetSequenceActivityName(victim.GetSequence()) == "ACT_TERROR_DRAGGING_FROM_TONGUE")
        {
            ::SmokerShoveMelee.StopThink(idx);
            return -1;
        }

        if ((victim.GetNetPropInt("m_afButtonPressed") & ::SmokerShoveMelee.ATTACK2_BUTTON) == 0) return -1;

        local weapon = victim.GetActiveWeapon();
        if (weapon == null || !weapon.IsEntityValid() || weapon.GetClassname() != "weapon_melee") return -1;

        local act = weapon.GetSequenceActivityName(weapon.GetSequence());
        if (act != "ACT_VM_IDLE" && act != "ACT_VM_IDLE_TO_LOWERED_IDLE") return -1;

        local time = Time();
        if (time < weapon.GetNetPropFloat("m_flNextSecondaryAttack")) return -1;

        local viewModel = victim.GetViewModel();

        local body_seq = victim.LookupSequence("ACT_SHOOT_SECONDARY_GUITAR");
        victim.SetNetPropInt("m_NetGestureSequence", body_seq, 6);
        victim.SetNetPropInt("m_NetGestureActivity", victim.LookupActivity("ACT_SHOOT_SECONDARY_GUITAR"), 6);
        victim.SetNetPropFloat("m_NetGestureStartTime", time, 6);

        local vm_seq = weapon.LookupSequence("ACT_VM_SECONDARYATTACK");
        weapon.SetNetPropInt("m_NetGestureSequence", vm_seq, 5);
        weapon.SetNetPropInt("m_NetGestureActivity", weapon.LookupActivity("ACT_VM_SECONDARYATTACK"), 5);
        weapon.SetNetPropFloat("m_NetGestureStartTime", 0, 5);

        if (viewModel != null && viewModel.IsEntityValid())
        {
            viewModel.SetNetPropInt("m_nLayerSequence", vm_seq);
            viewModel.SetNetPropInt("m_nLayer", 0);
            viewModel.SetNetPropFloat("m_flLayerStartTime", time);
        }

        weapon.SetNetPropFloat("m_helpingHandSuppressionTimer.m_duration", 1);
        weapon.SetNetPropFloat("m_helpingHandSuppressionTimer.m_timestamp", time + 1);
        weapon.SetNetPropInt("m_helpingHandState", 0);

        victim.EmitSound("Weapon.Swing");

        local surv_pos = victim.GetOrigin();
        local smoker_pos = smoker.GetOrigin();
        local dist = (smoker_pos - surv_pos).Length();

        if (dist <= ::SmokerShoveMelee.SHOVE_RANGE)
        {
            if (::SmokerShoveMelee.ViewCheck(victim, smoker))
            {
                smoker.StaggerAwayFromLocation(surv_pos);
                if (dist > ::SmokerShoveMelee.SOUND_RANGE)
                {
                    victim.EmitSound("Weapon.HitInfected");
                }
            }
            else
            {
                ::VSLib.Timers.AddTimer(0.1, false, ::SmokerShoveMelee.RetryStagger, { surv = victim, smoker = smoker });
            }
        }

        local interval = Convars.GetFloat("z_gun_swing_interval");
        if (interval < -1.0)
        {
            interval = -1.0;
        }
        return interval;
    });
};

::VSLib.EasyLogic.Notifications.OnRoundStart.SmokerShoveMelee <- function ()
{
    foreach (idx, record in ::SmokerShoveMelee.State)
    {
        if (record.dummy != null && record.dummy.IsEntityValid())
        {
            record.dummy.Kill();
        }
    }
    ::SmokerShoveMelee.State.clear();
};
