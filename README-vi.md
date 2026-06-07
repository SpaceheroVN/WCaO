*Read this in other languages: [English](README.md) | [Tiếng Việt](README-vi.md)*

# 🚀 Windows Cleanup & Optimizer v6.1.9 - Ultimate Toolkit (WCaO) <a href="https://github.com/SpaceheroVN/Windows_Cleanup_And_Optimizer/releases/download/6.1.9/WCaO.bat"><img src="https://img.shields.io/badge/Download-brightgreen?style=flat&logo=download&logoColor=white" alt="Latest Release" width="85"></a>

![Version](https://img.shields.io/badge/version-v6.1.9-blue?style=plastic) ![Platform](https://img.shields.io/badge/platform-Windows-0078D6?style=plastic&logo=windows&logoColor=white) ![Language](https://img.shields.io/badge/language-Batch-4D4D4D?style=plastic&logo=windows-terminal&logoColor=white) ![License](https://img.shields.io/badge/license-Open%20Source-brightgreen?style=plastic&logo=opensource&logoColor=white) ![Admin](https://img.shields.io/badge/requires_Admin-Optional-yellow?style=plastic&logo=powershell&logoColor=white) ![Status](https://img.shields.io/badge/status-Active-success?style=plastic&logo=rocket&logoColor=white)

Công cụ bảo trì hệ thống mã nguồn mở viết bằng Batch Script. Phiên bản v6.1.7 cung cấp tổng cộng **9 nhóm danh mục** với nhiều chức năng cụ thể giúp dọn dẹp, sửa lỗi và tối ưu hóa Windows. Nếu bạn thấy tôi cập nhật **README.md** đúng phiên bản **hiện tại** thì việc đó đồng nghĩa dự án ***đã tạm dừng vô thời hạn**...

---

## ⚠️ TUYÊN BỐ MIỄN TRỪ TRÁCH NHIỆM
**BẰNG VIỆC SỬ DỤNG BỘ CÔNG CỤ NÀY, BẠN ĐỒNG Ý VỚI [ĐIỀU KHOẢN SỬ DỤNG](#dieu-khoan-su-dung).**
Tác giả **KHÔNG chịu trách nhiệm** cho bất kỳ rủi ro mất dữ liệu hay hư hại hệ thống nào. **Hãy tự chịu rủi ro khi sử dụng.**

---

## ⚙️ Chi Tiết Chức Năng

Tool được chia thành 9 danh mục chính trên Menu, bao gồm các chức năng sau:

### 1. Quick Cleanup (Dọn dẹp nhanh)
*Không yêu cầu quyền Admin.*
* Xóa thư mục tạm của người dùng (`%temp%`) và lối tắt gần đây.
* Xóa thư mục tạm của hệ thống (`%SystemRoot%\Temp`) và Prefetch *(nếu có Admin)*.
* Xóa DNS Cache *(nếu có Admin)*.
* Làm sạch hoàn toàn Thùng rác (Recycle Bin).

### 2. Deep Cleanup (Dọn dẹp chuyên sâu)
*Yêu cầu quyền Admin.*
* **DISM /RestoreHealth:** Sửa chữa image hệ thống Windows.
* **SFC /scannow:** Quét và phục hồi các tệp hệ thống bị hỏng.
* **Disk Cleanup:** Quét và dọn dẹp ổ đĩa tự động.

### 3. System Optimization (Tối ưu hóa hệ thống)
| Chức Năng | Tính năng cụ thể | Yêu cầu Admin |
| :--- | :--- | :--- |
| **Check Disk Integrity** | Quét lỗi ổ cứng (`chkdsk /scan`). | Có |
| **Defrag / Trim Drive** | Chống phân mảnh hoặc tối ưu SSD. | Có |
| **Rebuild Caches** | Làm mới icon, thumbnail và khởi động lại WSearch. | Không |
| **Optimize Power Plan** | Thêm, xóa hoặc thiết lập các chế độ nguồn điện (Ultimate, High...). | Có |
| **Optimize Visual Effects** | Bật/tắt hiệu ứng đồ họa để tăng hiệu suất. | Không |
| **Win 11 Context Menu** | Chuyển đổi giữa Menu chuột phải kiểu Win 10 và Win 11 (Tự động khởi động lại Explorer để áp dụng). | Không |
| **Edge Rounded Corners Fix** | Vá các lối tắt để tắt viền bo tròn ép buộc trên Edge v149+. | Không |

### 4. Advanced Tools (Công cụ nâng cao)
| Chức Năng | Tính năng cụ thể | Yêu cầu Expert Mode |
| :--- | :--- | :--- |
| **Clear Update Cache** | Dọn dẹp cache của Windows Update. | Không |
| **Uninstall Office Key** | Gỡ key bản quyền Office 2016. | Không |
| **Remove Windows.old** | Xóa thư mục bản Win cũ sau khi nâng cấp. | **Có** |
| **Manage Pagefile/Hibernation**| Tắt Pagefile hoặc chế độ ngủ đông (Hibernation). | **Có** |
| **Network Reset & Flush DNS** | Đặt lại mạng và xóa bộ nhớ cache DNS. | Không |
| **Create Restore Point** | Tạo điểm khôi phục hệ thống (Restore Point). | Không |

### 5. System Utilities (Tiện ích hệ thống)
* Hiển thị thông tin hệ thống chi tiết (OS, CPU, RAM, GPU, Storage).
* Khởi động lại Windows Explorer để sửa lỗi giao diện.
* Tắt ép buộc (Kill) các ứng dụng đang bị treo (Not Responding).
* **Check Windows License Key & Status:** Kiểm tra chi tiết trạng thái bản quyền (phát hiện key KMS/Volume rác), trích xuất key gốc từ BIOS/UEFI.
* **Generate Battery Health Report:** Tự động tạo và mở báo cáo HTML chi tiết về tình trạng chai pin của thiết bị.
* **Winget Power Tools:** * Cập nhật tất cả phần mềm tự động ẩn (Silent & Auto) hoặc chọn lọc theo App ID.
  * Cài đặt phần mềm thiết yếu được chia theo danh mục cụ thể (Runtimes, Browsers, Media, Dev Tools, Utilities...).
  * Sửa lỗi và đặt lại bộ nhớ cache của Winget (Reset Source).

### 6. Screen & Power Tools (Công cụ màn hình & Nguồn)
* Tắt màn hình ngay lập tức.
* Tạo file script `Turn Off Screen.bat` ngoài Desktop để tắt màn hình nhanh.

### 7. Quick Rename Pro (Đổi tên hàng loạt)
Công cụ hỗ trợ kéo thả trực tiếp để đổi tên File và Folder số lượng lớn:
* **File:** Xóa dấu ngoặc, đánh số thứ tự (1, 2, 3...), xóa hậu tố, hoặc tìm & thay thế chuỗi ký tự.
* **Folder:** Xóa dấu ngoặc, xóa hậu tố.
* **Fast Rename:** Đổi tên nhanh tương tác từng bước thủ công, hoặc đổi hàng loạt tự động dựa trên danh sách file `.txt` (Hỗ trợ cả File và Folder).
* **Hoàn tác (Undo):** Hỗ trợ hoàn tác lại thao tác đổi tên gần nhất.

### 8. Auto Maintenance (Bảo trì tự động)
*Yêu cầu quyền Admin.*
* Chạy tự động chuỗi tác vụ: Quick Cleanup -> Deep Cleanup -> Clear Windows Update Cache.

### 9. Toolkit Options (Cài đặt & Nhật ký)
* Bật/Tắt chế độ chuyên gia (**Expert Mode**) để hiển thị các tính năng nâng cao/nguy hiểm.
* Trích xuất nhật ký hoạt động (Export Action Report).

---

## 🛠 Hướng Dẫn Sử Dụng

1. **Tải xuống** tệp `WCaO.bat`.
2. Khuyến nghị nhấp chuột phải và chọn **Run as administrator** để sử dụng được toàn bộ các tính năng.
3. Gõ phím số tương ứng ở Menu (từ 0-9) và nhấn `Enter` để điều hướng.
4. Đối với một số tính năng can thiệp sâu (Menu 4), bạn cần vào Menu `9` để bật **Expert Mode** trước khi sử dụng.
5. Toàn bộ lịch sử dọn dẹp được tự động lưu tạm, bạn có thể xuất file Log tại Menu `9`.

---

## Điều khoản sử dụng
1. **Mục đích:** Chỉ dành cho nghiên cứu và học tập.
2. **Trách nhiệm:** Tác giả không chịu trách nhiệm pháp lý cho mọi hư hỏng.
3. **Cẩn trọng:** Hãy tạo **Restore Point** trước khi dùng.

## Giấy phép
Giấy phép MIT - Bản quyền (c) 2026 thuộc về SpaceheroVN.
Dự án này được cấp phép theo Giấy phép MIT - xem file [LICENSE](LICENSE) để biết thêm chi tiết.
