//============================================================================
//  m60.nut — Tùy chỉnh M60 (weapon_rifle_m60)
//  ---------------------------------------------------------------------------
//  Mục tiêu:
//    1. Clip: 150 -> 200. (clip_size gốc = 150 nằm trong weapon script của VPK,
//       KHÔNG có ConVar; nên ta ép clip = 200 bằng netprop m_iClip1 lúc nhận súng.)
//    2. Không bị game tự vứt (discard) khi bắn hết đạn.
//    3. Cho nạp lại (reload) ĐÚNG 1 lần cho mỗi chapter.
//
//  Cơ chế:
//    - M60 vanilla là súng "dùng 1 lần": clip về 0 + KHÔNG có đạn dự trữ -> engine
//      tự vứt. Chỉ cần cho ConVar "ammo_m60_max" > 0 thì M60 được đối xử như một
//      khẩu primary bình thường: hết đạn vẫn NẰM TRONG TAY (0/0) và có thể reload
//      khi còn dự trữ. Đây là nền tảng cho cả (2) và (3).
//    - Cấp 200 đạn dự trữ MỘT lần mỗi chapter -> người chơi tự bấm R nạp lại đúng
//      1 lần; sau đó dự trữ = 0, không nạp thêm được. Tổng cộng 200 (clip) + 200
//      (một lần nạp) = 400 viên/chapter.
//    - Reload gốc của M60 chỉ nạp tới maxclip (150). Vì ta muốn 200, khi phát hiện
//      lần reload hợp lệ ta ÉP clip = 200, dự trữ = 0, và re-assert clip sau một
//      nhịp ngắn để "thắng" mọi thao tác clamp của engine ở cuối animation reload.
//============================================================================

IncludeScript("src/VSLib");

// Classname của M60.
::WC_M60_Class <- "weapon_rifle_m60";

// Số đạn trong clip mong muốn (thay cho 150 gốc).
::WC_M60_Clip <- 200;

// Số đạn dự trữ cấp cho "một lần nạp" mỗi chapter.
::WC_M60_ReserveGrant <- 200;

// Giá trị cho ConVar ammo_m60_max: phải >= ReserveGrant và > 0 để M60 không bị
// đối xử như súng "dùng 1 lần".
::WC_M60_ReserveMax <- 200;

// In log chẩn đoán vào khung chat của chính người chơi (đặt false để tắt).
::WC_M60_Verbose <- false;

// --- Trạng thái theo chapter -----------------------------------------------

// key = UserID người chơi, value = true nếu đã dùng hết lượt reload chapter này.
::WC_M60_ReloadUsed <- {};

// key = entity index của khẩu M60, value = true nếu đã khởi tạo (đặt clip/dự trữ)
// trong chapter này. Tránh việc mỗi lần đổi/nhặt lại súng bị nạp đầy clip.
::WC_M60_Inited <- {};

// --- Tiện ích ---------------------------------------------------------------

/**
 * Kiểm tra một classname có phải M60 không.
 *
 * @param sClassname (string) Classname cần kiểm tra; có thể @c null.
 * @return (bool) @c true nếu là M60.
 */
::WC_M60_IsM60 <- function (sClassname)
{
    return sClassname == ::WC_M60_Class;
}

/**
 * In log chẩn đoán cho DUY NHẤT một người chơi (chỉ khi bật Verbose và là người thật).
 *
 * @param player (VSLib::Player) Người nhận log; có thể @c null.
 * @param sMsg   (string)        Nội dung log.
 * @return (void)
 */
::WC_M60_Log <- function (player, sMsg)
{
    if (!::WC_M60_Verbose) return;
    if (player == null || !player.IsPlayerEntityValid()) return;
    if (player.IsBot()) return;

    player.Print("[M60] " + sMsg, 3); // 3 = HUD_PRINTTALK (khung chat)
}

/**
 * Xác nhận một VSLib::Player là survivor hợp lệ đang xét tới.
 *
 * @param player (VSLib::Player) Đối tượng cần kiểm tra; có thể @c null.
 * @return (bool) @c true nếu là survivor hợp lệ.
 */
::WC_M60_IsSurvivor <- function (player)
{
    if (player == null || !player.IsPlayerEntityValid()) return false;
    return player.GetTeam() == SURVIVORS;
}

// --- Khởi tạo M60 khi nhận / nhặt -------------------------------------------

/**
 * Khởi tạo một khẩu M60 vừa vào tay survivor: đặt clip = 200 và cấp đạn dự trữ
 * cho lượt reload (nếu người chơi chưa dùng lượt reload của chapter). Chỉ khởi
 * tạo MỘT lần cho mỗi khẩu trong một chapter (theo entity index).
 *
 * @param player (VSLib::Player) Người đang cầm khẩu M60.
 * @param wep    (VSLib::Entity) Thực thể khẩu M60; có thể @c null.
 * @return (void)
 */
::WC_M60_InitWeapon <- function (player, wep)
{
    if (!::WC_M60_IsSurvivor(player)) return;
    if (wep == null || !wep.IsEntityValid()) return;
    if (!::WC_M60_IsM60(wep.GetClassname())) return;

    local iWepIdx = wep.GetIndex();
    if (iWepIdx in ::WC_M60_Inited) return; // Đã khởi tạo khẩu này trong chapter
    ::WC_M60_Inited[iWepIdx] <- true;

    local iUid = player.GetUserID();
    local bUsed = (iUid in ::WC_M60_ReloadUsed) && ::WC_M60_ReloadUsed[iUid];

    wep.SetClip(::WC_M60_Clip);
    wep.SetAmmo(bUsed ? 0 : ::WC_M60_ReserveGrant);

    ::WC_M60_Log(player, "Sẵn sàng: clip=" + ::WC_M60_Clip
        + " dự trữ=" + (bUsed ? 0 : ::WC_M60_ReserveGrant)
        + (bUsed ? " (đã hết lượt nạp chapter)" : " (còn 1 lượt nạp)"));
}

// --- Xử lý reload (tiêu thụ lượt nạp duy nhất) ------------------------------

/**
 * Callback re-assert clip sau khi reload xong, "thắng" mọi thao tác clamp của
 * engine về maxclip (150) ở cuối animation reload.
 *
 * @param params (table) Bảng chứa khóa @c wep (VSLib::Entity khẩu M60).
 */
::WC_M60_ReassertClip <- function (params)
{
    local wep = params.wep;
    if (wep == null || !wep.IsEntityValid()) return;
    if (!::WC_M60_IsM60(wep.GetClassname())) return;

    if (wep.GetClip() < ::WC_M60_Clip)
    {
        wep.SetClip(::WC_M60_Clip);
    }
}

/**
 * Tiêu thụ "lượt nạp duy nhất" khi người chơi reload M60: ép clip về 200, dồn
 * hết dự trữ về 0 và đánh dấu đã dùng lượt cho chapter này.
 *
 * @param player (VSLib::Player) Người chơi vừa reload; có thể @c null.
 * @param manual (bool)          @c true nếu reload do người chơi chủ động (bấm R).
 * @param params (table)         Bảng tham số gốc của event weapon_reload.
 * @return (void)
 */
::VSLib.EasyLogic.Notifications.OnWeaponReload.WC_M60 <- function (player, manual, params)
{
    if (!::WC_M60_IsSurvivor(player)) return;

    local wep = player.GetActiveWeapon();
    if (wep == null || !wep.IsEntityValid()) return;
    if (!::WC_M60_IsM60(wep.GetClassname())) return;

    local iUid = player.GetUserID();
    local bUsed = (iUid in ::WC_M60_ReloadUsed) && ::WC_M60_ReloadUsed[iUid];

    if (bUsed)
    {
        // Đã dùng lượt rồi: đảm bảo không còn dự trữ để không nạp thêm được.
        wep.SetAmmo(0);
        ::WC_M60_Log(player, "Đã hết lượt nạp của chapter này.");
        return;
    }

    // Lượt nạp hợp lệ duy nhất: nạp đầy 200 và tiêu hết dự trữ.
    ::WC_M60_ReloadUsed[iUid] <- true;
    wep.SetClip(::WC_M60_Clip);
    wep.SetAmmo(0);

    // Re-assert clip sau khi engine kết thúc animation reload (đề phòng clamp 150).
    ::VSLib.Timers.AddTimer(0.5, false, ::WC_M60_ReassertClip, { wep = wep });
};

// --- Bắt các thời điểm M60 vào tay người chơi -------------------------------

// weapon_given: tham số weapon là ENTITY.
::VSLib.EasyLogic.Notifications.OnWeaponGiven.WC_M60 <- function (player, giver, weapon, params)
{
    ::WC_M60_InitWeapon(player, weapon);
};

// item_pickup: tham số weapon là CLASSNAME (string) -> lấy súng đang cầm.
::VSLib.EasyLogic.Notifications.OnItemPickup.WC_M60 <- function (player, weapon, params)
{
    if (!::WC_M60_IsM60(weapon)) return;
    ::WC_M60_InitWeapon(player, player.GetActiveWeapon());
};

/**
 * Áp ConVar ammo_m60_max để M60 không bị đối xử như súng "dùng 1 lần".
 */
::WC_M60_Apply <- function ()
{
    Convars.SetValue("ammo_m60_max", ::WC_M60_ReserveMax);
}

::VSLib.EasyLogic.Notifications.OnRoundStart.WC_M60 <- function ()
{
    ::WC_M60_Apply();
    ::WC_M60_ReloadUsed.clear(); 
    ::WC_M60_Inited.clear();
};

::WC_M60_Apply();
