::Shared.Convar <-
{
    GetPositiveFloat = function (name, defaultValue)
    {
        local value = Convars.GetFloat(name);
        return (value != null && value > 0) ? value : defaultValue;
    },

    GetPositiveInt = function (name, defaultValue)
    {
        local value = Convars.GetFloat(name);
        return (value != null && value > 0) ? value.tointeger() : defaultValue;
    }
};
