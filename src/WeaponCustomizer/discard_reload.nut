//============================================================================
//  discard_reload.nut — Nạp đạn kiểu "vứt băng dở" (tactical/realistic reload)
//  ---------------------------------------------------------------------------
//  Mục tiêu (áp cho MỌI súng chính có đạn dự trữ):
//    Khi nạp lại lúc băng đạn CHƯA cạn, toàn bộ số đạn còn dở trong băng cũ bị
//    VỨT ĐI — người chơi lắp một băng ĐẦY mới lấy từ kho dự trữ. Vì vậy mỗi lần
//    nạp luôn tốn trọn một băng từ dự trữ, thay vì chỉ "bù" cho đủ.
//      Ví dụ maxClip=30: 25/90 --reload--> 30/60  (KHÔNG phải 30/85).
//    (Giống cơ chế realistic mà người dùng mong muốn; tương tự Counter-Strike 2.)
//
//  Phạm vi:
//    - Chỉ súng chính (slot0) -> tự loại pistol (dự trữ vô hạn) và melee (slot1).
//    - Loại weapon_rifle_m60 (đã có luật nạp riêng ở m60.nut) và weapon_chainsaw.
//============================================================================

IncludeScript("src/VSLib");

// --- Cấu hình ---------------------------------------------------------------

// Các classname KHÔNG áp cơ chế này.
::WC_DR_Exclude <-
{
    weapon_rifle_m60 = true, // Có luật nạp 1 lần/chapter riêng (m60.nut)
    weapon_chainsaw  = true, // Không có cơ chế nạp băng
};

// Chu kỳ dò (giây). Nhỏ để không bỏ lỡ thời điểm nạp xong.
::WC_DR_PollInterval <- 0.1;

// In log chẩn đoán vào khung chat của chính người chơi (đặt false để tắt).
::WC_DR_Verbose <- false;

// --- Trạng thái theo dõi ----------------------------------------------------

// key = UserID người chơi, value = { wepIdx, clip, reserve } của súng chính ở
// nhịp dò trước. Dùng để phát hiện thay đổi giữa hai nhịp.
::WC_DR_State <- {};

// --- Tiện ích ---------------------------------------------------------------

/**
 * Lấy khẩu súng chính (slot0) mà người chơi đang mang.
 *
 * @param player (VSLib::Player) Người chơi cần lấy súng chính; có thể @c null.
 * @return (VSLib::Entity) Khẩu súng chính, hoặc @c null nếu không có.
 */
::WC_DR_GetPrimary <- function (player)
{
    local t = player.GetHeldItems();
    if (t == null || !("slot0" in t)) return null;

    local wep = t["slot0"];
    if (wep == null || !wep.IsEntityValid()) return null;

    return wep;
}

/**
 * Xét một survivor ở một nhịp dò: phát hiện vừa reload xong và áp cơ chế
 * "vứt băng dở" bằng cách tính lại clip/dự trữ từ giá trị TRƯỚC reload.
 *
 * @param player (VSLib::Player) Survivor cần xét; có thể @c null.
 */
::WC_DR_ProcessPlayer <- function (player)
{
    if (player == null || !player.IsPlayerEntityValid()) return;

    local iUid = player.GetUserID();
    local wep = ::WC_DR_GetPrimary(player);

    // Không có súng chính hợp lệ / thuộc danh sách loại trừ -> xóa baseline.
    if (wep == null || (wep.GetClassname() in ::WC_DR_Exclude))
    {
        if (iUid in ::WC_DR_State) delete ::WC_DR_State[iUid];
        return;
    }

    local iWepIdx  = wep.GetIndex();
    local iClipNow = wep.GetClip();
    local iResNow  = wep.GetAmmo();
    if (iClipNow == null || iResNow == null) return;

    // Chưa có baseline hoặc vừa đổi khẩu khác -> đặt baseline, chưa xử lý.
    if (!(iUid in ::WC_DR_State) || ::WC_DR_State[iUid].wepIdx != iWepIdx)
    {
        ::WC_DR_State[iUid] <- { wepIdx = iWepIdx, clip = iClipNow, reserve = iResNow };
        return;
    }

    local prev = ::WC_DR_State[iUid];

    // Dấu hiệu vừa nạp xong: clip tăng VÀ dự trữ giảm so với nhịp trước.
    if (iClipNow > prev.clip && iResNow < prev.reserve)
    {
        local iOldClip     = prev.clip;      // Đạn còn dở trong băng cũ (bị vứt)
        local iReserveBefore = prev.reserve; // Dự trữ trước khi nạp
        local iMaxClip     = wep.GetMaxClip();
        if (iMaxClip == null || iMaxClip <= 0) 
        {
            iMaxClip = iClipNow;
        }

        // Băng mới lắp đầy từ dự trữ (KHÔNG cộng lại đạn dở); phần thừa bỏ đi.
        local iTargetClip    = (iReserveBefore < iMaxClip) ? iReserveBefore : iMaxClip;
        local iTargetReserve = iReserveBefore - iTargetClip;

        wep.SetAmmo(iTargetReserve); // Trừ trọn một băng khỏi dự trữ (chi phí discard)

        // Chỉ hạ clip khi engine lắp nhiều hơn mức "một băng từ dự trữ" cho phép
        // (trường hợp dự trữ ít). KHÔNG nâng clip lên để tránh trả lại đạn vừa bắn.
        if (iClipNow > iTargetClip)
        {
            wep.SetClip(iTargetClip);
            iClipNow = iTargetClip;
        }

        if (::WC_DR_Verbose && !player.IsBot())
        {
            player.Print("[Reload] Vứt " + iOldClip + " viên dở; băng mới " + iClipNow + ", dự trữ " + iTargetReserve, 3); // 3 = HUD_PRINTTALK
        }

        // Cập nhật baseline theo giá trị đã chỉnh để không kích hoạt lại.
        prev.clip = iClipNow;
        prev.reserve = iTargetReserve;
        return;
    }

    // Không phải reload -> cập nhật baseline bình thường (bắn, nhặt đạn, ...).
    prev.clip = iClipNow;
    prev.reserve = iResNow;
};

/**
 * Vòng lặp dò định kỳ: xét mọi survivor.
 *
 * @param params (table) Bảng tham số của timer (không dùng).
 */
::WC_DR_Tick <- function (params)
{
    foreach (player in ::VSLib.EasyLogic.Players.AllSurvivors())
    {
        ::WC_DR_ProcessPlayer(player);
    }
};

// Reset trạng thái mỗi khi vào chapter mới.
::VSLib.EasyLogic.Notifications.OnRoundStart.WC_DR <- function ()
{
    ::WC_DR_State.clear();
};

// Khởi động vòng lặp dò.
::VSLib.Timers.AddTimerByName("WC_DiscardReload_Poll", ::WC_DR_PollInterval, true, ::WC_DR_Tick);
