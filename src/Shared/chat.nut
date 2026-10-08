::Shared.Chat <-
{
    /**
     * Tách `text` thành các dòng theo ký tự xuống dòng, giữ nguyên cả dòng rỗng.
     * @param {string} text Chuỗi cần tách
     * @returns {array} Mảng các dòng
     */
    SplitLines = function (text)
    {
        local lines = [];
        local start = 0;
        local position;
        while ((position = text.find("\n", start)) != null)
        {
            lines.append(text.slice(start, position));
            start = position + 1;
        }
        lines.append(text.slice(start));
        return lines;
    },

    /**
     * Cắt cứng một dòng quá dài thành các đoạn không vượt quá `maxBytes` byte.
     * Điểm cắt luôn lùi về ranh giới ký tự UTF-8 để không làm hỏng ký tự nhiều byte.
     * @param {string} line Dòng cần cắt
     * @param {integer} maxBytes Số byte tối đa của mỗi đoạn
     * @returns {array} Mảng các đoạn
     */
    SplitByBytes = function (line, maxBytes)
    {
        local pieces = [];
        local total = line.len();
        local position = 0;
        while (position < total)
        {
            local end = position + maxBytes;
            if (end >= total)
            {
                end = total;
            }
            else
            {
                local boundary = end;
                while (boundary > position && (line[boundary] & 0xC0) == 0x80)
                {
                    boundary--;
                }
                if (boundary > position) end = boundary;
            }
            pieces.append(line.slice(position, end));
            position = end;
        }
        return pieces;
    },

    /**
     * Gom `text` thành các đoạn, mỗi đoạn không vượt quá `maxBytes` byte, để không bị client cắt cụt.
     * Các dòng được ghép lại bằng "\n"; dòng nào dài hơn `maxBytes` sẽ bị cắt cứng theo ranh giới UTF-8.
     * @param {string|array} text Một chuỗi (có thể chứa "\n") hoặc mảng các dòng
     * @param {integer} maxBytes Số byte tối đa của mỗi đoạn
     * @returns {array} Mảng các đoạn
     */
    SplitIntoChunks = function (text, maxBytes = CHAT_MAX_BYTES)
    {
        local lines = (typeof text == "array") ? text : ::Shared.Chat.SplitLines(text);
        local chunks = [];
        local chunk = null;

        foreach (line in lines)
        {
            local pieces = (line.len() > maxBytes) ? ::Shared.Chat.SplitByBytes(line, maxBytes) : [line];
            foreach (piece in pieces)
            {
                if (chunk != null && chunk.len() + 1 + piece.len() > maxBytes)
                {
                    chunks.append(chunk);
                    chunk = null;
                }
                chunk = (chunk == null) ? piece : chunk + "\n" + piece;
            }
        }

        if (chunk != null)
        {
            chunks.append(chunk);
        }
        return chunks;
    },

    /**
     * Gửi nội dung `message` tới ô chat của TOÀN BỘ người chơi, tự chia nhỏ nếu vượt giới hạn byte.
     *
     * @param {string} message Nội dung tin nhắn
     * @see https://developer.valvesoftware.com/wiki/Left_4_Dead_2/Scripting/Script_Functions/ClientPrint
     */
    ChatBroadcast = function (message)
    {
        foreach (chunk in ::Shared.Chat.SplitIntoChunks(message))
        {
            ClientPrint(null, HUD_PRINTTALK, chunk);
        }
    },

    /**
     * Gửi nội dung `message` tới ô chat của riêng `target`, tự chia nhỏ nếu vượt giới hạn byte.
     * @param {string|array} message Một chuỗi hoặc mảng các dòng
     * @param {CTerrorPlayer} target Người chơi (entity gốc của game) sẽ nhận tin nhắn
     * @param {string} color Mã màu thêm vào đầu mỗi đoạn
     * @see https://developer.valvesoftware.com/wiki/Left_4_Dead_2/Scripting/Script_Functions/ClientPrint
     */
    TargetChat = function (message, target, color = "")
    {
        foreach (chunk in ::Shared.Chat.SplitIntoChunks(message))
        {
            ClientPrint(target, HUD_PRINTTALK, color + chunk);
        }
    },

    /**
     * Gửi nội dung `message` tới console của riêng tôi, tự chia nhỏ nếu vượt giới hạn byte.
     * @param {string} message Nội dung tin nhắn
     * @param {CTerrorPlayer} target Người chơi (entity gốc của game) sẽ nhận tin nhắn
     * @see https://developer.valvesoftware.com/wiki/Left_4_Dead_2/Scripting/Script_Functions/ClientPrint
     */
    Log = function (message, target = null)
    {
        foreach (chunk in ::Shared.Chat.SplitIntoChunks(message))
        {
            ClientPrint(target, HUD_PRINTCONSOLE, chunk);
        }
    }
};
