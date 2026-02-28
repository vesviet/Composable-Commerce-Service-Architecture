# Báo Cáo Phân Tích GitOps Worker Config (Senior TA Report)

**Dự án:** E-Commerce Microservices  
**Chủ đề:** Review Config GitOps (Kubernetes Deployment) của các Worker Node  
**Đường dẫn tham khảo:** `gitops/apps/*/base/worker-deployment.yaml`

---

## 1. Index Toàn Cảnh (GitOps Architecture)

Worker của mỗi service đang được deploy qua Kustomize `base` và overlay (có kèm HPA ở production overlay). Tổng cộng có hơn 20 file `worker-deployment.yaml`.
Sau khi review chi tiết 5 service đại diện (`analytics`, `search`, `order`, `loyalty-rewards`, `gateway`), dưới đây là cấu trúc chung đang được áp dụng:

1. **Deployment Specs:**
   - Dùng chung `argocd.argoproj.io/sync-wave: "8"` (Triển khai sau infra, DB, Redis).
   - SecurityContext: Chuẩn hoá `runAsNonRoot: true` và `runAsUser: 65532`.
2. **Commands & Args:**
   - Dùng script shell bọc ngoài để tăng file descriptors: `ulimit -n 65536 || true`
   - Gọi binary: `exec /app/bin/worker -conf /app/configs/...`
3. **Configs Mappings:**
   - Dùng `envFrom` trỏ vào `overlays-config` configMap và `<service>-secrets` secret.
   - Map volume config vào `/app/configs`.
4. **Health Port:** Standardized port `8081` mang tên `health`.

---

## 2. Các Vấn Đề Và Điểm Bất Đồng Nhất (Inconsistencies & Smells) 🚩

Mặc dù có chung pattern, nhưng việc copy-paste các file YAML này qua từng service đã gây ra một hệ luỵ lớn về **tính nhất quán (inconsistency)** giữa các file.

### 🚩 2.1. Lỗi Cấu Hình Dapr (Dapr Annotations)
Hầu hết các service giao tiếp qua Dapr Event-Driven, do đó worker dùng Dapr là điều cốt lõi. Tuy nhiên cấu hình annotations đang không đồng bộ:
*   `search`, `order`, `loyalty-rewards`, `gateway` đều khai báo chuẩn:
    *   `dapr.io/enabled: "true"`
    *   `dapr.io/app-port: "5005"`
    *   `dapr.io/app-protocol: "grpc"`
*   🚨 **ĐÁNG BÁO ĐỘNG:** Thằng `analytics` lại **BỎ QUÊN** `app-port` và `app-protocol`. Nếu Dapr Actor hoặc PubSub cần gọi ngược lại grpc/http server của worker, sidecar của analytics sẽ không biết mở port nào!
*   `gateway` có định nghĩa thêm `log-level` và `graceful-shutdown-seconds`, trong khi các service khác thì không.

### 🚩 2.2. Sự Loạn Loạn Của Health Probes
Dù tất cả đều chạy một `HealthServer` ở port `8081` theo code Go, nhưng cấu hình Kubernetes Probes lại đang **"mỗi nhà một kiểu"**:
*   `analytics` & `search`: Dùng HTTP GET `/healthz` trên port `health` (8081) với thời gian đợi mặc định.
*   `order`: Có thêm `startupProbe` sử dụng TCP Socket ở port `grpc-svc` trong 195s (cho phép app khởi động chậm vì chần chừ đợi Consul).
*   🚨 **LỖI NGHIÊM TRỌNG Ở LOYALTY-REWARDS:** Lại đi khai báo `grpc` probe ở port `5005` (`grpc: port: 5005`). Điều này cực kỳ nguy hiểm bởi worker không phải lúc nào cũng chạy một GRPC server đầy đủ. Code Go thì start HTTP Health Check port 8081 nhưng YAML k8s lại đi ping GRPC port 5005!
*   `gateway`/`analytics`: Probe lại có block cấu hình `timeoutSeconds` khác với các service còn lại.

### 🚩 2.3. Thiếu Tuân Thủ Tiêu Chuẩn Naming Secret/Config
*   Hầu hết secret được đánh tên dạng theo format số nhiều: `<service>-secrets` (VD: `analytics-secrets`, `order-secrets`, `loyalty-rewards-secrets`).
*   Một số lại là số ít: `<service>-secret` (VD: `search-secret`, `gateway-secret`). Lỗi chính tả nhỏ này trong GitOps Ops sẽ dẫn tới Mount Error khi ArgoCD deploy.
*   Tên config file lúc thì `/app/configs/config.yaml`, riêng gateway lại là `/app/configs/gateway.yaml`.

### 🚩 2.4. Sự Không Đồng Nhất Của Init Containers
Một worker thường phải đợi CSDL và Message Queue up.
*   `search`, `order`, `loyalty-rewards`: Đòi đủ 3 InitContainers (`wait-for-consul`, `wait-for-redis`, `wait-for-postgres`).
*   `analytics`: Chỉ đợi postgres và redis.
*   `gateway`: **KHÔNG CÓ InitContainer nào**. Có thể gây crash loop liên tục khi cụm mới start up mà RabbitMQ/Redis chưa sẵn sàng.

### 🚩 2.5. Tham Số `-mode` Lúc Khác Nhau Lúc Biến Mất
Dù Worker Code đều implement cờ `--mode`, GitOps lại truyền rất tuỳ ý:
*   `analytics`: `-mode all`
*   `loyalty-rewards`: `-mode event`
*   `search`, `order`: Hoàn toàn **khoa không truyền cờ `-mode`**, khiến hệ thống fallback về giá trị default trong code Go tùy tiện.

---

## 3. Lời Khuyên & Action Items Cho Đội DevOps / Kỹ Sư Hệ Thống

Đứng dưới góc nhìn Clean Architecture và GitOps thuần thục, việc duy trì >20 file `worker-deployment.yaml` thủ công này là Technical Debt lớn.

### ✅ Giải pháp Kustomize Kế Thừa (DRY in GitOps)
**Thay thế toàn bộ bằng 1 Base duy nhất!**
Chúng ta đã dùng Kustomize, tại sao không tạo một base template cho **ALL WORKERS** ở `gitops/apps/common-bases/worker/deployment.yaml` chứa đủ Probes, Args, Dapr annotations.

Từ `gitops/apps/<service>/base/kustomization.yaml`, chỉ cần dùng Patching:
1. Sửa `name` (thông qua `namePrefix` hoặc `nameSuffix` của kustomization).
2. Override `volumeMounts` hoặc `secrets` via kustomize patches.
3. Nếu cần Custom InitContainer thì vá vào qua file patch riêng.

### 📋 Checklist Khắc Phục Khẩn Cấp (P0 - Blocking Sync):
- [ ] **Liveness/Readiness Probes**: Gạch bỏ GRPC probe trong `loyalty-rewards` worker và đổi toàn bộ sang `httpGet /healthz port 8081`.
- [ ] **Dapr Annotations**: Bổ sung `dapr.io/app-port: "5005"` (hoặc port tương ứng) và `dapr.io/app-protocol: "grpc"` cho tất cả các worker, gồm cả `analytics`.
- [ ] **Arguments Consistency**: Explicitly define `-mode event` (hoặc `all`, `cron`) vào `args` block thay vì bỏ qua cho default logic của code.
- [ ] **Init Containers**: Tuẩn chuẩn hóa Init Containers (PostgreSQL, Redis) thành common components trong kustomize base, mọi worker đều phải tuân thủ để tránh restart crash backoff.
