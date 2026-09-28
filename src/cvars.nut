IncludeScript("src/VSLib");

::UserCvars <-
{
    survivor_allow_crawling = 1,
    survivor_crawl_speed = 60,
    sv_consistency = 0
};

::UserCvars_Verbose <- false;

::UserCvars_Apply <- function ()
{
    foreach (sName, val in ::UserCvars)
    {
        Convars.SetValue(sName, val);

        if (::UserCvars_Verbose)
        {
            local host = ::VSLib.Utils.GetHostPlayer();
            if (host == null || !host.IsPlayerEntityValid()) return;

            host.Print("[ConVars] Thuộc tính " + sName + " đã được thay đổi thành " + val + ".", HUD_PRINTCONSOLE);
        }
    }
}

::VSLib.EasyLogic.Notifications.OnRoundStart.UserCvarsApply <- function ()
{
    ::UserCvars_Apply();
};

::UserCvars_Apply();
