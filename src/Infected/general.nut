//============================================================================
//  Infected/general.nut — Các fix hành vi chung cho Special Infected.
//  ---------------------------------------------------------------------------
//  [Stagger Claw Fix]
//  Vá lỗi gốc của game: khi một SI bot bị stagger (loạng choạng vì trúng đạn,
//  bị đẩy, hụt pounce...) nó VẪN cào được bằng đòn thường. Dễ thấy nhất ở
//  Hunter/Jockey, nhưng phần lớn SI đều dính. Với Hunter, "cào" là nút phụ
//  IN_ATTACK2 (chuột phải) — pounce (IN_ATTACK) đã bị stagger chặn đúng, chỉ
//  còn đòn cào lọt qua.
//============================================================================

IncludeScript("src/VSLib");

// Bit nút "tấn công phụ" (IN_ATTACK2 / chuột phải). Với SI đây chính là đòn
// cào thường. Squirrel nền của game không định nghĩa sẵn hằng này; dùng biến
// root thay vì const để tránh va chạm nếu môi trường có sẵn định nghĩa khác.
::SIClawFix_ClawButton <- 2048; // (1 << 11)

// Chu kỳ quét (giây). Càng nhỏ càng bám sát khung stagger; 0.03s ~ mỗi tick.
::SIClawFix_TickInterval <- 0.03;

// Khoảng ân hạn (giây) sau khi SI thoát trạng thái bị chặn, trước khi cho cào
// lại. Chống việc SI cào ngay lập tức khi vừa hết stagger / vừa chạm đất.
::SIClawFix_GraceTime <- 0.5;

// In một dòng log ra console khi module khởi động (đặt false để tắt).
::SIClawFix_Verbose <- false;

// Trạng thái per-entity: key = entity index của SI đang bị chặn cào.
//   value == null   -> đang trong điều kiện bị chặn (stagger / trên không).
//   value == <float> -> đã thoát điều kiện, là mốc thời gian Time() được phép
//                       bật cào trở lại (đang đếm ngược ân hạn).
// Không có key trong bảng nghĩa là SI đó đang được cào bình thường.
::SIClawFix_State <- {};

/**
 * Kiểm tra một player SI có đang trong trạng thái stagger hay không.
 *
 * @param player (VSLib::Player) SI cần kiểm tra (đã được xác thực hợp lệ).
 * @return (bool) @c true nếu đang stagger.
 */
::SIClawFix_IsStaggered <- function (player)
{
    return player.GetNetPropFloat("m_staggerTimer", 1) > -1.0;
}

/**
 * Một vòng quét: cập nhật trạng thái chặn/mở đòn cào cho toàn bộ SI bot.
 *
 * @param params (table) Bảng tham số của timer VSLib (không dùng tới).
 */
::SIClawFix_Tick <- function (params)
{
    foreach (player in ::VSLib.EasyLogic.Players.InfectedBots())
    {
        if (player == null || !player.IsEntityValid()) continue;

        local iType = player.GetPlayerType();
        local iIndex = player.GetIndex();

        // Điều kiện chặn cào: KHÔNG áp cho Tank (Tank cũng stagger nhưng đòn
        // của nó không phải bug này). Chặn khi đang stagger, hoặc khi Hunter/
        // Jockey đang lơ lửng (chưa chạm đất) — lúc này không được cào.
        local bShouldDisable = !player.IsDead()
            && iType != Z_TANK
            && ( ::SIClawFix_IsStaggered(player) || ( !player.HasFlag(FL_ONGROUND) && (iType == Z_HUNTER || iType == Z_JOCKEY) ) );

        if (bShouldDisable)
        {
            // Vào/ở trong điều kiện chặn: tắt cào và huỷ mọi ân hạn đang đếm.
            if (!(iIndex in ::SIClawFix_State))
                player.DisableButton(::SIClawFix_ClawButton);

            ::SIClawFix_State[iIndex] <- null;
        }
        else if (iIndex in ::SIClawFix_State)
        {
            if (::SIClawFix_State[iIndex] == null)
            {
                // Vừa thoát điều kiện chặn -> bắt đầu đếm ân hạn.
                ::SIClawFix_State[iIndex] = Time() + ::SIClawFix_GraceTime;
            }
            else if (Time() >= ::SIClawFix_State[iIndex])
            {
                // Hết ân hạn -> cho cào trở lại.
                player.EnableButton(::SIClawFix_ClawButton);
                delete ::SIClawFix_State[iIndex];
            }
        }
    }
}

// Xoá trạng thái mỗi khi vào chapter mới: entity index có thể bị tái sử dụng
// cho player khác, không được để trạng thái cũ dính sang.
::VSLib.EasyLogic.Notifications.OnRoundStart.SIClawFix <- function ()
{
    ::SIClawFix_State.clear();
};

// Khởi động vòng quét (AddTimerByName tự thay thế nếu đã tồn tại -> không nhân đôi).
::VSLib.Timers.AddTimerByName("SIClawFix_Tick", ::SIClawFix_TickInterval, true, ::SIClawFix_Tick);
