//============================================================================
//  Campaign Progress Notifier (per-player, localized)
//  ---------------------------------------------------------------------------
//  Thông báo tiến độ hoàn thành chapter GIỐNG chế độ Versus, nhưng gửi RIÊNG
//  cho TỪNG người chơi ngay khi CHÍNH họ đạt mốc (không broadcast toàn đội).
//  Kèm âm thanh báo cho đúng người đó. Toàn bộ message được localized theo
//  ngôn ngữ Steam của người chơi; dữ liệu ngôn ngữ nằm ở localization.nut.
//============================================================================

IncludeScript("src/VSLib");
IncludeScript("src/ProgressNotifier/localization");

// Các mốc tiến độ (%) sẽ thông báo, PHẢI theo thứ tự tăng dần.
::CPN_Milestones <- [25, 50, 75];

// Âm thanh phát riêng cho người chơi khi đạt mốc (đặt null để tắt hẳn).
::CPN_Sound <- "Survival.team_record";

// Chu kỳ kiểm tra tiến độ (giây).
::CPN_PollInterval <- 1.0;

// Trạng thái per-player: key = SteamID, value = số mốc đã thông báo cho người đó.
::CPN_Reached <- {};

/**
 * Thay TẤT CẢ lần xuất hiện của một chuỗi con (so khớp literal, KHÔNG regex),
 * nên placeholder chứa ký tự đặc biệt như "{P}" vẫn an toàn.
 *
 * @param str    (string) Chuỗi nguồn.
 * @param needle (string) Chuỗi con cần tìm.
 * @param value  (string) Chuỗi thay thế.
 * @return (string) Chuỗi đã thay.
 */
::CPN_ReplaceLiteral <- function (str, needle, value)
{
    if (needle.len() == 0) return str;

    local out = "";
    local start = 0;
    local pos;
    while ((pos = str.find(needle, start)) != null)
    {
        out += str.slice(start, pos) + value;
        start = pos + needle.len();
    }
    out += str.slice(start);
    return out;
}

/**
 * Tra một message đã localized từ ::CPN_Locale, tự fallback khi thiếu ngôn ngữ
 * hoặc thiếu bản dịch, rồi thay các placeholder.
 *
 * @param sMessageKey (string) Mã message trong ::CPN_Locale.strings.
 * @param sClientLang (string) Giá trị "cl_language" của người chơi.
 * @param tSubs       (table)  Bảng thay placeholder, vd { P = 25 }; có thể null.
 * @return (string) Chuỗi đã dịch và thay placeholder.
 */
::CPN_Loc <- function (sMessageKey, sClientLang, tSubs = null)
{
    local sFallback = ::CPN_Locale.fallback;

    local sLangCode = (sClientLang in ::CPN_Locale.languages) ? ::CPN_Locale.languages[sClientLang] : sFallback;

    if (!(sMessageKey in ::CPN_Locale.strings)) return sMessageKey;

    local tVariants = ::CPN_Locale.strings[sMessageKey];
    local sText = (sLangCode in tVariants) ? tVariants[sLangCode]
                : ((sFallback in tVariants) ? tVariants[sFallback] : sMessageKey);

    if (tSubs != null)
    {
        foreach (sName, val in tSubs)
        {
            sText = ::CPN_ReplaceLiteral(sText, "{" + sName + "}", val.tostring());
        }
    }

    return sText;
}

/**
 * Gửi thông báo (chat + âm thanh) đạt mốc cho DUY NHẤT một người chơi,
 * theo đúng ngôn ngữ Steam của người đó.
 *
 * @param player    (VSLib::Player) Người chơi vừa đạt mốc.
 * @param iProgress (int)           Mốc phần trăm đạt được (vd 25).
 */
::CPN_AnnounceTo <- function (player, iProgress)
{
    local sMsg = ::CPN_Loc("progress_reached", player.GetClientConvarValue("cl_language"), { P = iProgress });

    player.Print(sMsg, 3); // 3 = HUD_PRINTTALK (khung chat)

    if (::CPN_Sound != null)
    {
        player.PlaySound(::CPN_Sound);
    }
}

/**
 * Vòng lặp kiểm tra định kỳ: với mỗi survivor là NGƯỜI THẬT, so tiến độ RIÊNG
 * của họ với các mốc chưa đạt và thông báo cho chính họ.
 */
::CPN_Tick <- function (params)
{
    // Chỉ chạy ở coop/realism
    local sMode = ::VSLib.Utils.GetBaseMode();
    if (sMode == null || sMode.len() == 0) return;
    if (sMode[0] == 's' || sMode[0] == 'v') return;

    foreach (player in ::VSLib.EasyLogic.Players.AllSurvivors())
    {
        if (player == null || !player.IsEntityValid()) continue;
        if (player.IsBot()) continue;

        local sKey = player.GetSteamID();
        if (sKey == null || sKey == "") continue;
        if (!(sKey in ::CPN_Reached))
        {
            ::CPN_Reached[sKey] <- 0;
        }

        local flPercent = player.GetFlowPercent();

        // Thông báo lần lượt mọi mốc vừa vượt qua kể từ lần kiểm tra trước.
        while (::CPN_Reached[sKey] < ::CPN_Milestones.len() && flPercent >= ::CPN_Milestones[::CPN_Reached[sKey]])
        {
            ::CPN_AnnounceTo(player, ::CPN_Milestones[::CPN_Reached[sKey]]);
            ::CPN_Reached[sKey]++;
        }
    }
}

// Reset trạng thái mỗi khi vào chapter mới (flow được tính lại từ đầu).
::VSLib.EasyLogic.Notifications.OnRoundStart.CampaignProgressNotifier <- function ()
{
    ::CPN_Reached.clear();
};

// Khởi động vòng lặp kiểm tra
::VSLib.Timers.AddTimerByName("CampaignProgressNotifier_Poll", ::CPN_PollInterval, true, ::CPN_Tick);
