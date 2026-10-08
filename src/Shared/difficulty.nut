::Shared.Difficulty <-
{
    Pick = function (valuesByDifficulty, defaultValue)
    {
        local difficulty = ::VSLib.Utils.GetDifficulty();
        return (difficulty in valuesByDifficulty) ? valuesByDifficulty[difficulty] : defaultValue;
    }
};
