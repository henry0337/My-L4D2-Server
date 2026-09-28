IncludeScript("src/VSLib");

::SIClawFix_ClawButton <- 2048;
::SIClawFix_TickInterval <- 0.03;
::SIClawFix_GraceTime <- 0.5;
::SIClawFix_Verbose <- false;
::SIClawFix_State <- {};

::SIClawFix_IsStaggered <- function (player)
{
    return player.GetNetPropFloat("m_staggerTimer", 1) > -1.0;
}

::SIClawFix_Tick <- function (params)
{
    foreach (player in ::VSLib.EasyLogic.Players.InfectedBots())
    {
        if (player == null || !player.IsEntityValid()) continue;

        local iType = player.GetPlayerType();
        local iIndex = player.GetIndex();

        local bShouldDisable = !player.IsDead()
            && iType != Z_TANK
            && ( ::SIClawFix_IsStaggered(player) || ( !player.HasFlag(FL_ONGROUND) && (iType == Z_HUNTER || iType == Z_JOCKEY) ) );

        if (bShouldDisable)
        {
            if (!(iIndex in ::SIClawFix_State))
            {
                player.DisableButton(::SIClawFix_ClawButton);
            }
            ::SIClawFix_State[iIndex] <- null;
        }
        else if (iIndex in ::SIClawFix_State)
        {
            if (::SIClawFix_State[iIndex] == null)
            {
                ::SIClawFix_State[iIndex] = Time() + ::SIClawFix_GraceTime;
            }
            else if (Time() >= ::SIClawFix_State[iIndex])
            {
                player.EnableButton(::SIClawFix_ClawButton);
                delete ::SIClawFix_State[iIndex];
            }
        }
    }
}

::VSLib.EasyLogic.Notifications.OnRoundStart.SIClawFix <- function ()
{
    ::SIClawFix_State.clear();
};

::VSLib.Timers.AddTimerByName("SIClawFix_Tick", ::SIClawFix_TickInterval, true, ::SIClawFix_Tick);
