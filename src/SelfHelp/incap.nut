::SH_RegisterCase("incap",
{
    function matches(player)
    {
        return player.IsIncapacitated() && !player.IsHangingFromLedge();
    }

    function duration(player)
    {
        return ::SH_GetDifficultyDuration();
    }

    function revive(player)
    {
        return player.Revive();
    }
});
