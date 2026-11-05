*Đọc tài liệu bằng ngôn ngữ khác: [English](README.md) | [Tiếng Việt](README-vi.md)*

# 🚀 Windows Cleanup & Optimizer v6.3.2 - Phiên bản TUI (WCaO) <a href="https://raw.githubusercontent.com/SpaceheroVN/WCaO/refs/heads/main/WCaO_TUI.bat"><img src="https://img.shields.io/badge/Download-brightgreen?style=flat&logo=download&logoColor=white" alt="Tải về bản mới nhất" width="85"></a>

![Phiên bản](https://img.shields.io/badge/version-v6.3.2_TUI-blue?style=plastic) ![Nền tảng](https://img.shields.io/badge/platform-Windows-0078D6?style=plastic&logo=windows&logoColor=white) ![Giao diện](https://img.shields.io/badge/interface-TUI_%C4%90i%E1%BB%81u_khi%E1%BB%83n_chu%E1%BB%99t-06b6d4?style=plastic&logo=windows-terminal&logoColor=white) ![Ngôn ngữ](https://img.shields.io/badge/language-Batch_%26_PowerShell-4D4D4D?style=plastic&logo=gnubash&logoColor=white) ![Giấy phép](https://img.shields.io/badge/license-Open%20Source-brightgreen?style=plastic&logo=opensource&logoColor=white) ![Quyền hạn](https://img.shields.io/badge/requires_Admin-T%C3%B9y_ch%E1%BB%8Dn-yellow?style=plastic&logo=powershell&logoColor=white) ![Trạng thái](https://img.shields.io/badge/status-Ho%E1%BA%A1t_%C4%91%E1%BB%99ng-success?style=plastic&logo=rocket&logoColor=white)

Bộ công cụ mã nguồn mở tối ưu và bảo trì hệ thống Windows toàn diện, không cần cài đặt bất kỳ thành phần ngoài nào, được trang bị giao diện **Terminal User Interface (TUI)** thế hệ mới. Phiên bản **v6.3.2** là bước nhảy vọt toàn diện so với các tệp lệnh dòng lệnh truyền thống: hỗ trợ tương tác chuột tự nhiên, bảng điều khiển hai cột trực quan và luồng nhật ký theo dõi thời gian thực.

---

## 🌟 Những Điểm Đột Phá Trên Phiên Bản TUI v6.3.2

* **Tương tác chuột tự nhiên:** Di chuyển con trỏ, nhấp chọn danh mục, nhấp vào các nút trạng thái `[ BẬT ]` / `[ TẮT ]` / `[ CÓ ]` / `[ KHÔNG ]`, cuộn chuột và kéo thanh cuộn nhật ký trực tiếp trong cửa sổ dòng lệnh hoặc Windows Terminal mà không bị giới hạn chỉ dùng bàn phím.
* **Bảng điều khiển hai cột chuyên nghiệp:**
  * **Cột bên trái:** Khung danh mục điều hướng, thông số trạng thái hệ thống, nút điều khiển và hiệu ứng xoay khi tác vụ đang xử lý.
  * **Cột bên phải:** Khung xuất nhật ký hoạt động theo màu sắc thời gian thực, có bộ nhớ đệm lịch sử và thanh cuộn kéo thả mượt mà.
* **Khởi chạy thông minh không nháy màn hình:** Tự động chuyển tiếp mượt mà vào Windows Terminal hoặc cửa sổ dòng lệnh chuẩn với chế độ xử lý màu ảo và mã hóa ký tự UTF-8 hoàn chỉnh.
* **Chuyển đổi ngôn ngữ tức thì:** Hỗ trợ song ngữ Tiếng Việt và Tiếng Anh, chuyển đổi ngay lập tức mà không cần khởi động lại ứng dụng.
* **Cơ chế an toàn nhiều lớp:** Các can thiệp sâu vào nhân hệ thống được bảo vệ an toàn bởi chế độ chuyên gia và các bước xác thực quyền Quản trị viên.

---

## ⚠️ TUYÊN BỐ MIỄN TRỪ TRÁCH NHIỆM
**BẰNG VIỆC SỬ DỤNG BỘ CÔNG CỤ NÀY, BẠN ĐỒNG Ý VỚI [ĐIỀU KHOẢN SỬ DỤNG](#dieu-khoan-su-dung).**
Tác giả **KHÔNG chịu trách nhiệm** cho bất kỳ rủi ro mất mát dữ liệu, gián đoạn phần mềm hay hư hại hệ thống nào. **Hãy tự chịu trách nhiệm khi sử dụng.**

---

## ⚙️ Cấu Trúc Các Nhóm Chức Năng

Bộ công cụ TUI gom nhóm tất cả tiện ích hệ thống vào 9 danh mục trực quan:

### 1. Dọn Dẹp Nhanh
*Phù hợp cho nhu cầu dọn rác định kỳ hàng tuần. Hoạt động an toàn ngay cả khi không có quyền Quản trị viên.*
* Dọn dẹp toàn bộ tệp rác tạm thời của người dùng (`%TEMP%`) và lối tắt Recent.
* Xóa tệp tạm hệ thống (`%SystemRoot%\Temp`) và bộ nhớ nạp trước Prefetch *(tự động tối ưu sâu hơn khi có quyền Quản trị viên)*.
* Xóa sạch bộ nhớ đệm phân giải tên miền DNS (`ipconfig /flushdns`).
* Làm sạch hoàn toàn Thùng rác hệ thống.

### 2. Dọn Dẹp Chuyên Sâu
*Yêu cầu quyền Quản trị viên.*
* **Sửa chữa kho thành phần Windows:** Chạy lệnh `DISM /Online /Cleanup-Image /RestoreHealth` khôi phục gói thành phần hệ điều hành bị hỏng.
* **Kiểm tra và sửa lỗi tệp hệ thống:** Chạy lệnh `sfc /scannow` quét và tự động thay thế các tệp tin hệ thống bị lỗi hoặc thất lạc.
* **Dọn dẹp ổ đĩa hệ thống:** Tự động quét và dọn sạch các bản cập nhật cũ cùng các tệp báo cáo lỗi hệ thống.

### 3. Tối Ưu Hóa Hệ Thống
| Tính Năng | Mô tả chi tiết | Yêu cầu Quản trị viên |
| :--- | :--- | :--- |
| **Kiểm tra ổ cứng** | Quét bề mặt và lỗi phân vùng đĩa với lệnh `chkdsk /scan`. | Có |
| **Chống phân mảnh và tối ưu SSD** | Tối ưu hóa phân mảnh ổ cứng cơ hoặc gửi lệnh TRIM tối ưu cho ổ SSD. | Có |
| **Làm mới bộ nhớ đệm** | Khởi tạo lại bộ nhớ đệm biểu tượng IconCache, bộ nhớ ảnh thu nhỏ ThumbnailCache và khởi động lại dịch vụ Windows Search. | Không |
| **Tối ưu chế độ nguồn điện** | Kích hoạt các gói hiệu năng cao như Ultimate Performance hoặc High Performance. | Có |
| **Tối ưu hiệu ứng đồ họa** | Tinh chỉnh bật tắt các hiệu ứng cửa sổ giúp giao diện phản hồi nhanh hơn. | Không |
| **Menu chuột phải Windows 11** | Chuyển đổi linh hoạt giữa menu cổ điển Windows 10 và menu mới Windows 11. | Không |
| **Vá góc bo tròn trình duyệt Edge** | Tắt viền khung bo tròn ép buộc trên trình duyệt Microsoft Edge. | Không |

### 4. Công Cụ Nâng Cao
| Tính Năng | Mô tả chi tiết | Yêu cầu Chuyên gia |
| :--- | :--- | :--- |
| **Xóa bộ đệm cập nhật** | Xóa sạch thư mục tải về của Windows Update để khắc phục lỗi cập nhật bị treo. | Không |
| **Tạo điểm khôi phục** | Tạo Điểm khôi phục nhanh chóng trước khi can thiệp sâu vào hệ thống. | Không |
| **Quản lý RAM ảo và ngủ đông** | Tùy biến bộ nhớ ảo Pagefile hoặc tắt tính năng ngủ đông để giải phóng dung lượng ổ C. | **Có** |
| **Xóa thư mục Windows cũ** | Dọn sạch thư mục sao lưu Windows.old sau khi nâng cấp phiên bản hệ điều hành. | **Có** |
| **Đổi tên hàng loạt** | Công cụ đổi tên tệp và thư mục tốc độ cao theo quy tắc, hậu tố, đánh số thứ tự. | Không |
| **Quản lý gói phần mềm Winget** | Tự động quét, cập nhật phần mềm hàng loạt và cài đặt các gói ứng dụng cần thiết. | Không |

### 5. Tiện Ích Hệ Thống
* **Thông tin phần cứng và bản quyền:** Tra cứu chi tiết cấu hình gồm hệ điều hành, vi xử lý, bộ nhớ RAM, card đồ họa, ổ lưu trữ và truy vấn khóa bản quyền gốc trong phần sụn BIOS/UEFI.
* **Đóng ứng dụng bị treo:** Tắt nhanh tức thì các tiến trình đang ở trạng thái ngừng phản hồi.
* **Trung tâm quản lý RAM:** Khu vực trung tâm điều khiển và quản lý tiến trình tối ưu RAM chạy nền.
* **Khởi động lại Windows Explorer:** Nạp lại tiến trình `explorer.exe` nhanh chóng để khắc phục lỗi đơ thanh tác vụ hoặc màn hình đen.
* **Trung tâm mạng và Wi-Fi:** Đặt lại danh mục Winsock, giao thức TCP/IP, làm mới địa chỉ IP và chẩn đoán kết nối mạng.
* **Tắt màn hình nhanh:** Đưa màn hình vào chế độ nghỉ ngay lập tức hoặc tạo lối tắt tiện lợi ngoài màn hình chính.

### 6. Bảo Trì Tự Động
*Quy trình thực hiện tuần tự tự động chỉ với 1 cú nhấp chuột.*
* Tự động chạy tuần tự: **Dọn dẹp nhanh** ➔ **Dọn dẹp chuyên sâu** ➔ **Xóa bộ đệm cập nhật Windows**.
* Báo cáo tiến độ trực quan với biểu tượng xoay, tự động luân chuyển lưu trữ nhật ký trong 7 ngày.

### 7. Cài Đặt Bộ Công Cụ
* **Chế độ Chuyên gia:** Công tắc khóa hoặc mở an toàn các tính năng can thiệp hệ thống chuyên sâu.
* **Chuyển đổi ngôn ngữ:** Đổi linh hoạt giữa Tiếng Việt và Tiếng Anh tức thì.
* **Trích xuất báo cáo:** Lưu toàn bộ bản ghi lịch sử hoạt động ra tệp nhật ký trong thư mục dữ liệu ứng dụng.

---

## 🛠 Hướng Dẫn Sử Dụng

1. **Tải về:** Tải tệp [`WCaO_TUI.bat`](https://raw.githubusercontent.com/SpaceheroVN/WCaO/refs/heads/main/WCaO_TUI.bat) mới nhất về máy tính.
2. **Khởi chạy:** 
   * Nhấp đúp chuột để mở (tự động chuyển tiếp vào Windows Terminal nếu đã cài đặt).
   * Khuyến khích nhấp chuột phải và chọn **Run as administrator** để sử dụng trọn vẹn mọi tính năng dọn dẹp chuyên sâu.
3. **Thao tác:**
   * Sử dụng chuột trực tiếp: nhấp vào các danh mục bên trái, nhấp các nút trạng thái `[ BẬT ]` / `[ TẮT ]` và kéo thanh cuộn.
   * Hoặc dùng bàn phím với các phím mũi tên điều hướng, phím tắt số hoặc phím Enter / Esc.

---

## 📜 Điều Khoản Sử Dụng
1. **Mục đích sử dụng:** Công cụ được phát triển phục vụ mục đích bảo trì hệ thống cá nhân và nghiên cứu học tập.
2. **Miễn trừ trách nhiệm:** Tác giả không chịu trách nhiệm đối với các sự cố phần cứng hoặc phần mềm do thao tác sai mục đích.
3. **Biện pháp cẩn trọng:** Luôn chủ động tạo **Điểm khôi phục hệ thống** trước khi kích hoạt các tính năng chuyên gia.
