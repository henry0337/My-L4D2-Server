::Shared.Mode <-
{
    competitiveModes =
    {
        versus = true,
        scavenge = true,
        teamversus = true,
        teamscavenge = true
    },

    /**
     * Returns true when the base game mode is Versus or Scavenge.
     * Mutations resolve to their base mode, so Versus-based and Scavenge-based mutations are included.
     */
    IsCompetitive = function ()
    {
        return ::VSLib.Utils.GetBaseMode() in ::Shared.Mode.competitiveModes;
    },

    /**
     * Returns true when the running mutation is Tank Run.
     * Tank Run is a Coop-based mutation, so IsCompetitive() does not cover it.
     */
    IsTankRun = function ()
    {
        return Director.GetGameMode() == "tankrun";
    },

    /**
     * Returns true only for the original Campaign mode (game mode "coop").
     * Realism and every mutation, including Coop-based ones such as Tank Run, return false.
     */
    IsCampaign = function ()
    {
        return Director.GetGameMode() == "coop";
    },

    /**
     * Returns true for the original Campaign ("coop") and Realism modes only.
     * Every mutation, including Coop-based ones such as Tank Run, returns false.
     */
    IsCampaignOrRealism = function ()
    {
        local mode = Director.GetGameMode();
        return mode == "coop" || mode == "realism";
    }
};
