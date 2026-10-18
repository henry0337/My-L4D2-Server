IncludeScript("src/Shared/shared");

if (!("WeaponCustomizer" in getroottable()))
{
    ::WeaponCustomizer <-
    {
        IsDisabled = function ()
        {
            return ::Shared.Mode.IsCompetitive() || ::Shared.Mode.IsTankRun();
        },

        ApplyConvar = function (name, customValue, defaultValue)
        {
            if (!::WeaponCustomizer.IsDisabled())
            {
                Convars.SetValue(name, customValue);
                return;
            }

            if (Convars.GetFloat(name) == customValue)
            {
                Convars.SetValue(name, defaultValue);
            }
        }
    };
}
