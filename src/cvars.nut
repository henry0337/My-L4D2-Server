//============================================================================
//  cvars.nut — Bảng ConVars mặc định của người dùng (quản lý tập trung)
//  ---------------------------------------------------------------------------
//  Toàn bộ ConVars khai báo trong ::UserCvars sẽ được ÁP (set) lại mỗi khi bắt
//  đầu một chapter (game-event round_start), tức mỗi lần vào / chuyển map trong
//  bất kỳ campaign nào. Áp lại theo từng round giúp giá trị luôn "dính" kể cả
//  khi game tự reset một số ConVar giữa các chapter.
//
//  Convars.SetValue chạy từ vscript phía server nên set được cả ConVar gắn cờ
//  FCVAR_CHEAT mà KHÔNG cần "sv_cheats 1".
//============================================================================

IncludeScript("src/VSLib");

// Danh sách CVars sẽ được tùy chỉnh
::UserCvars <-
{
    survivor_allow_crawling = 1,
    survivor_crawl_speed = 60,
    sv_consistency = 0,
    sv_pausable = 1
};

// In log vào console (HUD_PRINTCONSOLE) mỗi lần áp ConVar (đặt false để tắt).
::UserCvars_Verbose <- false;

/**
 * Áp toàn bộ ConVars trong ::UserCvars vào game theo đúng giá trị đã khai báo.
 */
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

// Áp lại mỗi khi một chapter bắt đầu (chuyển map / vào campaign mới).
::VSLib.EasyLogic.Notifications.OnRoundStart.UserCvarsApply <- function ()
{
    ::UserCvars_Apply();
};

::UserCvars_Apply();
