# Báo Cáo Phân Tích & Code Review: GitOps API Deployment Config (Senior TA Report)

**Dự án:** E-Commerce Microservices  
**Chủ đề:** Review Config GitOps (Kubernetes Deployment) của các API Server Node (App server chính)  
**Đường dẫn tham khảo:** `gitops/apps/*/base/deployment.yaml`
**Trạng thái Review:** Lần 1 (Pending Refactor - Theo chuẩn Senior Fullstack Engineer)

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🔴 P1] [Architecture / DRY] Phân mảnh Deployment Manifests:** Việc copy-paste tệp `deployment.yaml` riêng lẻ rác rưởi vẫn đang diễn ra ở hầu hết các service thay vì kế thừa tệp chuẩn `common-deployment`.
- **[🟡 P1] [Reliability] Sự Bất Đồng Nhất Về Health Probes:** `loyalty-rewards` vẫn đang set `startupProbe.initialDelaySeconds: 0`. Điều này bắn request health-check ngay lập tức khi DB/Wire chưa kip init, dễ gây restart sai.
- **[🔵 P2] [Cost] Phân Bổ Tài Nguyên Cảm Tính:** `loyalty-rewards` vẫn bú trọn 1Gi Memory Limit, quá lãng phí so với 1 service ít tính toán.
- **[🔵 P2] [Clean Code] Lỗi Naming Convention:** Naming `order-secrets` (số nhiều) vs `search-secret` (số ít) vẫn còn y nguyên.

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm ngoài scope của TA report ban đầu)*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Config/Reliability] Vá lỗi P0 CrashLoopBackOff (Thiếu Mount Config):** Chúc mừng đội ngũ Dev, các file deployment lỗi trước đó (`order`, `loyalty-rewards`) ĐÃ ĐƯỢC THÊM block `volumeMounts` trỏ vào `/app/configs` cùng với khối `volumes`. Giờ đây app đã chạy thành công bằng file config.yaml lấy từ ConfigMap.

## 1. Hiện Trạng Tổng Quan (The Good, The Bad, The Ugly)

Sau khi scan toàn bộ >20 file `deployment.yaml` cho các service API (như `order`, `search`, `loyalty-rewards`, v.v.), có một phát hiện đáng chú ý: **Đội ngũ đã từng có ý định làm chuẩn hoá (DRY) nhưng bỏ dở giữa chừng.**
- Cụ thể: Tồn tại thư mục `gitops/components/common-deployment/deployment.yaml` chứa một template chuẩn với các cờ `PLACEHOLDER_SERVICE_NAME` (sử dụng tính năng Kustomize Components).
- Thực Tế: **Không có kustomization nào đang xài Component này đúng cách**. Thay vào đó, mọi service lại tiếp tục copy-paste nguyên một file `deployment.yaml` dài 80-90 dòng cho riêng mình.

---

## 2. Các Vấn Đề Lớn Phát Hiện Được (Critical Smells) 🚩

Việc copy-paste file Manifest dẫn đến sự phân mảnh cấu hình vô cùng nguy hiểm. Dưới đây là những lỗi P0/P1 cần chấn chỉnh ngay lập tức:

### 🚨 2.1. LỖI NGHIÊM TRỌNG (P0): Thiếu Volume Mounts Cho Config File
Tất cả các service đều chạy args: `exec /app/bin/<service> -conf /app/configs/config.yaml`.
Tuy nhiên, cấu trúc mount volume lại cực kỳ lộn xộn:
- **`search` service:** Làm chuẩn. Có khai báo `volumeMounts` trỏ `/app/configs` vào ConfigMap `search-config`.
- **`order` và `loyalty-rewards`:** **HOÀN TOÀN KHÔNG CÓ `volumeMounts`!**
  - Hệ luỵ: File `/app/configs/config.yaml` mà app đọc thực chất là file được copy chết (bake) vào bên trong Docker Image lúc build.
  - Phá vỡ triết lý GitOps: Kỹ sư không thể đổi config (DB URI, Redis, flags tính năng) bằng cách sửa ConfigMap/Secret trên Repo GitOps được nữa. Đổi config bắt buộc phải build lại Image!

### 🟡 2.2. Sự Bất Đồng Nhất Về Health Probes (P1)
Khác với Worker dùng port 8081, các API Service sử dụng chính port HTTP của ứng dụng (VD: 8004, 8017) để export `/health/live` và `/health/ready`. Tuy nhiên tham số thời gian cực kỳ lộn xộn:
- **`startupProbe` khác nhau:**
  - `order`: `initialDelaySeconds: 10`, `failureThreshold: 30` (Cho phép 160s startup).
  - `search` / `loyalty-rewards`: `initialDelaySeconds: 0`, `failureThreshold: 30`. Probe bắt đầu nã request ngay giây thứ 0 hệ thống mới tải Image xong, dễ sinh ra log rác hoặc false-positive kill.
- **Base `common-deployment`:** Thậm chí KHÔNG CÓ `startupProbe` được định nghĩa trong template chuẩn, và path health lại trúng về `/health` thay vì `/health/live`.

### 🟡 2.3. Lỗi Đặt Tên Naming Convention (Secret & ConfigMap) (P1)
- **Secrets:** Tương tự như bên Worker, resource bị đặt tên lộn xộn số ít / số nhiều tuỳ hứng. Lỗi này làm đau đầu đội Ops.
  - Số nhiều: `order-secrets`
  - Số ít: `search-secret`
- **Tên Deployment / Container:** Lúc thì map là `order`, lúc là `search`, không có tiền tố hay hậu tố thống nhất nào. Dù điều này chấp nhận được trong K8s, nhưng gây rắc rối khi setup các regex monitor logs.

### 🔵 2.4. Phân Bổ Tài Nguyên Bất Báo Cáo (P2)
Tài nguyên cấp phát (Requests/Limits) đang được gán cảm tính:
- `search`: Limit 512Mi / 500m CPU
- `loyalty-rewards`: Limit 1Gi / 1000m CPU. Mặc dù role của rewards không tốn memory cache lớn bằng search engine (Elasticsearch), cấu hình limit gấp đôi search là rất phí tài nguyên của cluster k3d dev/prod.

---

## 3. Lời Khuyên & Kế Hoạch Đập Xây Lại (Refactoring Plan)

Với vai trò Senior Technical Architect, tôi YÊU CẦU **dừng ngay việc copy-paste các tệp manifest tĩnh**.

### ✅ Hành Động Chuẩn (Action Items)

**Giai đoạn 1: Fix lỗi P0 - Khôi phục tính động cho config:**
- Thêm ngay Block `volumes` và `volumeMounts` cho `order`, `loyalty-rewards`, và tất cả các services đang thiếu. Chắc chắn rằng k8s pod đọc config từ ConfigMap (GitOps) chứ không phải từ image.

**Giai đoạn 2: Kích Hoạt Kustomize Component / Helm:**
- Chúng ta ĐÃ CÓ `components/common-deployment`. Hãy tu sửa nó thành một Kustomize Component xịn, hoặc Kustomize Base.
- Tại `gitops/apps/<service>/base/kustomization.yaml`, khai báo:
  ```yaml
  resources:
    - ../../../components/common-deployment
  
  patches:
    - path: patch-deployment.yaml # Gán Tên, RAM, Mounts riêng
  ```
- Hoặc mạnh dạn cấu hình **Helm Chart** nội bộ. Chart Kratos đã được support khá nhiều ngoài cộng đồng.

**Giai đoạn 3: Chuẩn Hóa Probe & Dapr:**
- `/health/live` và `/health/ready` là chuẩn Kratos. Cập nhật base template dùng đúng path này.
- `startupProbe` fix cứng `initialDelaySeconds: 10` cho tất cả các service viết bằng Go. Dù Go boot nhanh, nhưng nó còn phải connect Redis/DB qua Wire init, 10s là an toàn để tránh bị CrashLoop.
