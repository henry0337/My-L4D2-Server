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
        local pills = ::SH_GetPills(player);

        if (!player.Revive()) return false;
        if (pills == null) return true;

        ::SH_ApplyBoost(player, pills.GetClassname());
        pills.Kill();
        return true;
    }
});
