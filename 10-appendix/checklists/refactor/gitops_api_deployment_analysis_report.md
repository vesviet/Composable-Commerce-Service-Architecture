# 📋 Báo Cáo Phân Tích & Code Review: GitOps API Deployment Config

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Review Config GitOps (Kubernetes Deployment) của các API Server Node.  
**Đường dẫn tham khảo:** `gitops/apps/*/base/deployment.yaml`  
**Trạng thái Review:** Lần 2 (Đã đối chiếu với Codebase Thực Tế - NGOAN CỐ KHÔNG FIX)

---

## 🚩 PENDING ISSUES (Unfixed - CẦN ACTION)
- **[🚨 P0] [Architecture/DRY] Sự Phân Mảnh Rác Rưởi Của Deployment Manifests:** Việc copy-paste tệp `deployment.yaml` thủ công lẻ tẻ vẫn đang diễn ra ở hầu hết các service (trên 20 file `deployment.yaml` độ dài 90 dòng lặp lại y hệt). Cực kỳ đáng báo động là team vẫn chưa thèm xóa các tệp này ở `search`, `customer`, `pricing`... **Yêu cầu (Hard-Requirement):** Lập tức xóa bỏ các file rác này và chuyển sang dùng Kustomize Component.
- **[🟡 P1] [Reliability/K8s] Sự Bất Đồng Nhất Về Health Probes Gây OOM/Restart Oan:** Kiểm tra codebase thấy Service `loyalty-rewards` và `search` vẫn đang nhắm mắt set `startupProbe.initialDelaySeconds: 0`. Điều này bắn request health-check ngay lập tức ở giây thứ 0. **Yêu cầu:** Sửa kịch kim `initialDelaySeconds: 10` cho tất cả các service Go.
- **[🔵 P2] [Cost/FinOps] Phân Bổ Tài Nguyên Cảm Tính Gây Lãng Phí Tiền Mây:** `loyalty-rewards` vẫn bú trọn Limit quá to.
- **[🔵 P2] [Clean Code/Naming] Lỗi Đặt Tên Lộn Xộn:** Naming rule K8s đang "múa" tự do.

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Config/Reliability] Vá Lỗi Chí Mạng P0 (Sập Pod Do Thiếu Mount Config):** Các file deployment (như `order`, `loyalty-rewards`) ĐÃ ĐƯỢC THÊM block `volumeMounts` trỏ vào `/app/configs`. Lỗi này không còn tái diễn.

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. Hiện Trạng Tốt (The Good, The Bad, The Ugly)
Sau khi scan toàn bộ >20 file `deployment.yaml` cho các service API, phát hiện một sự thật đau lòng: **Đội ngũ đã từng có ý định làm Tốt (DRY) nhưng làm dở dang rồi vứt xó.**
- **Bằng chứng:** Có hẳn thư mục `gitops/components/common-deployment/deployment.yaml` chứa một template chuẩn.
- **Thực Tế Đau Thương:** **Không có một service nào xài Component này đúng cách**. Mọi người tự tiện copy-paste lại 90 dòng mã.

### 2. Sự Cố Health Probes (P1) Khác Biệt Giữa 2 Thế Giới
Khác với Worker chạy cổng khác, các API Service sử dụng chính HTTP Port của Kratos để export live/ready.
- Tiêu chuẩn: `order` xài `initialDelaySeconds: 10`.
- Lệch chuẩn: `search` / `loyalty-rewards` vẫn đang set `initialDelaySeconds: 0`.

### 3. Giải Pháp Chỉ Đạo Từ Senior
Ngưng ngay trò đùa "Mỗi service tự lo Deploy của mình".

#### Bước 1: Khởi Động Lại Kustomize Components Đang Ngủ Quên
Biến `components/common-deployment` thành chuẩn Vàng. Tại `gitops/apps/<service>/base/kustomization.yaml`, xóa mọi tệp Deployment tĩnh, và trỏ Móc neo vào Base:
```yaml
resources:
  - ../../../components/common-deployment

patches:
  - path: patch-deployment.yaml # Chỉ được chèn đè Tên, Memory, ConfigMap Name
```

#### Bước 2: Thiết Quân Luật Probes & Kratos Standard
Fix cứng `startupProbe.initialDelaySeconds: 10` cho mọi kịch bản Go. Tiết kiệm tài nguyên không có nghĩa là keo kiệt 10 giây nạp đạn của hệ thống.
