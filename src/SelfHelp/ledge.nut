::SH_LedgeSuccessChance <- 0.5;

::SH_RegisterCase("ledge",
{
    keepMedkit = true

    function matches(player)
    {
        return player.IsHangingFromLedge();
    }

    function duration(player)
    {
        return ::SH_GetDifficultyDuration();
    }

    function roll(player)
    {
        return RandomFloat(0.0, 1.0) < ::SH_LedgeSuccessChance;
    }

    function onStart(player)
    {
        ::LF_Begin(player);
    }

    function onCancel(player, bCompleted)
    {
        if (!bCompleted && player.IsHangingFromLedge())
        {
            ::LF_End(player);
        }
    }

    function revive(player)
    {
        ::SH_Log("ledge revive before: " + ::SH_State(player));
        player.GetBaseEntity().ReviveFromIncap();
        ::SH_Log("ledge revive after: " + ::SH_State(player));

        if (!player.IsHangingFromLedge()) return true;

        ::LF_End(player);
        return false;
    }
});
