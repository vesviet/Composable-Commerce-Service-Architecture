# 🏗️ Báo Cáo Phân Tích & Code Review: Kiến Trúc GitOps & Infrastructure (Senior TA Report)

**Dự án:** E-Commerce Microservices  
**Chủ đề:** Review Tổng thể Kiến trúc Kustomize, ArgoCD, Quản lý Secret và High Availability.  
**Đường dẫn tham khảo:** `gitops/`
**Trạng thái Review:** Lần 1 (Pending Refactor - Theo chuẩn Senior Fullstack Engineer)

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🔴 P0] [Deployment] Thảm Họa ArgoCD SyncError (Kustomize Placeholders):** Kiểm tra file `gitops/apps/auth/base/kustomization.yaml` cho thấy các biến rác như `PLACEHOLDER_SERVICE_NAME` vẫn tòn tại sờ sờ rành rành ở phần patches. Kustomize JSONPatch này sẽ làm ArgoCD nổ lỗi SyncError vì K8s từ chối cấp phát Deployment có kí tự in hoa mâu thuẫn. *Yêu cầu: Hard-Requirement, phải xoá sạch các file kustomization lỗi này và thay bằng hard-coded values cho từng service.*
- **[🟡 P1] [Security / Documentation] Sự Lệch Pha Kiến Trúc Về Secrets:** File `gitops/README.md` vẫn đang chém gió là hệ thống dùng "External Secrets integration" fetch từ Vault. Nhưng thực tế thư mục `gitops/infrastructure/security/` lại chứa Bitnami Sealed Secrets. *Yêu cầu: Lựa chọn 1 trong 2 và sửa lại Docs cho khớp với thực tế. Không được để documentation dối lừa kỹ sư mới.*
- **[🔵 P2] [Clean Code] Mảnh vỡ Deployment thủ công:** Một số service như `order` vẫn giữ file deployment.yaml thay vì inherit từ `common-deployment`.

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm ngoài scope của TA report ban đầu)*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Config/Reliability] Vá lỗi Sập Pod do Hardcode Config:** May mắn là tại `gitops/apps/order/base/deployment.yaml`, dev đã bổ sung đoạn `volumeMounts: name: config` trỏ xuống `/app/configs`. Lỗi P0 CrashLoopBackOff do không tìm thấy file config.yaml đã được bứng gốc tại môi trường dev.

---

## 📋 Chi Tiết Phân Tích (Original TA Report)

## 1. Hiện Trạng Kiến Trúc Tổng Quan
Hệ thống GitOps được xây dựng dựa trên mô hình **App-of-Apps** cực kỳ chuẩn mực của ArgoCD (nằm tại `gitops/bootstrap/`). Cấu trúc thư mục chia tách rõ ràng giữa `apps/` (Base Manifests), `environments/` (Production/Dev overrides), `components/` (DRY templates) và `infrastructure/` (Core services như Dapr, DB).

**Điểm Sáng (The Good):**
- ✅ **Production Overlays & HPA:** Setup cho môi trường Production cực kỳ bài bản. HPA được cấu hình chuẩn xác (Scale up khi CPU > 70%, RAM > 80%, có `stabilizationWindowSeconds` để chống thrashing).
- ✅ **Worker Dependency Checks:** Các Worker node được setup với `initContainers` (như `wait-for-postgres` và `wait-for-redis`), giúp triệt tiêu hoàn toàn lỗi CrashLoopBackOff khi cụm mới khởi động.

---

## 2. Các Lỗ Hổng Kiến Trúc & Vấn Đề Vận Hành (Critical Smells) 🚩

Mặc dù bộ khung xương rất xịn, nhưng quá trình triển khai thực tế đang mắc phải những lỗi chí mạng đi ngược lại nguyên lý cốt lõi của DevOps:

### 🚨 2.1. LỖI P0: Sập Toàn Hệ Thống Do Hardcode Config (CrashLoopBackOff)
Lỗi này đã được nhắc đến chi tiết trong `gitops_api_deployment_analysis_report.md`, nhưng xin nhấn mạnh lại từ góc độ Infrastructure:
- Đội ngũ đã tạo ra `components/common-deployment` cực kỳ chuẩn (setup sẵn SecurityContext `runAsNonRoot`, chuẩn hoá Dapr annotations, v.v.).
- Tuy nhiên, chỉ có một số ít service (như `auth`) sử dụng nó. Các service lõi như `order`, `search` tự tách ra xài `deployment.yaml` riêng lẻ.
- Tệ hơn, các manifest thủ công này **QUÊN mount Volume ConfigMap**. Hệ quả trên Live Cluster: Hàng loạt các Pods (`order`, `loyalty-rewards`, `customer`, v.v.) hiện đang dính `CrashLoopBackOff` với lỗi tồi tệ nhất: `panic: failed to read config file /app/configs/config.yaml: no such file or directory`. Điều này vô hiệu hoá hoàn toàn sức mạnh của GitOps: *bạn không thể đổi cấu hình DB hay config app nếu không trigger CI build lại Image.*

### 🚨 2.2. LỖI P0: Thảm Họa ArgoCD SyncError (Kustomize Placeholders)
Đối với nhóm service có xài Component `common-deployment` (ví dụ `auth`), template lại chứa đầy các biến rác `PLACEHOLDER_SERVICE_NAME` và `PLACEHOLDER_HTTP_PORT`.
- Chức năng Kustomize `jsonPatch` được dùng dở dang, thay thế thiếu hụt các biến ở các layer quá sâu như: `envFrom[1].secretRef.name`, `livenessProbe.httpGet.port`, và `startupProbe.httpGet.port`.
- Hệ quả thực tế trên Cluster: **ArgoCD tê liệt hoàn toàn (Degraded & OutOfSync)** do K8s API từ chối áp dụng (validate) các chuỗi in hoa hoặc chuỗi Text không đúng format port: `Invalid value: "PLACEHOLDER_HTTP_PORT": must be no more than 15 characters`. Nhiều Worker bị treo ở trạng thái `CreateContainerConfigError`.

### 🟡 2.2. LỖI P1: Sự Lệch Pha Kiến Trúc (Documentation Drift) Về Secrets
Có một sự mâu thuẫn khổng lồ giữa Thiết kế (Design) và Thực thi (Implementation):
- **Tài liệu gốc (`gitops/README.md`):** Tự hào tuyên bố *"All credentials fetched from Vault via External Secrets operator"*.
- **Thực tế mã nguồn (`gitops/infrastructure/security/`):** Hệ thống đang chạy bằng **Bitnami Sealed Secrets**. Các key được mã hoá RSA-2048 và commit thẳng file `.yaml` lên Git (`gitops/infrastructure/security/sealed-secrets/`).
- **Hệ luỵ:** Lỗi lệch pha tài liệu gây hiểu lầm cực lớn cho kỹ sư mới. Nếu tổ chức thực sự có Vault Server, việc dùng Sealed Secrets là bước lùi về mặt quản trị tập trung (Audit log, dynamic secrets). Nếu tổ chức không có Vault, dòng Docs kia cần bị xoá bỏ lập tức.

### 🟡 2.3. LỖI P1: Thiếu Chuẩn Hoá Health Probes
Dù `common-deployment` có định nghĩa `startupProbe`, `livenessProbe` rất kỹ để nhường thời gian cho ứng dụng warm-up (Wire DI, DB Connection), việc các service tự ý tách ra viết Deployment riêng lẻ đã làm nát chuẩn này. Có service đánh probe ngay từ giây thứ `0`, dẫn đến tình trạng K8s liên tục vả HTTP request vào một App còn chưa boot xong, gây false-positive restart.

---

## 3. Lời Khuyên & Action Items (Refactoring Plan)

Với vai trò Senior Technical Architect, tôi đề xuất Roadmap đập đi xây lại như sau:

**Giai đoạn 1: Fix lỗi Configuration Lifecycle (P0)**
- Quét toàn bộ `gitops/apps/*`. Service nào không có khối `volumeMounts` trỏ vào `/app/configs`, phải bổ sung ConfigMap Overlay ngay lập tức. Cấm tuyệt đối hành vi config cứng vào image.

**Giai đoạn 2: Hợp Nhất Kustomize Component (P1)**
- Xoá sổ toàn bộ các file `deployment.yaml` rác nằm trong `apps/*/base/`.
- Ép toàn bộ 17 services phải thừa kế (inherit) từ `gitops/components/common-deployment` thông qua cấu trúc thư mục Patching của Kustomize. Mọi service chỉ được phép chèn đè Name, Image, và Port.

**Giai đoạn 3: Giải Quyết Kiến Trúc Secret (P1)**
- CTO hoặc Tech Lead phải chốt: Dự án dùng **Vault + External Secrets** hay **Sealed Secrets**?
  - Nếu dùng Sealed Secrets: Xoá đoạn nói dối trong `README.md`. Bổ sung script chạy Auto Rotate Sealed Keys mỗi năm 1 lần.
  - Nếu dùng Vault: Phải phế truất tháo gỡ Bitnami Sealed Secrets Controller, và bootstrap External Secrets đâm vào Vault URL.
