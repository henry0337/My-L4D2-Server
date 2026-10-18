# Coding convention

## Quy ước đặt tên (Squirrel)

- File: `snake_case`.
- Namespace và hàm: `PascalCase`.
- Biến (local, tham số): `camelCase`.
- Hằng: `UPPER_SNAKE`, khai báo bằng `const`.

## Comment

- Không viết **comment** hay **documentation string** trong code.
- **Ngoại lệ** duy nhất: module Shared (`src/Shared/`) được phép có comment và documentation string.

## Thư viện (Library)

Thuật ngữ "Thư viện" trong repo này chỉ chung hai thư mục:

- Thư mục `src/VSLib/` + File `src/VSLib.nut` (sẽ được đề cập với cái tên chung là **VSLib**)
- Thư mục `src/Shared/`

Bạn sẽ không được phép động vào **VSLib** bằng bất cứ giá nào, coi nó là **source of truth** giống như trên trang chủ **Valve Developer** cho **Left 4 Dead 2**.

## Lỗi đã gặp và cách xử lý (Squirrel / L4D2)

### Cú pháp Squirrel

- `const` chỉ nhận **số nguyên, số thực hoặc chuỗi**. Không được gán `true`, `false`, `null`: compiler bỏ cả file, các `::Namespace` trong file đó không tồn tại, và **extension VS Code không báo lỗi**. Với cờ bật/tắt, dùng `const X = 1;` / `0` và kiểm tra bằng `X != 0`.
- `base` là từ khóa, không được dùng làm tên field, tham số hay biến (VS Code báo `expected 'IDENTIFIER'`). Đặt tên khác, ví dụ `defaultReserve`. Các từ khóa dễ vấp khác: `class`, `default`, `delete`, `enum`, `static`, `this`, `clone`, `typeof`.
- Extension VS Code chỉ bắt được một phần lỗi. File không báo lỗi vẫn có thể hỏng khi nạp trong game: nếu một module "im lặng" hoàn toàn (không log, convar không đổi), nghi ngờ lỗi compile và xem console lúc nạp map.
- Module dùng guard `if (!("Name" in getroottable()))` thì sửa code xong phải **khởi động lại map** mới có hiệu lực, nạp lại script không thay bảng cũ.

### Đạn dự trữ

- Đạn dự trữ lưu trên người chơi theo **loại đạn**, không theo từng khẩu. Convar `ammo_*_max` dùng chung cho cả họ (ví dụ `ammo_assaultrifle_max` cho M16, AK-47, Desert, SG552). Muốn một khẩu có mức riêng thì không đặt convar theo khẩu đó, mà để convar ở mức chuẩn của loại đạn và cấp riêng bằng `SetAmmo`.
- Client chỉ nhận đạn dự trữ trong 10 bit (0–1023). Giá trị lớn hơn vẫn đúng ở server nhưng HUD hiển thị `giá trị - 1024`, ví dụ 1080 hiện `56`, 1440 hiện `416`. Không đặt dự trữ trên 1023; mức trần dùng trong repo là 1000.
- Engine điền đạn cho súng mới nhặt (bằng đúng convar) **sau** khi event `item_pickup` / `weapon_given` bắn ra, nên `SetAmmo` trong event bị ghi đè. Cấp đạn phải dùng poll hoặc timer trễ. Lệnh `give` ở console cũng có thể không bắn event.
- Khi bắt đầu nạp đạn, engine trả phần đạn dở của băng về dự trữ ngay (clip về 0, dự trữ tăng đúng bằng phần đó), rồi cuối lần nạp mới lấy lại từ dự trữ. Muốn vứt đạn dở thì trừ lại phần trả về ngay lúc đó, đừng sửa ở cuối lần nạp vì sẽ có khoảnh khắc hiển thị sai.
- `ammo_*_max = -2` nghĩa là đạn dự trữ **vô hạn** (HUD hiện 999 cố định). Tank Run (`Director.GetGameMode() == "tankrun"`, base `coop`) tự đặt `-2` cho mọi loại đạn. Với mode bị tắt (Versus, Scavenge, Tank Run) không được ghi đè convar của mode: dùng `::WeaponCustomizer.ApplyConvar`, chỉ trả convar về mức gốc khi giá trị hiện tại đúng bằng giá trị module đã đặt. Từng ghi đè vô điều kiện 360/650 lên `-2` và làm hỏng cơ chế của Tank Run.
- Mức gốc đã đối chiếu (addon `resettings.nut` trong Workshop): assaultrifle 360, autoshotgun 90, grenadelauncher 30, huntingrifle 150, shotgun 72, smg 650, sniperrifle 180. `ammo_m60_max` gốc là 0 (M60 không hồi đạn ở đống đạn), không phải 150.
- Muốn biết một mode tự đặt convar đạn gì thì in giá trị thật ra chat (`Shared.Chat.ChatBroadcast`, console `Log` có thể không thấy) kèm `Director.GetGameMode()` và `::VSLib.Utils.GetBaseMode()`, đừng đoán.
- Timer của VSLib chạy theo think của một entity trung gian nên chu kỳ poll thực tế bị chặn dưới, giảm `PollInterval` dưới 0.1 chưa chắc nhanh hơn (chưa kiểm chứng).

## Ngôn ngữ localization được hỗ trợ chính thức

- Vietnamese
- Japanese
- English
- Chinese (Traditional + Simplified)
- Korean (`korean` và `koreana`)
- Thailand
