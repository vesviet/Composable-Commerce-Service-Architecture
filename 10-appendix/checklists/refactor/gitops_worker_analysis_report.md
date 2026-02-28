# 📋 Báo Cáo Phân Tích & Code Review: GitOps Worker Config

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Review Config GitOps (Kubernetes Deployment) của các Worker Node.  
**Đường dẫn tham khảo:** `gitops/apps/*/base/worker-deployment.yaml`  
**Trạng thái Review:** Đã Review - Cần Refactor Lập Tức  

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🚨 P1] [Architecture/DRY] Sự Phân Mảnh Rác Rưởi Của Worker Manifests:** Giống y hệt bên API Deployment, các file `worker-deployment.yaml` vẫn đang bị copy-paste thủ công 100 dòng cho hơn 20 services. Cần dọn dẹp và gom về màn Kustomize base chung duy nhất tại `components`. Không được phép duy trì Technical Debt này nữa.
- **[🔵 P2] [Clean Code/Naming] Lỗi Naming Secret & Thiếu Nhất Quán Init Container:** Lỗi chính tả tên secret số ít/nhiều (`search-secret` vs `order-secrets`), và việc thiếu định hướng rõ ràng về InitContainers (`gateway` không hề có, `analytics` lại thiếu consul) phô bày sự thiếu chuyên nghiệp trong vận hành. **Yêu cầu:** Thống nhất đặt tên chuẩn `<service-name>-secret`.
- **[🔵 P2] [Clean Code/Runtime] Tham Số `-mode` Tuỳ Hứng:** Worker Go hỗ trợ cờ `-mode event/cron/all`. Nhưng `search` và `order` lại thả nổi biến `args` gieo xúc xắc cho default logic của code, trong khi `analytics` thì truyền rõ ràng. **Yêu cầu:** Bắt buộc truyền `-mode` tường minh vào mọi file YAML.

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm trong vòng Review này).*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Reliability] Vá Lỗi Sập Health Check Ở Loyalty-Rewards:** Đáng khen ngợi, Worker của `loyalty-rewards` đã được sửa lại: Gạch bỏ hoàn toàn probe chạy nhầm vào GRPC port `5005` chết người trước đó, chuyển về chuẩn HTTP `httpGet` vào `/healthz` port `8081`. Pod đã khởi động mượt mà không bị K8s vả chết oan.
- **[FIXED ✅] [Dapr/Comm] Vá Lỗi Mất Cấu Hình Dapr Ở Analytics:** Nửa đêm sidecar không biết gọi cổng nào? Lỗi này ĐÃ FIXED khi Worker `analytics` được bổ sung đầy đủ khối annotation `dapr.io/app-port` và `app-protocol`. Dapr sidecar giờ đã biết trỏ luồng pubsub về đâu.

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. Hiện Trạng Tốt (GitOps Architecture)
Worker của mỗi service đang được triển khai qua Kustomize `base` và environment overlays. Điểm sáng chung:
- **Deployment Specs:** Đồng bộ dùng `argocd.argoproj.io/sync-wave: "8"` (Đảm bảo Worker chỉ boot lên khi Core Infra Postgres/Redis đã sống).
- **SecurityContext:** Chuẩn hoá `runAsNonRoot: true` và `runAsUser: 65532`. Rất an toàn.
- **File Descriptors:** Chịu khó bọc bash script để đẩy `ulimit -n 65536`. Đủ tải C10K.
- **Health Port:** Standardized port `8081` chuyên dụng cho Liveness/Readiness. Tách biệt hẳn luồng Business. Rất Tốt.

### 2. Sự Cẩu Thả Gây Nguy Hiểm Hệ Thống 🚩
Việc dung túng thói quen copy-paste file YAML qua từng service đã gây ra một hệ luỵ Inconsistency cực kỳ đau đầu:

#### 🚩 2.1. Quên Cấu Hình Dapr Annotations
Worker sống nhờ Dapr (Event-Driven), dĩ nhiên Dapr Sidecar là mạch máu.
- Service `search`, `order` khai báo chuẩn: `dapr.io/enabled: "true"`, `dapr.io/app-port: "5005"`, `dapr.io/app-protocol: "grpc"`.
- Nhưng `analytics` (trước khi fix) lại BỎ QUÊN `app-port` và `app-protocol`. Đây là lỗi sinh tử (P0) nếu Dapr cần gọi ngược lại ứng dụng. Dẫn đến thất thoát Message Pub/Sub. Hệ thống đã fixed nhưng quy trình kiểm duyệt PR lỏng lẻo đang bị cảnh báo.

#### 🚩 2.2. Sự Loạn Luân Của Health Probes
Dù tất cả đều chạy `HealthServer` HTTP port `8081`. Nhưng K8s Probes lại "mỗi nhà một kiểu":
- Chuẩn: `analytics` & `search` dùng HTTP GET `/healthz` port `8081`.
- Rườm rà: `order` tự kẹp thêm `startupProbe` gọi Socket TCP cực kỳ khó hiểu.
- Thảm Họa (đã fix): `loyalty-rewards` từng đi khai báo Probe bắn vào Cổng gRPC `5005`. Mà Worker thì có lúc không chạy gRPC Server -> Pod bị K8s bóp cổ chết liên hoàn.

#### 🚩 2.3 Sự Không Đồng Nhất Của Init Containers
App boot lên mà thiếu DB thì Crash. InitContainers sinh ra để giải quyết. Nhưng:
- `search`, `order`: Tháo vát chèn đủ 3 thằng đợi (`wait-for-consul`, `redis`, `postgres`).
- `analytics`: Lười, bỏ qua Consul.
- `gateway`: Vô tư KHÔNG CÓ cái InitContainer nào. Hậu quả là hễ Deploy Cụm là gateway đỏ lòm vài phút đầu chờ RabbitMQ.

### 3. Giải Pháp Chỉ Đạo Từ Senior
Đứng dưới góc nhìn Clean Architecture và GitOps thuần thục, việc duy trì >20 file thủ công này là Technical Debt nợ nần ngập đầu.

**Xóa Bỏ Kỉ Nguyên Copy-Paste Bằng Kustomize Kế Thừa (DRY in GitOps)**
- **Xây Dựng Base Vàng:** Cần ngay 1 Base template cho **ALL WORKERS** tại `gitops/components/common-worker-deployment/deployment.yaml`. Chứa đủ Probes chuẩn `8081`, InitContainers xịn sò nhất, và Dapr annotations chuẩn gRPC.
- **Patch Để Cá Nhân Hóa:** Từ `gitops/apps/<service>/base/kustomization.yaml`, dev chỉ được quyền dùng Patching để ghi đè Tên file cấu hình, Secret Name, và `-mode`. Không được phép chọc ngoáy vào sức khỏe Health Probes.
