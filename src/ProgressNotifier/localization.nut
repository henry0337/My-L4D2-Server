::CPN_Locale <-
{
    // Ngôn ngữ dùng khi cl_language không khớp bảng dưới, hoặc khi một message
    // chưa có bản dịch cho ngôn ngữ của người chơi.
    fallback = "en",

    // Ánh xạ giá trị Steam "cl_language" -> mã ngôn ngữ nội bộ.
    languages =
    {
        english    = "en",
        vietnamese = "vi",
        japanese   = "ja",
        russian    = "ru",
    },

    strings =
    {
        // Thông báo khi người chơi tự đạt một mốc tiến độ. Dùng placeholder {P}.
        progress_reached =
        {
            en = "\x04The Survivors have made it \x03{P}%\x04 of the way!",
            vi = "\x04Người Sống Sót đã đi được \x03{P}%\x04 chặng đường!",
            ja = "\x04生存者はコースの\x03{P}%\x04を突破しました！",
            ru = "\x04Выжившие прошли \x03{P}%\x04 пути!",
        },
    },
};
