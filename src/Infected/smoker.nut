//============================================================================
//  Infected/smoker_shove_melee.nut — Cho phép shove (đẩy) Smoker khi đang bị
//  lưỡi kéo và đang cầm vũ khí cận chiến (weapon_melee, slot 1).
//  ---------------------------------------------------------------------------
//  [Melee Shove during Smoker Pull Fix]
//  Lỗi gốc của game: khi người chơi bị Smoker móc lưỡi (giai đoạn ĐANG KÉO,
//  trước lúc bị siết cổ), nếu đang cầm súng (slot 0) thì bấm chuột phải vẫn
//  shove được để đẩy Smoker loạng choạng; nhưng nếu đang cầm vũ khí cận chiến
//  thì nút phụ (IN_ATTACK2) của melee lại là "đòn chém phụ" bị game khoá trong
//  lúc bị kéo — nên người chơi mất luôn khả năng tự đẩy Smoker.
//
//  Cách vá: trong khung thời gian ĐANG KÉO, tự phát hiện người chơi bấm nút
//  phụ, tái tạo animation shove (viewmodel + gesture bên thứ 3 + tiếng vung),
//  rồi tự gọi Stagger lên Smoker nếu Smoker nằm trong tầm & trong góc nhìn.
//
//  Nguyên tác: addon "Melee Shove during Smoker Pull Fix" của Raya
//  (workshop 3676296062). Bản này viết lại theo VSLib cho khớp codebase.
//============================================================================

IncludeScript("src/VSLib");

::SmokerShoveMelee <- {};

// Bit nút "tấn công phụ" (IN_ATTACK2 / chuột phải) — chính là nút shove.
// Squirrel nền của game không định nghĩa sẵn hằng này.
::SmokerShoveMelee.ATTACK2_BUTTON <- 2048; // (1 << 11)

// Tầm shove tối đa (đơn vị Hammer). Ngoài tầm này coi như không đẩy tới Smoker.
::SmokerShoveMelee.SHOVE_RANGE <- 120.0;

// Ngưỡng khoảng cách mà nếu vượt qua vẫn phát tiếng "trúng" cho có phản hồi.
::SmokerShoveMelee.SOUND_RANGE <- 115.0;

// Góc lệch tối đa (độ) giữa hướng nhìn và Smoker để tính là "shove trúng".
::SmokerShoveMelee.VIEW_TOLERANCE <- 50.0;

// In một dòng log khi module khởi động (đặt false để tắt).
::SmokerShoveMelee.Verbose <- true;

// Trạng thái per-survivor: key = entity index của người chơi đang bị kéo.
//   record.choke  (bool)          -> Smoker đã chuyển sang giai đoạn siết cổ
//                                    chưa (khi true thì ngừng cho shove).
//   record.dummy  (VSLib.Entity)  -> logic_script chạy think mỗi tick, hoặc
//                                    null nếu chưa có think nào đang chạy.
// Không có key nghĩa là người chơi đó không trong pha bị kéo.
::SmokerShoveMelee.State <- {};

/**
 * Lấy (tạo nếu chưa có) bản ghi trạng thái của một người chơi.
 *
 * @param idx (int) Entity index của survivor.
 * @return (table) Bản ghi { choke, dummy } tương ứng.
 */
::SmokerShoveMelee.GetRecord <- function (idx)
{
    if (!(idx in ::SmokerShoveMelee.State))
        ::SmokerShoveMelee.State[idx] <- { choke = false, dummy = null };

    return ::SmokerShoveMelee.State[idx];
};

/**
 * Dừng vòng think của một survivor: giết dummy logic_script và xoá trạng thái.
 *
 * @param idx (int) Entity index của survivor.
 */
::SmokerShoveMelee.StopThink <- function (idx)
{
    if (!(idx in ::SmokerShoveMelee.State))
        return;

    local dummy = ::SmokerShoveMelee.State[idx].dummy;
    if (dummy != null && dummy.IsEntityValid())
        dummy.Kill();

    delete ::SmokerShoveMelee.State[idx];
};

/**
 * Kiểm tra Smoker có nằm trong góc nhìn của survivor không (dùng để quyết định
 * cú shove có "trúng" và làm Smoker loạng choạng hay không).
 *
 * @param surv   (VSLib.Player) Người chơi đang bị kéo.
 * @param target (VSLib.Player) Smoker đang kéo.
 * @return (bool) @c true nếu góc lệch nhỏ hơn VIEW_TOLERANCE.
 */
::SmokerShoveMelee.ViewCheck <- function (surv, target)
{
    local startpos = surv.GetEyePosition();
    local target_pos = target.GetOrigin() + Vector(0, 0, 30);

    local targetNorm = Vector(target_pos.x - startpos.x,
                              target_pos.y - startpos.y,
                              target_pos.z - startpos.z);
    local len = targetNorm.Norm();
    if (len <= 0.0)
        return true;

    targetNorm.x = targetNorm.x / len;
    targetNorm.y = targetNorm.y / len;
    targetNorm.z = targetNorm.z / len;

    local viewerAng = surv.GetEyeAngles().Forward();
    local angle = 180.0 / PI * acos(viewerAng.Dot(targetNorm));

    return (angle < ::SmokerShoveMelee.VIEW_TOLERANCE);
};

/**
 * Thử shove lại sau một nhịp trễ nhỏ — dùng cho trường hợp người chơi quét
 * chuột nhanh: lúc bấm nút Smoker chưa lọt vào góc nhìn, nhưng ngay sau đó thì
 * có, nên vẫn cho ăn shove.
 *
 * @param params (table) { surv = VSLib.Player, smoker = VSLib.Player }.
 */
::SmokerShoveMelee.RetryStagger <- function (params)
{
    local surv = params.surv;
    local smoker = params.smoker;

    if (surv == null || !surv.IsPlayerEntityValid()) return;
    if (smoker == null || !smoker.IsPlayerEntityValid()) return;

    // Nếu đã chuyển sang siết cổ thì thôi.
    local idx = surv.GetIndex();
    if (idx in ::SmokerShoveMelee.State && ::SmokerShoveMelee.State[idx].choke)
        return;

    if (surv.GetSequenceActivityName(surv.GetSequence()) == "ACT_TERROR_DRAGGING_FROM_TONGUE")
        return;

    if (::SmokerShoveMelee.ViewCheck(surv, smoker))
    {
        smoker.StaggerAwayFromLocation(surv.GetOrigin());
        surv.EmitSound("Weapon.HitInfected");
    }
};

/**
 * Xử lý sự kiện Smoker bắt đầu siết cổ (choke_start). Đánh dấu để vòng think
 * ngừng cho shove — giai đoạn siết cổ không còn thuộc phạm vi bản vá.
 *
 * @param smoker (VSLib.Player) Smoker gây ra.
 * @param victim (VSLib.Player) Người chơi bị siết.
 * @param params (table) Bảng tham số sự kiện gốc.
 */
::VSLib.EasyLogic.Notifications.OnSmokerChokeBegin.SmokerShoveMelee <- function (smoker, victim, params)
{
    if (victim == null || !victim.IsPlayerEntityValid()) return;
    if (victim.IsBot()) return;

    ::SmokerShoveMelee.GetRecord(victim.GetIndex()).choke = true;
};

/**
 * Xử lý sự kiện Smoker móc trúng lưỡi (tongue_grab) — bắt đầu vòng think cho
 * phép shove trong lúc bị kéo.
 *
 * @param smoker (VSLib.Player) Smoker gây ra.
 * @param victim (VSLib.Player) Người chơi bị móc.
 * @param params (table) Bảng tham số sự kiện gốc.
 */
::VSLib.EasyLogic.Notifications.OnSmokerTongueGrab.SmokerShoveMelee <- function (smoker, victim, params)
{
    if (victim == null || !victim.IsPlayerEntityValid()) return;
    if (smoker == null || !smoker.IsPlayerEntityValid()) return;
    if (victim.IsBot()) return;

    local idx = victim.GetIndex();
    local record = ::SmokerShoveMelee.GetRecord(idx);

    // Đã có think đang chạy cho người chơi này -> không tạo trùng.
    if (record.dummy != null && record.dummy.IsEntityValid())
        return;

    record.choke = false;

    // Tạo một logic_script rỗng chỉ để "cắm" hàm think chạy mỗi tick.
    local dummy = ::VSLib.Utils.CreateEntity("logic_script");
    if (dummy == null)
        return;
    record.dummy = dummy;

    // Think chạy mỗi tick suốt pha ĐANG KÉO. Trả về số giây tới lần think kế:
    //   -1  = tick tiếp theo (mặc định, để bắt kịp cạnh bấm nút).
    //   >0  = thời gian hồi giữa hai cú shove (theo z_gun_swing_interval).
    dummy.AddThinkFunction(function ()
    {
        // --- Điều kiện dừng ---------------------------------------------------
        if (victim == null || !victim.IsPlayerEntityValid())
        {
            ::SmokerShoveMelee.StopThink(idx);
            return -1;
        }

        if (victim.IsIncapacitated() || victim.IsHangingFromLedge() || victim.IsDying())
        {
            ::SmokerShoveMelee.StopThink(idx);
            return -1;
        }

        // Hết bị kéo: Smoker mất, hoặc lưỡi không còn chủ.
        if (smoker == null || !smoker.IsPlayerEntityValid()
            || victim.GetNetPropEntity("m_tongueOwner") == null)
        {
            ::SmokerShoveMelee.StopThink(idx);
            return -1;
        }

        // Đã chuyển sang siết cổ -> ngoài phạm vi bản vá.
        if (::SmokerShoveMelee.State[idx].choke)
        {
            ::SmokerShoveMelee.StopThink(idx);
            return -1;
        }

        // Đã bị lôi sát vào Smoker (animation kéo tới) -> ngừng.
        if (victim.GetSequenceActivityName(victim.GetSequence()) == "ACT_TERROR_DRAGGING_FROM_TONGUE")
        {
            ::SmokerShoveMelee.StopThink(idx);
            return -1;
        }

        // --- Phát hiện bấm nút shove -----------------------------------------
        if ((victim.GetNetPropInt("m_afButtonPressed") & ::SmokerShoveMelee.ATTACK2_BUTTON) == 0)
            return -1;

        local weapon = victim.GetActiveWeapon();
        if (weapon == null || !weapon.IsEntityValid() || weapon.GetClassname() != "weapon_melee")
            return -1;

        // Chỉ shove khi vũ khí đang ở tư thế idle (không đang giữa một đòn khác).
        local act = weapon.GetSequenceActivityName(weapon.GetSequence());
        if (act != "ACT_VM_IDLE" && act != "ACT_VM_IDLE_TO_LOWERED_IDLE")
            return -1;

        // Tôn trọng thời gian hồi của đòn phụ.
        local time = Time();
        if (time < weapon.GetNetPropFloat("m_flNextSecondaryAttack"))
            return -1;

        // --- Tái tạo animation shove -----------------------------------------
        local viewModel = victim.GetViewModel();

        // Gesture bên thứ 3 (người khác nhìn thấy). Slot gesture 6, tái dùng
        // animation "chém phụ đàn guitar" — chỉ cần một cử động vung tay.
        local body_seq = victim.LookupSequence("ACT_SHOOT_SECONDARY_GUITAR");
        victim.SetNetPropInt("m_NetGestureSequence", body_seq, 6);
        victim.SetNetPropInt("m_NetGestureActivity", victim.LookupActivity("ACT_SHOOT_SECONDARY_GUITAR"), 6);
        victim.SetNetPropFloat("m_NetGestureStartTime", time, 6);

        // Animation viewmodel (góc nhìn của chính người chơi). Slot gesture 5.
        local vm_seq = weapon.LookupSequence("ACT_VM_SECONDARYATTACK");
        weapon.SetNetPropInt("m_NetGestureSequence", vm_seq, 5);
        weapon.SetNetPropInt("m_NetGestureActivity", weapon.LookupActivity("ACT_VM_SECONDARYATTACK"), 5);
        weapon.SetNetPropFloat("m_NetGestureStartTime", 0, 5);

        if (viewModel != null && viewModel.IsEntityValid())
        {
            viewModel.SetNetPropInt("m_nLayerSequence", vm_seq);
            viewModel.SetNetPropInt("m_nLayer", 0);
            viewModel.SetNetPropFloat("m_flLayerStartTime", time);
        }

        // Chặn "helping hand" (bàn tay phụ khi sát Smoker) khỏi cướp animation.
        weapon.SetNetPropFloat("m_helpingHandSuppressionTimer.m_duration", 1);
        weapon.SetNetPropFloat("m_helpingHandSuppressionTimer.m_timestamp", time + 1);
        weapon.SetNetPropInt("m_helpingHandState", 0);

        victim.EmitSound("Weapon.Swing");

        // --- Quyết định có đẩy Smoker loạng choạng không ---------------------
        local surv_pos = victim.GetOrigin();
        local smoker_pos = smoker.GetOrigin();
        local dist = (smoker_pos - surv_pos).Length();

        if (dist <= ::SmokerShoveMelee.SHOVE_RANGE)
        {
            if (::SmokerShoveMelee.ViewCheck(victim, smoker))
            {
                smoker.StaggerAwayFromLocation(surv_pos);
                if (dist > ::SmokerShoveMelee.SOUND_RANGE)
                    victim.EmitSound("Weapon.HitInfected");
            }
            else
            {
                // Chưa lọt góc nhìn: thử lại sau một nhịp (quét chuột nhanh).
                ::VSLib.Timers.AddTimer(0.1, false, ::SmokerShoveMelee.RetryStagger,
                    { surv = victim, smoker = smoker });
            }
        }

        // Đặt nhịp hồi giữa hai cú shove theo cấu hình của game.
        local interval = Convars.GetFloat("z_gun_swing_interval");
        if (interval < -1.0)
            interval = -1.0;
        return interval;
    });
};

// Dọn trạng thái mỗi khi vào chapter mới: entity index có thể bị tái sử dụng
// cho player khác, và mọi dummy cũ cần được huỷ.
::VSLib.EasyLogic.Notifications.OnRoundStart.SmokerShoveMelee <- function ()
{
    foreach (idx, record in ::SmokerShoveMelee.State)
    {
        if (record.dummy != null && record.dummy.IsEntityValid())
            record.dummy.Kill();
    }
    ::SmokerShoveMelee.State.clear();
};
