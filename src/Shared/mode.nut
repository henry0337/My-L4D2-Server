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
    }
};
