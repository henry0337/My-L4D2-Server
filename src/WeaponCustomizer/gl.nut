//============================================================================
//  gl.nut — Tùy chỉnh Grenade Launcher (weapon_grenade_launcher)
//  ---------------------------------------------------------------------------
//  Mục tiêu:
//    1. Đạn dự trữ tối đa: 30 -> 10 (clip luôn = 1 theo thiết kế gốc; nạp clip từ
//       dự trữ đã hoạt động sẵn ở vanilla nên không cần đụng tới).
//    2. Cho phép NẠP LẠI ĐẠN TỪ ĐỐNG ĐẠN (ammo pile) TRONG MAP như súng thường.
//============================================================================

IncludeScript("src/VSLib");

// Số đạn dự trữ TỐI ĐA cho Grenade Launcher (ConVar ammo_grenadelauncher_max,
// mặc định 30) -> hạ về 10 để ra "1/10". Cũng là mức nạp đầy khi dùng ammo pile.
::WC_GL_ReserveMax <- 10;

// Classname của Grenade Launcher.
::WC_GL_Class <- "weapon_grenade_launcher";

// In log chẩn đoán vào khung chat của chính người chơi (đặt false để tắt).
::WC_GL_Verbose <- false;

/**
 * Áp ConVar dự trữ của Grenade Launcher về giá trị ::WC_GL_ReserveMax.
 */
::WC_GL_Apply <- function ()
{
    Convars.SetValue("ammo_grenadelauncher_max", ::WC_GL_ReserveMax);
}

/**
 * Lấy khẩu súng chính (slot0) mà người chơi đang mang.
 *
 * @param player (VSLib::Player) Người chơi cần lấy súng chính; có thể @c null.
 * @return (VSLib::Entity) Khẩu súng chính, hoặc @c null nếu không có.
 */
::WC_GL_GetPrimary <- function (player)
{
    if (player == null || !player.IsPlayerEntityValid()) return null;

    local t = player.GetHeldItems();
    if (t == null || !("slot0" in t)) return null;

    return t["slot0"];
}

/**
 * Khi game báo "vũ khí không dùng được đống đạn": nếu súng chính là Grenade
 * Launcher thì nạp đầy dự trữ về ::WC_GL_ReserveMax (mô phỏng tiếp đạn ở ammo pile).
 *
 * @param player (VSLib::Player) Người chơi đang đứng ở đống đạn; có thể @c null.
 * @param params (table)         Bảng tham số gốc của event.
 * @return (void)
 */
::VSLib.EasyLogic.Notifications.OnAmmoCantUse.WC_GL <- function (player, params)
{
    if (player == null || !player.IsPlayerEntityValid()) return;
    if (player.GetTeam() != SURVIVORS) return;

    local wep = ::WC_GL_GetPrimary(player);
    if (wep == null || !wep.IsEntityValid()) return;
    if (wep.GetClassname() != ::WC_GL_Class) return;

    wep.SetAmmo(::WC_GL_ReserveMax);

    if (::WC_GL_Verbose && !player.IsBot())
    {
        player.Print("[GL] Đã tiếp đạn từ đống đạn: dự trữ = " + ::WC_GL_ReserveMax, HUD_PRINTTALK);
    }
};

// Áp lại mỗi khi vào chapter mới (đề phòng game reset ConVar giữa các map).
::VSLib.EasyLogic.Notifications.OnRoundStart.WC_GL_Apply <- function ()
{
    ::WC_GL_Apply();
};

// Áp ngay khi nạp script (map đang chạy cũng nhận giá trị mới).
::WC_GL_Apply();
