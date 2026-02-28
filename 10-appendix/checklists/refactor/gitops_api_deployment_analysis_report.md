# 📋 Báo Cáo Phân Tích & Code Review: GitOps API Deployment Config

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Review Config GitOps (Kubernetes Deployment) của các API Server Node.  
**Đường dẫn tham khảo:** `gitops/apps/*/base/deployment.yaml`  
**Trạng thái Review:** Đã Review - Cần Refactor Lập Tức  

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🚨 P1] [Architecture/DRY] Sự Phân Mảnh Rác Rưởi Của Deployment Manifests:** Việc copy-paste tệp `deployment.yaml` thủ công lẻ tẻ vẫn đang diễn ra ở hầu hết các service (trên 20 file `deployment.yaml` độ dài 90 dòng lặp lại y hệt). Thay vì tuân thủ và kế thừa tệp chuẩn `common-deployment`, các DevOps/Backend dev lười biếng đã tàn phá nguyên lý DRY. **Yêu cầu:** Lập tức xóa bỏ các file rác này và chuyển sang dùng Kustomize Component / Helm Chart nội bộ.
- **[🟡 P1] [Reliability/K8s] Sự Bất Đồng Nhất Về Health Probes Gây OOM/Restart Oan:** Service `loyalty-rewards` vẫn đang nhắm mắt set `startupProbe.initialDelaySeconds: 0`. Điều này bắn request health-check ngay lập tức ở giây thứ 0 khi DB/Wire còn chưa kịp Init, khiến K8s hiểu lầm là App chết và vả lệnh restart liên tục. **Yêu cầu:** Sửa kịch kim `initialDelaySeconds: 10` cho tất cả các service Go.
- **[🔵 P2] [Cost/FinOps] Phân Bổ Tài Nguyên Cảm Tính Gây Lãng Phí Tiền Mây:** `loyalty-rewards` vẫn bú trọn Limit `1Gi` Memory / `1000m` CPU, quá lãng phí so với 1 service mang tính chất CRUD đơn giản, ngốn gấp đôi search engine Elasticsearch. **Yêu cầu:** Hạ Resource Limit của các dịch vụ nhẹ xuống mức tiêu chuẩn (VD: `512Mi`/`500m`).
- **[🔵 P2] [Clean Code/Naming] Lỗi Đặt Tên Lộn Xộn:** Naming rule K8s đang "múa" tự do. `order-secrets` (số nhiều) đứng cạnh `search-secret` (số ít). **Yêu cầu:** Xóa sạch và thống nhất lại theo chuẩn `<service-name>-secret`.

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm trong vòng Review này).*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Config/Reliability] Vá Lỗi Chí Mạng P0 (Sập Pod Do Thiếu Mount Config):** Chúc mừng đội ngũ Dev! Lỗi ngu ngốc nhất lịch sử (bake thẳng file cấu hình vào Image) đã được gỡ. Các file deployment trước đó (`order`, `loyalty-rewards`) ĐÃ ĐƯỢC THÊM block `volumeMounts` trỏ vào `/app/configs` cùng với khối `volumes`. K8s Pod giờ đây đã đọc config động từ ConfigMap (GitOps).

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. Hiện Trạng Tốt (The Good, The Bad, The Ugly)
Sau khi scan toàn bộ >20 file `deployment.yaml` cho các service API, phát hiện một sự thật đau lòng: **Đội ngũ đã từng có ý định làm Tốt (DRY) nhưng làm dở dang rồi vứt xó.**
- **Bằng chứng:** Có hẳn thư mục `gitops/components/common-deployment/deployment.yaml` chứa một template chuẩn với `PLACEHOLDER_SERVICE_NAME`.
- **Thực Tế Đau Thương:** **Không có một service nào xài Component này đúng cách**. Mọi người tự tiện copy-paste lại 90 dòng mã, tự định nghĩa Label, tự định nghĩa Mounts, tự định nghĩa Resource... Dẫn đến cấu hình phân mảnh hoang tàn!

### 2. Sự Cố Health Probes (P1) Khác Biệt Giữa 2 Thế Giới
Khác với Worker dùng port `8081`, các API Service sử dụng chính HTTP Port của Kratos (VD: `8004`, `8017`) để export `/health/live` và `/health/ready`. Tuy nhiên Time/Delay bị gõ cảm tính:
- Tiêu chuẩn: `order` xài `initialDelaySeconds: 10`, `failureThreshold: 30` (Cho phép tối đa 160s startup). An toàn cho gRPC/DB warmup.
- Lệch chuẩn: `search` / `loyalty-rewards` nã `initialDelaySeconds: 0`. K8s vả request từ giây 0.
- **Thảm họa Base:** Template chuẩn `common-deployment` thâm chí KHÔNG CÓ `startupProbe`. Nguy cơ CrashLoop cực độ khi Pod bị thắt cổ chai CPU lúc Boot.

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
- Kratos cung cấp endpoint xịn là `/health/live` và `/health/ready`. Tuyệt đối không xài lại `/health` rỗng tuếch. Cập nhật thẳng vào Base template.
- Fix cứng `startupProbe.initialDelaySeconds: 10` cho mọi kịch bản Go. Tiết kiệm tài nguyên không có nghĩa là keo kiệt 10 giây nạp đạn của hệ thống.
- Chế tài: Đưa Kustomize Linter/Kubeconform vào luồng CI (GitHub Actions/GitLab CI). Mọi PR lách luật đẩy tệp `deployment.yaml` lên sẽ bị chặn (Block) lập tức.
