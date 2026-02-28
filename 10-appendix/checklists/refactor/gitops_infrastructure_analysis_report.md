# 📋 Báo Cáo Phân Tích & Code Review: Kiến Trúc GitOps & Infrastructure

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Review Tổng thể Kiến trúc Kustomize, ArgoCD, Quản lý Secret và High Availability.  
**Đường dẫn tham khảo:** `gitops/`  
**Trạng thái Review:** Đã Review - Cần Refactor Lập Tức  

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🚨 P0] [Deployment/ArgoCD] Thảm Họa ArgoCD SyncError (Kustomize Placeholders):** Kiểm tra file `gitops/apps/auth/base/kustomization.yaml` cho thấy các biến rác như `PLACEHOLDER_SERVICE_NAME` vẫn tồn tại sờ sờ rành rành ở phần patches. Kustomize JSONPatch này sẽ làm ArgoCD nổ lỗi SyncError vì K8s từ chối cấp phát Deployment có kí tự in hoa mâu thuẫn. **Yêu cầu (Hard-Requirement):** Phải xoá sạch các file kustomization lỗi này và thay bằng hard-coded values cho từng service ngay lập tức.
- **[🟡 P1] [Security/Documentation] Sự Lệch Pha Kiến Trúc Về Secrets:** File `gitops/README.md` vẫn đang chém gió là hệ thống dùng "External Secrets integration" fetch từ Vault. Nhưng thực tế thư mục `gitops/infrastructure/security/` lại chứa Bitnami Sealed Secrets. **Yêu cầu:** Lựa chọn 1 trong 2 và sửa lại Docs cho khớp với thực tế. Không được để documentation dối lừa kỹ sư mới.
- **[🔵 P2] [Clean Code/DRY] Mảnh Vỡ Deployment Thủ Công:** Một số service như `order` vẫn giữ file `deployment.yaml` riêng rẻ thay vì kế thừa (inherit) từ `common-deployment`. Mây mưa mã nguồn rác rải rác. **Yêu cầu:** Quy về một mối duy nhất.

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm trong vòng Review này).*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Config/Reliability] Vá Lỗi Sập Pod Do Hardcode Config:** May mắn là tại `gitops/apps/order/base/deployment.yaml`, dev đã bổ sung đoạn `volumeMounts: name: config` trỏ xuống `/app/configs`. Lỗi P0 CrashLoopBackOff do không tìm thấy file `config.yaml` đã được bứng gốc tại môi trường dev.

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. Hiện Trạng Tốt (The Good)
Hệ thống GitOps được xây dựng dựa trên mô hình **App-of-Apps** cực kỳ chuẩn mực của ArgoCD (nằm tại `gitops/bootstrap/`). Cấu trúc chia tách rất rõ ràng: `apps/` (Base), `environments/` (Production/Dev overrides), `components/` (DRY templates) và `infrastructure/`.
- **Production Overlays & HPA:** Cấu hình chuẩn xác (Scale up khi CPU > 70%, RAM > 80%, có `stabilizationWindowSeconds` để chống thrashing).
- **Worker Dependency Checks:** Các Worker node được bảo vệ bởi `initContainers` (`wait-for-postgres` và `wait-for-redis`), giúp triệt tiêu hoàn toàn lỗi CrashLoopBackOff lãng xẹt khi cụm mới khởi động.

### 2. Các Lỗ Hổng Kiến Trúc Chí Mạng (P0, P1) 🚩

#### 🚩 2.1 LỖI P0: Thảm Họa ArgoCD SyncError (Kustomize Rác)
Đối với nhóm service có xài Component `common-deployment` (ví dụ `auth`), template đang chứa đầy các biến rác `PLACEHOLDER_HTTP_PORT`. Chức năng Kustomize `jsonPatch` được dùng dở dang, thay thế thiếu hụt ở các layer sâu (`livenessProbe.httpGet.port`).
**Hậu quả trên Cluster:** API của Kubernetes từ chối Validate chuỗi in hoa hoặc format sai: `Invalid value: "PLACEHOLDER_HTTP_PORT"`. ArgoCD báo lỗi vỡ mặt (Degraded & OutOfSync). Dây chuyền CD đứt gãy hoàn toàn.

#### 🚩 2.2 LỖI P1: Thảm Họa Sự Lệch Pha Kiến Trúc Mật Mã (Secrets)
Sự lừa dối trong tài liệu kiến trúc:
- **Tài liệu (`README.md`):** Tự hào rêu rao *"All credentials fetched from Vault via External Secrets operator"*.
- **Thực tế mã nguồn (`security/`):** Hệ thống đang chạy bằng **Bitnami Sealed Secrets**. Các key RSA-2048 bị ne ném thẳng lên mâm Git. Mọi kỹ sư có quyền Read đều thọc tay vào được.
**Hậu quả:** Nếu dự án thực sự có Vault Server, việc dùng Sealed Secrets là bước lùi về mặt Audit log. Nếu không có Vault, dòng Docs trên là tội ác.

#### 🚩 2.3 LỖI P1: Thiếu Chuẩn Hoá Health Probes Ở Các Service Lẻ
`common-deployment` đã định nghĩa `startupProbe`, `livenessProbe` cực kỳ khôn ngoan để nhường thời gian cho DB Connection được khởi tạo (Warm-up). Lẽ ra mọi service phải tuân theo chuẩn này. Việc các service lẻ tẻ tự tách ra viết Deployment riêng đã phá hỏng Probe, dẫn đến tình trạng K8s liên tục vả HTTP request vào một App còn chưa boot xong, gây false-positive restart (Khởi động lại oan uổng).

### 3. Giải Pháp Chỉ Đạo Từ Senior
Ngay lập tức thực thi chuỗi hành động "Khắc Phục Hậu Quả":

1. **Dập Tắt SyncError (P0):** Quét sạch toàn bộ `gitops/apps/*/base/kustomization.yaml`. Gỡ bỏ kiểu jsonPatch vá víu lỗi bằng những tham số String rác rưởi. Hard-code rõng rạc port và tên service ở Base, hoặc Patch đúng đường dẫn YAML.
2. **Quy Quy Hoạch Deploy (P2 -> P0 trong tương lai):** Ép toàn bộ 17+ services phải thừa kế (inherit) từ `gitops/components/common-deployment` thông qua Patching của Kustomize. Mọi service chỉ được phép chèn đè đúng Name, Image, và Container Port. Xóa không thương tiếc `deployment.yaml` lẻ tẻ rác bẩn.
3. **Phán Quyết Bí Mật (P1):** CTO / Technical Lead cần xác nhận 1 là đi đường Sealed Secrets, 2 là chạy Vault External. Sửa tài liệu tức tốc. Đừng khiến DevOps mới vào khóc thét khi mò theo tài liệu sai sự thật.
