//============================================================================
//  director_base_addon.nut
//  Hook chuẩn của L4D2, tự động chạy mỗi khi map load (đúng thời điểm hệ thống
//  game-event đã sẵn sàng). Dùng để nạp các script global.
//============================================================================

IncludeScript("src/cvars");
IncludeScript("src/Infected/general");
IncludeScript("src/Infected/smoker");
IncludeScript("src/AutoFire/autofire");
IncludeScript("src/ProgressNotifier/progress_notifier");
IncludeScript("src/WeaponCustomizer/entrypoint");
IncludeScript("src/Moderation/moderation");
