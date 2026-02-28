# Báo Cáo Phân Tích K8s Policies & Resource Ordering (Senior TA Report)

**Dự án:** E-Commerce Microservices  
**Chủ đề:** Review cấu trúc Deployments Ordering (ArgoCD Sync-Waves) và các Policies (HPA, PDB, NetworkPolicy).  

---

## 1. Phân Tích Thứ Tự Deploy (ArgoCD Sync-Wave) 🌊

Hệ thống đang sử dụng ArgoCD `sync-wave` annotations khá bài bản để dàn xếp thứ tự khởi động (boot sequence) của toàn bộ namespace, tránh tình trạng giẫm chân lên nhau. Dưới đây là kiến trúc phân lớp hiện tại được bóc tách từ GitOps code:

| Wave (Thứ tự) | Nhóm Component | File Tham Chiếu Tiêu Biểu | Đánh Giá (Review) |
| :--- | :--- | :--- | :--- |
| **-5** | `Secret` | `secret.yaml` | Rất chuẩn xác. Credential phải có mặt đầu tiên. |
| **-1** | `ServiceAccount` | `serviceaccount.yaml` | Chuẩn bị RBAC permissions cho Pods. |
| **0** | `ConfigMap`, `NetworkPolicy`, `ServiceMonitor` | `configmap.yaml`, `networkpolicy.yaml` | Chuẩn. Khởi tạo cấu hình tĩnh và rules bảo mật trước khi Pod mọc lên. |
| **1** | `Job` (DB Migration) | `migration-job.yaml` | **Tuyệt vời.** DB Schema phải được `up` xong trước khi App start để tránh schema mismatch crash. |
| **2 -> 4** | `Service` (ClusterIP) | `service.yaml` | Khai báo Service trước để K8s ghim IPs/DNS cho các Pod sắp tới. |
| **3 -> 6** | `Deployment` (API Server chính) | `deployment.yaml` | API Server bắt đầu mọc lên. |
| **7** | `HPA` (cho API Server) | `hpa.yaml` | Cấu hình Auto-scaling sau khi Pod chính đã ổn định. |
| **8** | `Deployment` (Worker) | `worker-deployment.yaml` | **Hợp lý.** Worker mọc sau API ngụ ý Worker phụ thuộc hoặc nhường tài nguyên boot cho API Server. |
| **9** | Public Services / Ingress | (Một số service đặc thù) | Gateway/Ingress mở cửa sau cùng khi mọi backend đã ready. |

### 💡 Khuyến nghị về Sync-Wave:
Logic Wave hiện tại rất vững (Solid). Kubernetes/ArgoCD sẽ tự block Deploy API nếu Wave 1 (Migration Job) failed. Giữ nguyên cấu trúc này.

---

## 2. Review Kubernetes Policies (HPA, PDB, Network Policy) 🛡️

Mặc dù base logic là đúng, nhưng do lỗi "Copy-Paste Manifests" (như đã phân tích ở phần Deployment), các policies này đang bị phân mảnh và dư thừa.

### 2.1. Horizontal Pod Autoscaler (HPA)
- **Cấu hình hiện tại:** Đa số các service set ngưỡng `CPU: 70%` và `Memory: 80%`. Scale down/up behavior được define rõ ràng với `stabilizationWindowSeconds`. Khá xịn xò.
- **Vấn đề (P1):** File `hpa.yaml` nằm trơ trọi ở `base/`. HPA thường đi kèm với môi trường `production` hoặc `staging`, việc ném thẳng vào `base` ép môi trường `dev` (trên máy local k3d) cũng phải chạy HPA (với minReplicas=2). Sẽ làm tốn RAM vô ích ở local dev.
- **Giải pháp:** Xoá `hpa.yaml` ở `base/`. Chỉ inject HPA thông qua `overlays/production/hpa.yaml`.

### 2.2. Pod Disruption Budget (PDB)
- **Cấu hình hiện tại:** `minAvailable: 1`
- **Đánh giá:** Rất an toàn. Đảm bảo cluster rollout / node drain không bao giờ kill 100% replicas của một service cùng lúc.
- **Vấn đề:** 15 service là 15 file `pdb.yaml` copy hệt nhau.

### 2.3. Network Policy (Zero-Trust)
- **Cấu hình hiện tại:** Hệ thống đang làm khá tốt Zero-trust. Default deny ALL, chỉ allow `Ingress` từ Gateway hoặc các service gọi trực tiếp (ví dụ: `order` cho phép cổng từ `payment`, `fulfillment`). `Egress` chỉ cho phép chọc ra các service đích và port 80/81.
- **Vấn đề (P0 - Security Risk):** Do copy-paste, cấu hình Ingress/Egress đang bị đóng băng tĩnh (`hardcoded namespaces`: `payment-dev`, `fulfillment-dev`). Giả sử ta deploy overlay `production` sang namespace `order-prod`, rules NetworkPolicy vẫn matching với cái chữ `-dev` kia!. Điều này sẽ làm sập kết nối liên mạng ở prod, hoặc vô tình mở backdoor cho môi trường dev chọc sang prod.
- **Giải pháp:** Xóa hardcode `-dev`. Trong Kustomize, sử dụng tính năng biến môi trường hoán đổi tự động namespace, hoặc thiết kế Labels standard để gán Policy theo Label App thay vì gán chết theo text Tên Namespace.

---

## 3. Tổng Kết Phương Án Kiến Trúc Tương Lai (The GitOps DRY Dream)

Gộp tất cả các report lại (Worker, API, Migration, Policies), đội DevOps đang duy trì hơn **100 file YAML** rác rưởi do nhân bản vô tính.

**Action Item duy nhất và cấp bách nhất:**
Hãy vứt bỏ toàn bộ setup Kustomize hiện tại (vì Kustomize không sinh ra để dùng theo pattern Copy-Paste). Chuyển sang sử dụng **HELM CHART** duy nhất tên là `microservice-standard-chart`.

Một Helm `values.yaml` của service `order` sẽ chỉ còn đẹp như thế này:
```yaml
app:
  name: order
  type: api-and-worker # Tự động render 2 Deployment

migrations:
  enabled: true
  schemaVersionTable: order_goose_db_version # Chống lỗi trùng bảng

autoscaling:
  enabled: true # Chỉ bật ở overlay prod
  minReplicas: 2
  maxReplicas: 8

networkPolicy:
  allowIngressFrom:
    - gateway
    - payment
```
Lúc này GitOps Repo từ 1000 file sẽ co lại thành đúng 1 thư mục Helm Chart và 15 file `values.yaml` sạch sẽ, triệt tiêu 100% lỗi Copy-Paste dớ dẩn.
