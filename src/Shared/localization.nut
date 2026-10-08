::Shared.Localization <-
{
    Register = function (locale, strings)
    {
        foreach (key, variants in strings)
        {
            locale.strings[key] <- variants;
        }
    },

    Resolve = function (locale, messageKey, clientLanguage, substitutions = null)
    {
        if (!(messageKey in locale.strings)) return messageKey;

        local fallback = locale.fallback;
        local code = (clientLanguage in locale.languages) ? locale.languages[clientLanguage] : fallback;

        local variants = locale.strings[messageKey];
        local text = messageKey;
        if (code in variants)
        {
            text = variants[code];
        }
        else if (fallback in variants)
        {
            text = variants[fallback];
        }

        if (substitutions != null)
        {
            foreach (name, value in substitutions)
            {
                local replacement = (typeof value == "table")
                    ? ::Shared.Localization.Resolve(locale, value.key, clientLanguage)
                    : value.tostring();
                text = ::Shared.Strings.ReplaceLiteral(text, "{" + name + "}", replacement);
            }
        }

        return text;
    }
};
