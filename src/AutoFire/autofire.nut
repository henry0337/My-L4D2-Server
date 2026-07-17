//============================================================================
//  Biến các khẩu súng semi-auto / pump thành full-auto theo tốc độ ra đạn
//  MẶC ĐỊNH của từng khẩu.
//============================================================================

IncludeScript("src/VSLib");

// Cho phép bot sử dụng được chức năng này (như mô tả).
::AutoFire_IncludeBots <- false;

// Danh sách các vũ khí được áp dụng bắn tự động.
::AutoFire_Guns <-
{
    weapon_pistol           = true,
    weapon_pistol_magnum    = true,
    weapon_pumpshotgun      = true,
    weapon_shotgun_chrome   = true,
    weapon_autoshotgun      = true,
    weapon_shotgun_spas     = true,
    weapon_hunting_rifle    = true,
    weapon_sniper_military  = true,
    weapon_sniper_awp       = true,
    weapon_sniper_scout     = true,
    weapon_grenade_launcher = true,
};

/**
 * Ép súng semi-auto/pump bắn tiếp khi người chơi vẫn giữ nút bắn.
 *
 * @param player (VSLib::Player) Người chơi vừa bắn; có thể @c null.
 * @param weapon (string)        Classname đầy đủ của vũ khí, vd "weapon_pumpshotgun".
 * @param params (table)         Bảng tham số gốc của game event weapon_fire.
 */
::VSLib.EasyLogic.Notifications.OnWeaponFire.AutoFire <- function (player, weapon, params)
{
    if (!(weapon in ::AutoFire_Guns)) return; // Không nằm trong danh sách vũ khí hợp lệ
    if (player == null || !player.IsEntityValid()) return; 
    if (player.GetTeam() != SURVIVORS) return; // Đối tượng nên là một survivor
    if (!::AutoFire_IncludeBots && player.IsBot()) return; // (Như mô tả dòng 8)

    local wep = player.GetActiveWeapon();
    if (wep == null || !wep.IsEntityValid()) return;

    // Giả lập "vừa nhả nút bắn" -> cho phép phát bắn kế tiếp khi vẫn giữ chuột.
    wep.SetNetProp("m_isHoldingFireButton", 0);
};
