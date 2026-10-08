::Shared.Strings <-
{
    ReplaceLiteral = function (text, needle, replacement)
    {
        if (needle.len() == 0) return text;

        local result = "";
        local start = 0;
        local position;
        while ((position = text.find(needle, start)) != null)
        {
            result += text.slice(start, position) + replacement;
            start = position + needle.len();
        }
        return result + text.slice(start);
    },

    FormatPercent = function (value)
    {
        local text = format("%.1f", value);
        return (text.slice(-2) == ".0") ? text.slice(0, -2) : text;
    }
};
