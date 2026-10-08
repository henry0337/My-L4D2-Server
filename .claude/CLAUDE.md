# Coding convention

## Quy ước đặt tên (Squirrel)

- File: `snake_case`.
- Namespace và hàm: `PascalCase`.
- Biến (local, tham số): `camelCase`.
- Hằng: `UPPER_SNAKE`, khai báo bằng `const`.

## Comment

- Không viết **comment** hay **documentation string** trong code.
- Ngoại lệ duy nhất: module Shared (`src/Shared/`) được phép có comment và documentation string.

## Thư viện (Library)

Thuật ngữ "Thư viện" trong repo này chỉ chung hai thành phần:

- Thư mục `src/VSLib/` + File `src/VSLib.nut` (sẽ được đề cập với cái tên chung là **VSLib**)
- Thư mục `src/Shared/`

Bạn sẽ không được phép động vào **VSLib** bằng bất cứ giá nào, coi nó là **source of truth giống** như trên trang chủ **Valve Developer** cho **Left 4 Dead 2**.

## Ngôn ngữ localization được hỗ trợ chính thức

- Vietnamese
- Japanese
- English
- Chinese (Traditional + Simplified)
- Korean (`korean` và `koreana`)
- Thailand
