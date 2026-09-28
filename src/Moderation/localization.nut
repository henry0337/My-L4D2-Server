::MOD_Locale <-
{
    fallback = "en",

    languages =
    {
        english    = "en",
        vietnamese = "vi",
        japanese   = "ja",
        russian    = "ru",
    },

    strings =
    {
        perm_denied =
        {
            en = "\x04[Mod]\x01 Only the host can use this command.",
            vi = "\x04[Mod]\x01 Chỉ host mới được dùng lệnh này.",
            ja = "\x04[Mod]\x01 このコマンドはホストのみ使用できます。",
            ru = "\x04[Mod]\x01 Команда доступна только хосту.",
        },
        not_found =
        {
            en = "\x04[Mod]\x01 No human player is playing \x03{N}\x01.",
            vi = "\x04[Mod]\x01 Không có người chơi thật nào đang dùng nhân vật \x03{N}\x01.",
            ja = "\x04[Mod]\x01 \x03{N}\x01 を使用中の人間プレイヤーがいません。",
            ru = "\x04[Mod]\x01 Нет живого игрока за персонажа \x03{N}\x01.",
        },
        cannot_self =
        {
            en = "\x04[Mod]\x01 You cannot target yourself.",
            vi = "\x04[Mod]\x01 Bạn không thể tự áp dụng lên chính mình.",
            ja = "\x04[Mod]\x01 自分自身を対象にできません。",
            ru = "\x04[Mod]\x01 Нельзя выбрать самого себя.",
        },
        dur_none =
        {
            en = "immediately", vi = "ngay lập tức", ja = "即時", ru = "немедленно",
        },
        dur_minutes =
        {
            en = "{V} min", vi = "{V} phút", ja = "{V}分", ru = "{V} мин",
        },
        dur_seconds =
        {
            en = "{V} sec", vi = "{V} giây", ja = "{V}秒", ru = "{V} сек",
        },

        ban_usage =
        {
            en = "\x04[Mod]\x01 Usage: \x03!ban <character>\x01 (e.g. !ban nick)",
            vi = "\x04[Mod]\x01 Cú pháp: \x03!ban <nhân_vật>\x01 (vd: !ban nick)",
            ja = "\x04[Mod]\x01 使い方: \x03!ban <キャラ名>\x01 (例: !ban nick)",
            ru = "\x04[Mod]\x01 Использование: \x03!ban <персонаж>\x01 (напр. !ban nick)",
        },
        ban_done =
        {
            en = "\x04[Mod]\x01 Banned \x03{P}\x01 (\x05{N}\x01, {S}) and kicked.",
            vi = "\x04[Mod]\x01 Đã ban \x03{P}\x01 (\x05{N}\x01, {S}) và kick khỏi session.",
            ja = "\x04[Mod]\x01 \x03{P}\x01 (\x05{N}\x01, {S}) をBANして追放しました。",
            ru = "\x04[Mod]\x01 \x03{P}\x01 (\x05{N}\x01, {S}) забанен и исключён.",
        },

        kick_usage =
        {
            en = "\x04[Mod]\x01 Usage: \x03!kick <character> [time]\x01 (e.g. !kick nick 10m, !kick nick 5s, !kick nick)",
            vi = "\x04[Mod]\x01 Cú pháp: \x03!kick <nhân_vật> [thời_gian]\x01 (vd: !kick nick 10m, !kick nick 5s, !kick nick)",
            ja = "\x04[Mod]\x01 使い方: \x03!kick <キャラ名> [時間]\x01 (例: !kick nick 10m / 5s / なし)",
            ru = "\x04[Mod]\x01 Использование: \x03!kick <персонаж> [время]\x01 (напр. !kick nick 10m, 5s)",
        },
        kick_done =
        {
            en = "\x04[Mod]\x01 \x03{P}\x01 (\x05{N}\x01) will be kicked in {W}s — block: {D}.",
            vi = "\x04[Mod]\x01 \x03{P}\x01 (\x05{N}\x01) sẽ bị kick sau {W}s — chặn: {D}.",
            ja = "\x04[Mod]\x01 \x03{P}\x01 (\x05{N}\x01) を{W}秒後にキック — 制限: {D}。",
            ru = "\x04[Mod]\x01 \x03{P}\x01 (\x05{N}\x01) будет исключён через {W}с — блок: {D}.",
        },
        kick_warn_temp =
        {
            en = "\x04[Mod]\x01 You will be temporarily kicked in {W}s for {D}. You may rejoin afterwards.",
            vi = "\x04[Mod]\x01 Bạn sẽ bị kick tạm thời sau {W} giây, trong {D}. Bạn có thể tham gia lại sau đó.",
            ja = "\x04[Mod]\x01 {W}秒後に{D}の間キックされます。その後は再参加できます。",
            ru = "\x04[Mod]\x01 Через {W}с вы будете временно исключены на {D}. Затем сможете вернуться.",
        },
        kick_warn_now =
        {
            en = "\x04[Mod]\x01 You will be kicked in {W}s. You may rejoin right after.",
            vi = "\x04[Mod]\x01 Bạn sẽ bị kick sau {W} giây. Bạn có thể vào lại ngay sau đó.",
            ja = "\x04[Mod]\x01 {W}秒後にキックされます。すぐに再参加できます。",
            ru = "\x04[Mod]\x01 Через {W}с вы будете исключены. Сразу сможете вернуться.",
        },
    },
};

::MOD_ReplaceLiteral <- function (str, needle, value)
{
    if (needle.len() == 0) return str;

    local out = "", start = 0, pos;
    while ((pos = str.find(needle, start)) != null)
    {
        out += str.slice(start, pos) + value;
        start = pos + needle.len();
    }
    return out + str.slice(start);
}

::MOD_Loc <- function (sMessageKey, sClientLang, tSubs = null)
{
    local sFallback = ::MOD_Locale.fallback;
    local sLangCode = (sClientLang in ::MOD_Locale.languages) ? ::MOD_Locale.languages[sClientLang] : sFallback;

    if (!(sMessageKey in ::MOD_Locale.strings)) return sMessageKey;

    local tVariants = ::MOD_Locale.strings[sMessageKey];
    local sText = (sLangCode in tVariants) ? tVariants[sLangCode]
                : ((sFallback in tVariants) ? tVariants[sFallback] : sMessageKey);

    if (tSubs != null)
        foreach (sName, val in tSubs)
            sText = ::MOD_ReplaceLiteral(sText, "{" + sName + "}", val.tostring());

    return sText;
}
