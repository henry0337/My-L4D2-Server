IncludeScript("src/Shared/shared");

::LF_DefaultGrabHealth <- 300;
::LF_State <- {};

::LF_GetGrabHealth <- function ()
{
    return ::Shared.Convar.GetPositiveInt("survivor_ledge_grab_health", ::LF_DefaultGrabHealth);
}

::LF_Entry <- function (userId)
{
    if (!(userId in ::LF_State))
    {
        ::LF_State[userId] <- { hang = ::LF_GetGrabHealth(), savior = null };
    }
    return ::LF_State[userId];
}

::LF_Begin <- function (player, saviorUserId = null)
{
    local tEntry = ::LF_Entry(player.GetUserID());
    tEntry.hang = player.GetRawHealth();
    tEntry.savior = saviorUserId;
    player.SetRawHealth(::LF_GetGrabHealth());
}

::LF_End <- function (player)
{
    local tEntry = ::LF_Entry(player.GetUserID());
    tEntry.savior = null;
    player.SetRawHealth(tEntry.hang);
}

::LF_Done <- function (userId)
{
    if (userId in ::LF_State)
    {
        ::LF_State[userId].savior = null;
    }
}

LedgeFixEvents <-
{
    function OnGameEvent_player_ledge_grab(params)
    {
        if (!("userid" in params)) return;
        ::LF_State[params.userid] <- { hang = ::LF_GetGrabHealth(), savior = null };
    }

    function OnGameEvent_revive_begin(params)
    {
        if (!("userid" in params) || !("subject" in params)) return;

        local hanged = ::Shared.Players.GetByUserId(params.subject);
        if (hanged == null || !hanged.IsHangingFromLedge()) return;

        ::LF_Begin(hanged, params.userid);
    }

    function OnGameEvent_revive_end(params)
    {
        if (!("subject" in params) || !("ledge_hang" in params)) return;

        local hanged = ::Shared.Players.GetByUserId(params.subject);
        if (hanged == null || !hanged.IsHangingFromLedge()) return;

        ::LF_End(hanged);
    }

    function OnGameEvent_revive_success(params)
    {
        if (!("subject" in params) || !("ledge_hang" in params) || !params.ledge_hang) return;

        ::LF_Done(params.subject);
    }

    function OnGameEvent_player_hurt(params)
    {
        if (!("userid" in params) || !("dmg_health" in params)) return;

        local hurt = ::Shared.Players.GetByUserId(params.userid);
        if (hurt == null || !hurt.IsHangingFromLedge()) return;

        local tEntry = ::LF_Entry(params.userid);
        hurt.SetRawHealth(tEntry.hang - params.dmg_health);
        tEntry.hang = hurt.GetRawHealth();

        local savior = ::Shared.Players.GetByUserId(tEntry.savior);
        if (savior != null && savior.IsBot())
        {
            savior.StaggerAwayFromEntity(hurt);
            tEntry.savior = null;
        }
    }
};

__CollectEventCallbacks(LedgeFixEvents, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);

::VSLib.EasyLogic.Notifications.OnRoundStart.LF_Reset <- function ()
{
    ::LF_State.clear();
};
