IncludeScript("src/VSLib");

if (!("Shared" in getroottable()))
{
    ::Shared <- {};

    IncludeScript("src/Shared/constants");
    IncludeScript("src/Shared/strings");
    IncludeScript("src/Shared/convar");
    IncludeScript("src/Shared/mode");
    IncludeScript("src/Shared/players");
    IncludeScript("src/Shared/difficulty");
    IncludeScript("src/Shared/localization");
    IncludeScript("src/Shared/chat");
}
