# Checklist: Khởi tạo Kubernetes (K8s) và k3d

## 📋 Mục lục
1. [Prerequisites & Installation](#prerequisites--installation)
2. [k3d Setup](#k3d-setup)
3. [Kubernetes Basics](#kubernetes-basics)
4. [Common Operations](#common-operations)
5. [Troubleshooting](#troubleshooting)
6. [Best Practices](#best-practices)

---

## 🔧 Prerequisites & Installation

### System Requirements
- [x] Kiểm tra hệ điều hành (Windows/Linux/macOS)
  - ✅ **Kết quả:** Ubuntu 24.04.3 LTS (Noble Numbat) - Server: 192.168.1.112
- [x] Đảm bảo có quyền admin/root
  - ✅ **Kết quả:** User: `tuananh` (có thể dùng sudo)
- [x] Kiểm tra dung lượng ổ cứng (tối thiểu 20GB free)
  - ✅ **Kết quả:** Ổ chính: 229.8G (nvme1n1p3) - Đủ dung lượng
- [x] Kiểm tra RAM (tối thiểu 4GB, khuyến nghị 8GB+)
  - ✅ **Kết quả:** RAM: 31GB total, 30GB available - Rất tốt

### Resource Planning (K3S Cluster - Single Node)
- [x] **SYSTEM:** 6GB
  - ✅ OS (Ubuntu): 2GB
  - ✅ K3s Components: 2GB
  - ✅ Buffer: 2GB
- [x] **INFRASTRUCTURE:** 12.5GB
  - ✅ PostgreSQL (all DBs): 6GB
  - ✅ Redis: 1.5GB
  - ✅ Elasticsearch: 3GB
  - ✅ RabbitMQ/Dapr: 1.5GB
  - ✅ Consul: 512MB
- [x] **CORE SERVICES (Single Replica):** 9GB
  - ✅ Gateway: 1GB
  - ✅ Auth: 512MB
  - ✅ User: 512MB
  - ✅ Customer: 512MB
  - ✅ Order: 1GB
  - ✅ Payment: 1GB
  - ✅ Catalog: 512MB
  - ✅ Warehouse: 512MB
  - ✅ Shipping: 512MB
  - ✅ Fulfillment: 512MB
  - ✅ Pricing: 512MB
  - ✅ Promotion: 512MB
  - ✅ Loyalty: 512MB
  - ✅ Review: 512MB
  - ✅ Notification: 256MB
  - ✅ Location: 256MB
  - ✅ Search: 512MB
- [x] **MONITORING:** 4.5GB
  - ✅ Prometheus: 2GB (7d retention)
  - ✅ Grafana: 512MB
  - ✅ Loki: 1.5GB (7d retention)
  - ✅ Jaeger: 512MB (memory)
- [x] **TỔNG CỘNG:** ~32GB
  - ✅ **Đánh giá:** Server có 31GB RAM, phù hợp với yêu cầu (có thể cần tối ưu hoặc thêm RAM nếu cần buffer)

### Storage Planning (Multi-Tier Storage Strategy)
- [x] **nvme1n1 (232.9GB) - CURRENT OS DISK:**
  - ✅ Keep as-is (Ubuntu already installed)
  - ✅ `/` (root): 50GB
  - ✅ `/var/lib/docker`: 100GB (move here)
  - ✅ `/var/lib/rancher`: 50GB (K3s data)
  - ✅ Free: ~30GB buffer
- [x] **nvme0n1 (238.5GB) - HOT DATABASES:**
  - ✅ Mount as `/data/hot`
  - ✅ PostgreSQL: 100GB
  - ✅ Redis: 10GB
  - ✅ Elasticsearch (hot): 40GB
  - ✅ Prometheus (0-3d): 30GB
  - ✅ Loki (0-3d): 20GB
  - ✅ Free: ~38GB
  - ⚡⚡⚡ **Performance:** <1ms latency
- [x] **sdb (223.6GB SSD) - WARM DATA:**
  - ✅ Mount as `/data/warm`
  - ✅ Elasticsearch (warm): 80GB
  - ✅ Prometheus (3-7d): 50GB
  - ✅ Loki (3-7d): 40GB
  - ✅ Application cache: 30GB
  - ✅ Free: ~23GB
  - ⚡⚡ **Performance:** <5ms latency
- [x] **sda (931.5GB HDD) - COLD STORAGE:**
  - ✅ Mount as `/data/cold`
  - ✅ Prometheus archive (7-30d): 200GB
  - ✅ Loki archive (7-30d): 150GB
  - ✅ Database backups: 150GB
  - ✅ MinIO/Object Storage: 250GB
  - ✅ Application backups: 50GB
  - ✅ Docker registry cache: 50GB
  - ✅ Free: ~81GB
  - ⚡ **Performance:** ~10ms latency
- [ ] **Storage Setup Tasks:**

#### Step 1: Kiểm tra và xác nhận các ổ đĩa
- [x] Kiểm tra các ổ đĩa: `lsblk -a`
  - ✅ **Kết quả:** 
    - nvme0n1 (238.5G) - Chưa format (HOT)
    - sdb (223.6G) - Chưa format (WARM)
    - sda (931.5G) - Chưa format (COLD)
    - nvme1n1 (232.9G) - Đã sử dụng cho OS
- [x] Kiểm tra filesystem hiện tại: `df -m`
  - ✅ **Kết quả:** Chỉ có nvme1n1 được mount (OS)

#### Step 2: Format các ổ đĩa
- [x] **Format nvme0n1 (HOT - NVMe):**
  - ✅ **Kết quả:** Đã format thành công với ext4
- [x] **Format sdb (WARM - SSD):**
  - ✅ **Kết quả:** Đã format thành công với ext4
- [x] **Format sda (COLD - HDD):**
  - ✅ **Kết quả:** Đã format thành công với ext4

#### Step 3: Tạo mount points và mount
- [x] **Tạo mount points:**
  - ✅ **Kết quả:** Đã tạo thành công
- [x] **Mount các ổ đĩa:**
  - ✅ **Kết quả:** Đã mount thành công
- [x] **Kiểm tra mount:**
  - ✅ **Kết quả:**
    - `/dev/nvme0n1` → `/data/hot` (234G, ext4, 1% used)
    - `/dev/sdb` → `/data/warm` (220G, ext4, 1% used)
    - `/dev/sda` → `/data/cold` (916G, ext4, 1% used)

#### Step 4: Cấu hình /etc/fstab cho auto-mount
- [x] **Lấy UUID của các ổ đĩa:**
  - ✅ **Kết quả:**
    - nvme0n1: `5caf348e-2f96-45d8-a9e1-51550669029c`
    - sdb: `d413e9cf-1d7b-427f-9915-d7e34a1a2bd9`
    - sda: `2be93147-eaf2-480b-a9a1-5d27e7f322f0`
- [x] **Backup /etc/fstab:**
  - ✅ **Kết quả:** Đã backup (hoặc đã cấu hình)
- [x] **Thêm entries vào /etc/fstab:**
  - ✅ **Kết quả:** Đã thêm thành công các entries:
    - UUID=5caf348e-2f96-45d8-a9e1-51550669029c → /data/hot
    - UUID=d413e9cf-1d7b-427f-9915-d7e34a1a2bd9 → /data/warm
    - UUID=2be93147-eaf2-480b-a9a1-5d27e7f322f0 → /data/cold
  
  **Giải thích các tham số:**
  - `defaults`: Sử dụng các mount options mặc định (rw, suid, dev, exec, auto, nouser, async)
  - `noatime`: Không update access time (tăng performance)
  - `0`: Không dump filesystem
  - `2`: Filesystem sẽ được kiểm tra bằng fsck ở lần boot thứ 2 (sau root filesystem)
- [x] **Test fstab configuration:**
  - ✅ **Kết quả:** Test thành công, không có lỗi
    - `/dev/nvme0n1` → `/data/hot` (234G, 1% used)
    - `/dev/sdb` → `/data/warm` (220G, 1% used)
    - `/dev/sda` → `/data/cold` (916G, 1% used)
  - ✅ **Kết luận:** Các ổ đĩa sẽ tự động mount khi reboot

#### Step 5: Tạo cấu trúc thư mục cho services
- [x] **Tạo thư mục cho HOT storage (/data/hot):**
  - ✅ **Kết quả:** Đã tạo thành công
    - postgresql, redis, elasticsearch-hot, prometheus-hot, loki-hot
  - [x] **Kiểm tra UID/GID hiện có:**
    - ✅ **Kết quả:** 
      - UID 999: dnsmasq (đã được sử dụng)
      - UID 1000: tuananh (đã được sử dụng)
  - [ ] **Giải pháp Ownership:**
    
    **Option 1: Để root và để Kubernetes tự quản lý (Recommended)**
    - Khi deploy trong Kubernetes, containers sẽ chạy với SecurityContext riêng
    - Kubernetes sẽ tự động set ownership khi mount volumes
    - Giữ ownership hiện tại (root) hoặc:
      ```bash
      sudo chown -R root:root /data/hot/*
      ```
    
    **Option 2: Tạo các user/group riêng (Nếu cần)**
    ```bash
    # Tạo postgres user/group (UID 1001)
    sudo groupadd -g 1001 postgres
    sudo useradd -u 1001 -g 1001 -r -s /bin/false postgres
    
    # Tạo redis user/group (UID 1002)
    sudo groupadd -g 1002 redis
    sudo useradd -u 1002 -g 1002 -r -s /bin/false redis
    
    # Tạo elasticsearch user/group (UID 1003)
    sudo groupadd -g 1003 elasticsearch
    sudo useradd -u 1003 -g 1003 -r -s /bin/false elasticsearch
    
    # Set ownership
    sudo chown -R 1001:1001 /data/hot/postgresql
    sudo chown -R 1002:1002 /data/hot/redis
    sudo chown -R 1003:1003 /data/hot/elasticsearch-hot
    ```
    
    **Khuyến nghị:** Sử dụng Option 1 (để Kubernetes quản lý) vì:
    - Đơn giản hơn
    - Kubernetes sẽ tự động handle ownership khi mount volumes
    - Có thể cấu hình trong Pod SecurityContext khi deploy
- [x] **Tạo thư mục cho WARM storage (/data/warm):**
  - ✅ **Kết quả:** Đã tạo thành công
    - elasticsearch-warm, prometheus-warm, loki-warm, app-cache
- [x] **Tạo thư mục cho COLD storage (/data/cold):**
  - ✅ **Kết quả:** Đã tạo thành công
    - prometheus-archive, loki-archive, db-backups, minio, app-backups, docker-registry
- [x] **Kiểm tra cấu trúc thư mục:**
  - ✅ **Kết quả:** Tất cả thư mục đã được tạo thành công
    - HOT: postgresql, redis, elasticsearch-hot, prometheus-hot, loki-hot
    - WARM: elasticsearch-warm, prometheus-warm, loki-warm, app-cache
    - COLD: prometheus-archive, loki-archive, db-backups, minio, app-backups, docker-registry
  - [ ] **Sửa ownership (Optional - để Kubernetes quản lý):**
    ```bash
    # Nếu muốn đồng nhất ownership về root (khuyến nghị)
    sudo chown -R root:root /data/warm/elasticsearch-warm
    ```

#### Step 6: Cấu hình Docker data directory
- [x] **Kiểm tra Docker data directory hiện tại:**
  - ✅ **Kết quả:** Docker Root Dir: `/var/lib/docker` (thư mục mặc định)
- [ ] **Kiểm tra dung lượng Docker đang sử dụng:**
  ```bash
  sudo du -sh /var/lib/docker
  ```
- [x] **Tạo thư mục mới cho Docker:**
  - ✅ **Kết quả:** `/var/lib/docker` đã tồn tại (thư mục mặc định)
- [ ] **Đánh giá:**
  - Docker đang ở `/var/lib/docker` trên root filesystem (nvme1n1)
  - Root filesystem có 229.8G với 83.8G available (12% used)
  - **Quyết định:** Có thể giữ nguyên hoặc di chuyển sang `/data/hot/docker` nếu cần
  - **Khuyến nghị:** Giữ nguyên vì root partition còn nhiều dung lượng
- [ ] **Di chuyển Docker data (Optional - chỉ khi cần):**
  ```bash
  # Chỉ thực hiện nếu muốn di chuyển sang /data/hot/docker
  # Stop Docker
  sudo systemctl stop docker
  
  # Di chuyển data
  sudo mv /var/lib/docker /data/hot/docker
  sudo ln -s /data/hot/docker /var/lib/docker
  
  # Start Docker
  sudo systemctl start docker
  ```

#### Step 7: Cấu hình K3s data directory
- [ ] **Tạo thư mục cho K3s:**
  ```bash
  sudo mkdir -p /var/lib/rancher
  ```
- [ ] **K3s sẽ tự động sử dụng /var/lib/rancher khi cài đặt**

#### Step 8: Test I/O performance
- [ ] **Test write performance cho HOT (nvme0n1):**
  ```bash
  sudo dd if=/dev/zero of=/data/hot/testfile bs=1G count=1 oflag=direct
  sudo rm /data/hot/testfile
  ```
- [ ] **Test write performance cho WARM (sdb):**
  ```bash
  sudo dd if=/dev/zero of=/data/warm/testfile bs=1G count=1 oflag=direct
  sudo rm /data/warm/testfile
  ```
- [ ] **Test write performance cho COLD (sda):**
  ```bash
  sudo dd if=/dev/zero of=/data/cold/testfile bs=1G count=1 oflag=direct
  sudo rm /data/cold/testfile
  ```

#### Step 9: Setup StorageClass trong K3s (sau khi cluster được tạo)
- [ ] **Tạo Local Path Provisioner cho Hot Storage**
- [ ] **Tạo Local Path Provisioner cho Warm Storage**
- [ ] **Tạo Local Path Provisioner cho Cold Storage**

### Docker Installation
- [x] Cài đặt Docker Desktop (Windows/macOS) hoặc Docker Engine (Linux)
  - ✅ **Kết quả:** Docker Engine đã cài đặt
- [x] Kiểm tra Docker đã chạy: `docker --version`
  - ✅ **Kết quả:** Docker Client Version: 28.2.2
- [x] Kiểm tra Docker daemon: `docker ps`
  - ✅ **Kết quả:** Docker daemon đang chạy, không có container nào (sẵn sàng)
- [ ] Đảm bảo Docker có quyền truy cập

### kubectl Installation
- [x] Cài đặt kubectl CLI tool
  - ✅ **Kết quả:** Đã cài đặt thành công qua snap
- [x] Kiểm tra version: `kubectl version --client`
  - ✅ **Kết quả:** Client Version: v1.34.2, Kustomize Version: v5.7.1
- [x] Cấu hình PATH environment variable (nếu cần)
  - ✅ **Kết quả:** PATH đã được cấu hình tự động (snap)
- [ ] Kiểm tra kubectl có hoạt động: `kubectl cluster-info` (sẽ test sau khi có cluster)

### k3d Installation
- [x] Cài đặt k3d (via script/package manager)
  - ✅ **Kết quả:** Đã cài đặt thành công
- [x] Kiểm tra version: `k3d version`
  - ✅ **Kết quả:** k3d version v5.8.3, k3s version v1.31.5-k3s1 (default)
- [ ] Xác nhận k3d có thể tạo cluster (sẽ test ở bước tiếp theo)

---

## 🎯 K3S Cluster Configuration Suggestions (Based on 19 Services)

### Namespace Structure
- [ ] **infrastructure** - Databases, Redis, Consul, Elasticsearch, Dapr
- [ ] **core-services** - Core business services (Customer, Order, Payment, Catalog, etc.)
- [ ] **support-services** - Support services (Auth, Notification, Search, Location)
- [ ] **integration-services** - Gateway, Admin Panel, Frontend
- [ ] **monitoring** - Prometheus, Grafana, Loki, Jaeger
- [ ] **default** - System pods

### Service Ports Mapping (19 Services)
- [ ] **Gateway Service**: 8080 (NodePort/LoadBalancer)
- [ ] **Auth Service**: 8002 (ClusterIP)
- [ ] **User Service**: 8001 (ClusterIP)
- [ ] **Customer Service**: 8003 (ClusterIP)
- [ ] **Order Service**: 8004 (ClusterIP)
- [ ] **Payment Service**: 8005 (ClusterIP)
- [ ] **Catalog Service**: 8001 (ClusterIP) - Note: Same port as User, use different namespace
- [ ] **Warehouse Service**: 8008 (ClusterIP)
- [ ] **Shipping Service**: 8007 (ClusterIP)
- [ ] **Fulfillment Service**: 8009 (ClusterIP)
- [ ] **Pricing Service**: 8010 (ClusterIP)
- [ ] **Promotion Service**: 8011 (ClusterIP)
- [ ] **Loyalty Service**: 8012 (ClusterIP)
- [ ] **Review Service**: 8013 (ClusterIP)
- [ ] **Notification Service**: Internal (ClusterIP)
- [ ] **Search Service**: Internal (ClusterIP)
- [ ] **Location Service**: Internal (ClusterIP)
- [ ] **Admin Panel**: 3001 (NodePort)
- [ ] **Frontend Service**: 3000 (NodePort)

### Infrastructure Services (Deploy First)
- [ ] **PostgreSQL** (all databases)
  - Storage: `/data/hot` (nvme0n1) - 100GB
  - Memory: 6GB
  - Namespace: `infrastructure`
- [ ] **Redis**
  - Storage: `/data/hot` (nvme0n1) - 10GB
  - Memory: 1.5GB
  - Namespace: `infrastructure`
- [ ] **Elasticsearch**
  - Hot data: `/data/hot` (nvme0n1) - 40GB
  - Warm data: `/data/warm` (sdb) - 80GB
  - Memory: 3GB
  - Namespace: `infrastructure`
- [ ] **Consul** (Service Discovery)
  - Memory: 512MB
  - Namespace: `infrastructure`
- [ ] **Dapr** (Service Mesh)
  - Memory: 1.5GB
  - Namespace: `infrastructure`

### Core Services Resource Allocation
- [ ] **Gateway Service** (1GB RAM)
  - Requests: CPU 200m, Memory 512Mi
  - Limits: CPU 1000m, Memory 1Gi
  - Namespace: `integration-services`
- [ ] **Auth Service** (512MB RAM)
  - Requests: CPU 100m, Memory 256Mi
  - Limits: CPU 500m, Memory 512Mi
  - Namespace: `support-services`
- [ ] **User Service** (512MB RAM)
  - Requests: CPU 100m, Memory 256Mi
  - Limits: CPU 500m, Memory 512Mi
  - Namespace: `core-services`
- [ ] **Customer Service** (512MB RAM)
  - Requests: CPU 100m, Memory 256Mi
  - Limits: CPU 500m, Memory 512Mi
  - Namespace: `core-services`
- [ ] **Order Service** (1GB RAM)
  - Requests: CPU 200m, Memory 512Mi
  - Limits: CPU 1000m, Memory 1Gi
  - Namespace: `core-services`
- [ ] **Payment Service** (1GB RAM)
  - Requests: CPU 200m, Memory 512Mi
  - Limits: CPU 1000m, Memory 1Gi
  - Namespace: `core-services`
- [ ] **Catalog Service** (512MB RAM)
  - Requests: CPU 200m, Memory 256Mi
  - Limits: CPU 1000m, Memory 512Mi
  - Namespace: `core-services`
- [ ] **Warehouse Service** (512MB RAM)
  - Requests: CPU 100m, Memory 256Mi
  - Limits: CPU 500m, Memory 512Mi
  - Namespace: `core-services`
- [ ] **Shipping Service** (512MB RAM)
  - Requests: CPU 100m, Memory 256Mi
  - Limits: CPU 500m, Memory 512Mi
  - Namespace: `core-services`
- [ ] **Fulfillment Service** (512MB RAM)
  - Requests: CPU 100m, Memory 256Mi
  - Limits: CPU 500m, Memory 512Mi
  - Namespace: `core-services`
- [ ] **Pricing Service** (512MB RAM)
  - Requests: CPU 100m, Memory 256Mi
  - Limits: CPU 500m, Memory 512Mi
  - Namespace: `core-services`
- [ ] **Promotion Service** (512MB RAM)
  - Requests: CPU 100m, Memory 256Mi
  - Limits: CPU 500m, Memory 512Mi
  - Namespace: `core-services`
- [ ] **Loyalty Service** (512MB RAM)
  - Requests: CPU 100m, Memory 256Mi
  - Limits: CPU 500m, Memory 512Mi
  - Namespace: `core-services`
- [ ] **Review Service** (512MB RAM)
  - Requests: CPU 100m, Memory 256Mi
  - Limits: CPU 500m, Memory 512Mi
  - Namespace: `core-services`

### Support Services Resource Allocation
- [ ] **Notification Service** (256MB RAM)
  - Requests: CPU 50m, Memory 128Mi
  - Limits: CPU 250m, Memory 256Mi
  - Namespace: `support-services`
- [ ] **Search Service** (512MB RAM)
  - Requests: CPU 200m, Memory 256Mi
  - Limits: CPU 1000m, Memory 512Mi
  - Namespace: `support-services`
- [ ] **Location Service** (256MB RAM)
  - Requests: CPU 50m, Memory 128Mi
  - Limits: CPU 250m, Memory 256Mi
  - Namespace: `support-services`

### Frontend Services Resource Allocation
- [ ] **Admin Panel** (512MB RAM)
  - Requests: CPU 100m, Memory 256Mi
  - Limits: CPU 500m, Memory 512Mi
  - Namespace: `integration-services`
- [ ] **Frontend Service** (512MB RAM)
  - Requests: CPU 200m, Memory 256Mi
  - Limits: CPU 1000m, Memory 512Mi
  - Namespace: `integration-services`

### Monitoring Services Resource Allocation
- [ ] **Prometheus** (2GB RAM)
  - Hot data (0-3d): `/data/hot` - 30GB
  - Warm data (3-7d): `/data/warm` - 50GB
  - Archive (7-30d): `/data/cold` - 200GB
  - Namespace: `monitoring`
- [ ] **Grafana** (512MB RAM)
  - Requests: CPU 100m, Memory 256Mi
  - Limits: CPU 500m, Memory 512Mi
  - Namespace: `monitoring`
- [ ] **Loki** (1.5GB RAM)
  - Hot data (0-3d): `/data/hot` - 20GB
  - Warm data (3-7d): `/data/warm` - 40GB
  - Archive (7-30d): `/data/cold` - 150GB
  - Namespace: `monitoring`
- [ ] **Jaeger** (512MB RAM)
  - Memory-only storage
  - Namespace: `monitoring`

### StorageClass Configuration
- [ ] **hot-storage** (nvme0n1)
  - Type: Local Path Provisioner
  - Path: `/data/hot`
  - Performance: <1ms latency
  - Use for: PostgreSQL, Redis, Elasticsearch hot, Prometheus/Loki 0-3d
- [ ] **warm-storage** (sdb SSD)
  - Type: Local Path Provisioner
  - Path: `/data/warm`
  - Performance: <5ms latency
  - Use for: Elasticsearch warm, Prometheus/Loki 3-7d, Application cache
- [ ] **cold-storage** (sda HDD)
  - Type: Local Path Provisioner
  - Path: `/data/cold`
  - Performance: ~10ms latency
  - Use for: Archives, backups, MinIO, Docker registry cache

### Deployment Strategy

**Option 1: Manual Deployment (Scripts)**
- [ ] Deploy using scripts in `k8s-local/`
- [ ] See: [STAGING_DEPLOYMENT_REVIEW.md](./STAGING_DEPLOYMENT_REVIEW.md)

**Option 2: GitOps với ArgoCD** ⭐ **RECOMMENDED**
- [ ] Install ArgoCD
- [ ] Setup Git repository cho K8s manifests
- [ ] Create ArgoCD Applications
- [ ] Deploy via GitOps workflow
- [ ] See: [ARGOCD_SETUP_GUIDE.md](./ARGOCD_SETUP_GUIDE.md) và [STAGING_DEPLOYMENT_ARGOCD_PLAN.md](./STAGING_DEPLOYMENT_ARGOCD_PLAN.md)

### Deployment Order (Dependencies)
1. [x] **Infrastructure Layer** (Deploy first) ✅ **COMPLETED**
   - ✅ PostgreSQL → ✅ Redis → ✅ Consul → ✅ Elasticsearch → ✅ Dapr
   - **Status:** Tất cả services đang Running và Ready
   - **Pods:**
     - PostgreSQL: Running (37m uptime)
     - Redis: Running (37m uptime)
     - Consul: Running (6m uptime)
     - Elasticsearch: Running (5m uptime)
     - Dapr: All components Running (dapr-operator, dapr-sidecar-injector, dapr-sentry, dapr-placement-server, dapr-dashboard)
2. [ ] **Support Services** (Deploy second)
   - Auth Service → Notification Service → Search Service → Location Service
3. [ ] **Core Services** (Deploy third)
   - Customer Service → User Service → Catalog Service → Pricing Service
   - Warehouse Service → Order Service → Payment Service
   - Shipping Service → Fulfillment Service → Promotion Service → Loyalty Service → Review Service
4. [ ] **Integration Services** (Deploy last)
   - Gateway Service → Admin Panel → Frontend Service
5. [ ] **Monitoring** (Can deploy anytime)
   - Prometheus → Grafana → Loki → Jaeger

### Infrastructure Deployment Script
- [x] **Script đã được tạo:** `deploy-infrastructure.sh`
  - ✅ Script tự động deploy: PostgreSQL, Redis, Consul, Elasticsearch, Dapr
  - ✅ Sử dụng StorageClasses đã tạo (hot-storage, warm-storage, cold-storage)
  - ✅ Deploy vào namespace `infrastructure`
  - ✅ Tự động wait cho deployments/statefulsets ready
  - ✅ Hiển thị status và access points sau khi deploy

- [x] **Script đã được chạy thành công:**
  - ✅ Tất cả infrastructure services đã được deploy
  - ✅ Storage requests đã được giảm xuống 50% (PostgreSQL: 50Gi, Redis: 5Gi, ES hot: 20Gi, ES warm: 40Gi)
  - ✅ Image Consul đã được sửa thành `hashicorp/consul:1.17`
  - ✅ Readiness probes đã được thêm cho Consul

- [x] **Kiểm tra sau khi deploy:**
  - ✅ **Kết quả:** Tất cả services đang Running và Ready
    - PostgreSQL: Running (37m uptime) ✅
    - Redis: Running (37m uptime) ✅
    - Consul: Running (6m uptime) ✅
    - Elasticsearch: Running (5m uptime) ✅
    - Dapr: All components Running ✅
  
- [x] **Access Points sau khi deploy:**
  - ✅ PostgreSQL: `postgresql.infrastructure.svc.cluster.local:5432`
  - ✅ Redis: `redis.infrastructure.svc.cluster.local:6379`
  - ✅ Consul UI: `http://<node-ip>:30500` (NodePort)
  - ✅ Elasticsearch: `http://elasticsearch.infrastructure.svc.cluster.local:9200`
  - ✅ Dapr Dashboard: Available in dapr-system namespace

### Ingress Configuration (Domain: tanhdev.com)
**Lưu ý:** Sử dụng Nginx Manager trên server khác thay vì Ingress Controller trong cluster

- [ ] **Cấu hình Nginx Manager bên ngoài:**
  - **Gateway Service** (Port 8080)
    - Domain: `api.tanhdev.com` hoặc `gateway.tanhdev.com`
    - Proxy pass: `http://192.168.1.112:8080`
    - TLS: SSL/TLS certificates tại Nginx Manager
  - **Frontend Service** (Port 3000)
    - Domain: `www.tanhdev.com` hoặc `tanhdev.com`
    - Proxy pass: `http://192.168.1.112:3000`
    - TLS: SSL/TLS certificates tại Nginx Manager
  - **Admin Panel** (Port 3001)
    - Domain: `admin.tanhdev.com`
    - Proxy pass: `http://192.168.1.112:3001`
    - TLS: SSL/TLS certificates tại Nginx Manager
    - Authentication: Require admin access (Basic Auth hoặc OAuth2)
  - **Monitoring** (Optional - Internal access recommended)
    - Grafana: `grafana.tanhdev.com` → `http://192.168.1.112:3000` (nếu expose)
    - Prometheus: `prometheus.tanhdev.com` → `http://192.168.1.112:9090` (nếu expose)
    - Consul UI: `consul.tanhdev.com` → `http://192.168.1.112:8500` (nếu expose)
    - Authentication: Strong authentication required (VPN/Basic Auth)

### DNS Configuration (tanhdev.com)
- [ ] **A Records** (Point to Nginx Manager server IP - không phải K3S server)
  - `api.tanhdev.com` → [Nginx Manager Server IP]
  - `gateway.tanhdev.com` → [Nginx Manager Server IP] (optional, alias of api)
  - `www.tanhdev.com` → [Nginx Manager Server IP]
  - `tanhdev.com` → [Nginx Manager Server IP]
  - `admin.tanhdev.com` → [Nginx Manager Server IP]
- [ ] **CNAME Records** (Optional - for monitoring)
  - `grafana.tanhdev.com` → [Nginx Manager Server IP]
  - `prometheus.tanhdev.com` → [Nginx Manager Server IP]
  - `consul.tanhdev.com` → [Nginx Manager Server IP]
- [ ] **SSL/TLS Certificates**
  - [ ] Setup SSL/TLS certificates tại Nginx Manager (Let's Encrypt hoặc custom)
  - [ ] Configure auto-renewal cho certificates
  - [ ] Test certificate renewal

### Service Discovery & Networking
- [ ] **Consul** for service discovery
- [ ] **Dapr** for service mesh (pub/sub, state management)
- [ ] **Internal DNS** for service-to-service communication
- [ ] **Network Policies** for security isolation

### Recommended k3d Cluster Configuration

**Option 1: Single Agent (Development/Testing) - Khuyến nghị để bắt đầu**
```bash
k3d cluster create ecommerce-cluster \
  --port "8080:8080@loadbalancer" \
  --port "3000:3000@loadbalancer" \
  --port "3001:3001@loadbalancer" \
  --port "8500:8500@loadbalancer" \
  --port "9090:9090@loadbalancer" \
  --agents 1 \
  --k3s-arg "--disable=traefik@server:0" \
  --volume /data/hot:/data/hot \
  --volume /data/warm:/data/warm \
  --volume /data/cold:/data/cold
```

**Option 2: Multiple Agents (Production-like) - Khi cần HA và performance**
```bash
k3d cluster create ecommerce-cluster \
  --port "8080:8080@loadbalancer" \
  --port "3000:3000@loadbalancer" \
  --port "3001:3001@loadbalancer" \
  --port "8500:8500@loadbalancer" \
  --port "9090:9090@loadbalancer" \
  --agents 2 \
  --k3s-arg "--disable=traefik@server:0" \
  --volume /data/hot:/data/hot \
  --volume /data/warm:/data/warm \
  --volume /data/cold:/data/cold
```

**Lưu ý về k3s-arg:**
- Khi có nhiều node (control plane + agents), cần chỉ định node filter
- `@server:0` = áp dụng cho server node (control plane)
- `@all` = áp dụng cho tất cả nodes
- `@agents:*` = áp dụng cho tất cả agent nodes

**So sánh số lượng Agents:**

| Agents | Use Case | Pros | Cons |
|--------|----------|------|------|
| **1 agent** | Development, Testing, Single server | ✅ Đơn giản, ít resource, dễ quản lý | ❌ Không có HA, single point of failure |
| **2 agents** | Production (small-medium) | ✅ HA cơ bản, load distribution | ⚠️ Cần nhiều resource hơn |
| **3+ agents** | Production (large scale) | ✅ High availability, tốt cho production | ⚠️ Phức tạp, tốn nhiều resource |

**Khuyến nghị cho setup hiện tại:**
- **Bắt đầu với 1 agent** để test và validate
- Server có 31GB RAM, đủ cho 1 agent với 19 services (~32GB requirement)
- **Sau đó scale lên 2-3 agents** khi:
  - Cần high availability
  - Traffic tăng cao
  - Có thêm server resources

**Note:** 
- Disable Traefik (k3d default) vì bạn đã có Gateway Service
- **Không cần Ingress Controller** vì đã có Nginx Manager trên server khác
- Mount storage volumes để sử dụng multi-tier storage
- Expose ports để Nginx Manager bên ngoài có thể proxy đến:
  - `8080`: Gateway Service → Nginx Manager sẽ route `api.tanhdev.com` đến đây
  - `3000`: Frontend Service → Nginx Manager sẽ route `www.tanhdev.com` đến đây
  - `3001`: Admin Panel → Nginx Manager sẽ route `admin.tanhdev.com` đến đây
  - `8500`: Consul UI (optional - có thể chỉ internal access)
  - `9090`: Prometheus (optional - có thể chỉ internal access)

**Kiến trúc với Nginx Manager bên ngoài:**
```
Internet (Port 80/443)
    ↓
[Nginx Manager - Server khác]
    ↓ (Proxy đến K3S cluster)
┌─────────────────────────────────────┐
│  K3S Cluster (192.168.1.112)       │
│  ├─ api.tanhdev.com → :8080        │
│  ├─ www.tanhdev.com → :3000        │
│  └─ admin.tanhdev.com → :3001      │
└─────────────────────────────────────┘
```

**Cấu hình Nginx Manager cần thiết:**
- SSL/TLS termination tại Nginx Manager
- Proxy pass đến các ports tương ứng trên server K3S
- Load balancing (nếu có nhiều nodes)

**So sánh 2 cách tiếp cận:**

| Aspect | Local Setup (Nginx Manager bên ngoài) | AWS Setup (Ingress Controller) |
|--------|--------------------------------------|--------------------------------|
| **Entry Point** | Nginx Manager (server khác) | Ingress Controller (trong cluster) |
| **Expose Ports** | 8080, 3000, 3001 (services) | 80, 443 (Ingress Controller) |
| **Service Types** | LoadBalancer/NodePort | ClusterIP (không expose) |
| **SSL/TLS** | Tại Nginx Manager | Tại Ingress Controller |
| **Routing** | Nginx Manager proxy pass | Ingress Controller route |
| **Security** | Services expose ra ngoài | Services chỉ accessible qua Ingress |

**Kết luận:**
- **Local:** Cần expose 8080, 3000, 3001 vì Nginx Manager bên ngoài cần proxy đến
- **AWS:** Chỉ expose 80/443, services là ClusterIP, Ingress Controller route traffic vào

### Ingress Controller Setup
- [x] **Không cần cài đặt Ingress Controller trong cluster**
  - ✅ **Lý do:** Đã có Nginx Manager trên server khác đứng trước
  - ✅ **Kiến trúc:** Nginx Manager → Proxy → K3S Cluster (ports 8080, 3000, 3001)
  - ✅ **Lợi ích:** 
    - SSL/TLS termination tại Nginx Manager (tập trung)
    - Không cần expose ports 80/443 trong cluster
    - Quản lý routing tập trung tại một nơi
    - Giảm complexity trong cluster

**Nếu muốn cài Ingress Controller trong cluster (không khuyến nghị cho local setup):**
- [ ] **Install Nginx Ingress Controller**
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
  ```
- [ ] **Verify Installation**
  ```bash
  kubectl get pods -n ingress-nginx
  kubectl get svc -n ingress-nginx
  ```

### 📝 AWS Deployment - Ingress Controller (80/443)
**Lưu ý:** Khi deploy lên AWS, sẽ sử dụng Ingress Controller với ports 80/443

- [ ] **AWS EKS/K3S trên EC2 với Ingress Controller:**
  - [ ] **Install Nginx Ingress Controller trên AWS:**
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/aws/deploy.yaml
    ```
  - [ ] **Expose ports 80/443 trong cluster:**
    - Port 80: HTTP traffic
    - Port 443: HTTPS traffic (SSL/TLS)
  - [ ] **Cấu hình LoadBalancer Service:**
    - Type: LoadBalancer (AWS sẽ tạo ALB/NLB tự động)
    - Ports: 80, 443
    - SSL/TLS: Sử dụng AWS Certificate Manager (ACM) hoặc Cert-Manager với Let's Encrypt
  - [ ] **Ingress Resources cho AWS:**
    - `api.tanhdev.com` → Gateway Service (ClusterIP, port 8080 - không expose ra ngoài)
    - `www.tanhdev.com` → Frontend Service (ClusterIP, port 3000 - không expose ra ngoài)
    - `admin.tanhdev.com` → Admin Panel (ClusterIP, port 3001 - không expose ra ngoài)
  - [ ] **Service Types cho AWS:**
    - Gateway, Frontend, Admin Panel: **ClusterIP** (chỉ accessible trong cluster)
    - Ingress Controller: **LoadBalancer** (expose ports 80/443)
    - **Lưu ý:** Không cần expose ports 8080, 3000, 3001 vì Ingress sẽ route từ 80/443 vào
  - [ ] **DNS Configuration cho AWS:**
    - Point A records đến AWS Load Balancer DNS/IP
    - Sử dụng Route53 hoặc DNS provider khác
  - [ ] **SSL/TLS Certificates trên AWS:**
    - Option 1: AWS Certificate Manager (ACM) - tích hợp với ALB
    - Option 2: Cert-Manager với Let's Encrypt
    - Auto-renewal certificates

- [ ] **AWS k3d Cluster Configuration (khi deploy lên AWS):**
  ```bash
  # Khi deploy lên AWS EC2 với Ingress Controller
  # CHỈ expose ports 80/443 cho Ingress Controller
  # KHÔNG expose ports 8080, 3000, 3001 (services sẽ là ClusterIP)
  k3d cluster create ecommerce-cluster-aws \
    --port "80:80@loadbalancer" \
    --port "443:443@loadbalancer" \
    --agents 1 \
    --k3s-arg "--disable=traefik" \
    --volume /data/hot:/data/hot \
    --volume /data/warm:/data/warm \
    --volume /data/cold:/data/cold
  ```
  
  **Giải thích:**
  - Ports 80/443: Cho Ingress Controller (entry point duy nhất)
  - Ports 8080, 3000, 3001: **KHÔNG cần expose** - services là ClusterIP, chỉ accessible qua Ingress
  - Ingress Controller sẽ route traffic từ 80/443 vào các services bên trong cluster
  
  **Hoặc với EKS:**
  - Sử dụng AWS Load Balancer Controller
  - Ingress với ALB (Application Load Balancer)
  - SSL/TLS termination tại ALB
  - Services là ClusterIP, không expose trực tiếp

- [ ] **AWS Architecture với Ingress:**
  ```
  Internet (Port 80/443)
      ↓
  [AWS Load Balancer (ALB/NLB)]
      ↓
  [Ingress Controller (Nginx)]
      ↓ (Route dựa trên domain)
  ┌─────────────────────────────────────┐
  │  K3S/EKS Cluster                    │
  │  ├─ api.tanhdev.com → Gateway:8080 │
  │  ├─ www.tanhdev.com → Frontend:3000│
  │  └─ admin.tanhdev.com → Admin:3001 │
  └─────────────────────────────────────┘
  ```

- [ ] **AWS Security Groups:**
  - Allow inbound: Ports 80, 443 từ Internet (cho Ingress Controller)
  - **KHÔNG cần** allow inbound ports 8080, 3000, 3001 (services là ClusterIP, chỉ accessible trong cluster)
  - Allow outbound: All traffic

- [ ] **AWS Storage:**
  - EBS volumes cho `/data/hot`, `/data/warm`, `/data/cold`
  - Hoặc EFS (Elastic File System) cho shared storage
  - Backup strategy với AWS Backup hoặc S3

---

## 🚀 k3d Setup

### Cluster Creation
- [x] Tạo cluster đầu tiên: `k3d cluster create <name>`
  - ✅ **Kết quả:** Cluster `ecommerce-cluster` đã được tạo thành công!
  - ✅ **Cấu hình:**
    - 1 server node (control plane): `k3d-ecommerce-cluster-server-0`
    - 1 agent node: `k3d-ecommerce-cluster-agent-0`
    - LoadBalancer: `k3d-ecommerce-cluster-serverlb`
    - Ports exposed: 8080, 3000, 3001, 8500, 9090
    - Volumes mounted: /data/hot, /data/warm, /data/cold
    - Traefik disabled: ✅
- [ ] Tạo cluster với custom port: `k3d cluster create --port "8080:80@loadbalancer"`
- [ ] Tạo cluster với nhiều nodes: `k3d cluster create --agents 3`
- [ ] Tạo cluster với custom config: `k3d cluster create --config <config-file>`

### Cluster Management
- [x] Liệt kê các cluster: `k3d cluster list`
  - ✅ **Kết quả:** `ecommerce-cluster` - 1/1 servers, 1/1 agents, LoadBalancer: true
- [x] Kiểm tra cluster status: `k3d cluster get ecommerce-cluster`
  - ✅ **Kết quả:** Cluster đang chạy tốt
- [x] Kiểm tra nodes: `kubectl get nodes`
  - ✅ **Kết quả:** 
    - `k3d-ecommerce-cluster-server-0`: Ready (control-plane, master) - v1.31.5+k3s1
    - `k3d-ecommerce-cluster-agent-0`: Ready - v1.31.5+k3s1
- [x] Kiểm tra cluster info: `kubectl cluster-info`
  - ✅ **Kết quả:** Kubernetes control plane đang chạy tại https://0.0.0.0:38039
  - ✅ CoreDNS và Metrics-server đang chạy
- [x] Kiểm tra kubeconfig: `kubectl config view` và `kubectl config current-context`
  - ✅ **Kết quả:** Context hiện tại: `k3d-ecommerce-cluster`
- [x] Kiểm tra system pods: `kubectl get pods -A`
  - ✅ **Kết quả:** Tất cả system pods đang Running:
    - coredns: Running
    - local-path-provisioner: Running
    - metrics-server: Running
- [ ] Start cluster: `k3d cluster start <name>`
- [ ] Stop cluster: `k3d cluster stop <name>`
- [ ] Delete cluster: `k3d cluster delete <name>`
- [ ] Delete tất cả clusters: `k3d cluster delete --all`

### Scale Agents (Thêm/Xóa Nodes)
- [ ] **Thêm agent node vào cluster hiện có (Scale Up):**
  ```bash
  # Thêm 1 agent node vào cluster ecommerce-cluster
  k3d node create agent-2 --cluster ecommerce-cluster
  
  # Hoặc thêm nhiều agents cùng lúc
  k3d node create agent-2 agent-3 --cluster ecommerce-cluster
  ```
  
  **Lưu ý:** 
  - ✅ **KHÔNG cần setup lại từ đầu** - chỉ cần thêm node mới
  - ✅ Các services đã deploy sẽ tự động distribute trên nodes mới
  - ✅ Không mất data, không cần migrate
  - ✅ Có thể thêm nodes bất cứ lúc nào
  
- [ ] **Kiểm tra nodes sau khi scale:**
  ```bash
  kubectl get nodes
  kubectl get nodes -o wide
  ```
  
- [ ] **Xóa agent node (Scale Down):**
  ```bash
  # Xóa node cụ thể
  k3d node delete agent-2
  
  # Hoặc xóa nhiều nodes
  k3d node delete agent-2 agent-3
  ```
  
  **Lưu ý:**
  - Kubernetes sẽ tự động drain pods từ node trước khi xóa
  - Pods sẽ được reschedule sang nodes còn lại
  - Đảm bảo có đủ resources trên nodes còn lại

**Ví dụ: Scale từ 1 → 2 agents:**
```bash
# 1. Kiểm tra cluster hiện tại
k3d cluster list
kubectl get nodes

# 2. Thêm agent node mới
k3d node create agent-2 --cluster ecommerce-cluster

# 3. Kiểm tra nodes mới
kubectl get nodes
# Sẽ thấy: k3d-ecommerce-cluster-server-0 (control plane)
#          k3d-ecommerce-cluster-agent-0 (agent 1)
#          k3d-ecommerce-cluster-agent-1 (agent 2 - mới thêm)

# 4. Kiểm tra pods distribution
kubectl get pods -A -o wide
# Pods sẽ tự động distribute trên các nodes
```

### kubeconfig Setup
- [x] Kiểm tra kubeconfig: `kubectl config view`
  - ✅ **Kết quả:** kubeconfig đã được cấu hình đúng
- [x] Kiểm tra context hiện tại: `kubectl config current-context`
  - ✅ **Kết quả:** `k3d-ecommerce-cluster` (đã được set làm context mặc định)
- [ ] Merge kubeconfig: `k3d kubeconfig merge <name> --kubeconfig-switch-context` (nếu cần)
- [ ] Switch context: `kubectl config use-context <context-name>` (nếu có nhiều clusters)

### Volume Mount Verification
- [x] **Kiểm tra volumes đã mount vào cluster nodes:**
  - ✅ **Kết quả:** Volumes đã được mount vào cluster nodes qua `--volume` flag
  - ⚠️ **Lưu ý:** Volumes không tự động mount vào pods - cần mount qua PersistentVolumes hoặc hostPath

- [x] **Kiểm tra volumes trong pod (cần mount volumes vào pod):**
  - ✅ **Kết quả:** Volumes đã được mount thành công vào pod!
  - ✅ **HOT storage (/data/hot):**
    - postgresql, redis, elasticsearch-hot, prometheus-hot, loki-hot
  - ✅ **WARM storage (/data/warm):**
    - elasticsearch-warm, prometheus-warm, loki-warm, app-cache
  - ✅ **COLD storage (/data/cold):**
    - prometheus-archive, loki-archive, db-backups, minio, app-backups, docker-registry
  
  **Giải thích:**
  - Volumes được mount vào cluster nodes qua `--volume` flag khi tạo cluster
  - Để pods sử dụng, cần mount volumes vào pod spec (hostPath hoặc PersistentVolume)
  - Khi deploy services, sẽ mount volumes trong deployment/pod spec

- [ ] **Tạo PersistentVolumes cho storage tiers (sẽ làm khi deploy services):**
  - Tạo PV cho hot-storage, warm-storage, cold-storage
  - Tạo PVC khi deploy services
  - Services sẽ tự động mount volumes khi deploy

### Registry Setup (Optional)
- [ ] Tạo local registry: `k3d registry create <name>`
- [ ] Kết nối registry với cluster: `k3d cluster create --registry-use <registry-name>`
- [ ] Kiểm tra registry: `docker ps | grep registry`

---

## ☸️ Kubernetes Basics

### Cluster Information
- [ ] Kiểm tra cluster info: `kubectl cluster-info`
- [ ] Kiểm tra nodes: `kubectl get nodes`
- [ ] Kiểm tra node details: `kubectl describe node <node-name>`
- [ ] Kiểm tra API resources: `kubectl api-resources`

### Namespaces
- [x] Liệt kê namespaces: `kubectl get namespaces` hoặc `kubectl get ns`
  - ✅ **Kết quả:** Tất cả namespaces đang Active:
    - `infrastructure` - Cho databases, Redis, Consul, Elasticsearch, Dapr ✅
    - `core-services` - Cho 12 core business services ✅
    - `support-services` - Cho Auth, Notification, Search, Location ✅
    - `integration-services` - Cho Gateway, Admin Panel, Frontend ✅
    - `monitoring` - Cho Prometheus, Grafana, Loki, Jaeger ✅
    - System namespaces: default, kube-system, kube-public, kube-node-lease ✅
- [x] Tạo namespace: `kubectl create namespace <name>`
  - ✅ **Kết quả:** Đã tạo thành công 5 namespaces cho các nhóm services
- [ ] Xóa namespace: `kubectl delete namespace <name>`
- [ ] Set default namespace: `kubectl config set-context --current --namespace=<name>`

### StorageClasses Setup (Multi-Tier Storage)
- [x] **Kiểm tra StorageClasses hiện có:**
  - ✅ **Kết quả:** Có StorageClass mặc định `local-path` với provisioner `rancher.io/local-path`
  
- [x] **Tạo StorageClass cho HOT storage (nvme0n1):**
  - ✅ **Kết quả:** StorageClass `hot-storage` đã được tạo thành công
  - ✅ **Cấu hình:** basePath=/data/hot, provisioner=rancher.io/local-path
- [x] **Tạo StorageClass cho WARM storage (sdb SSD):**
  - ✅ **Kết quả:** StorageClass `warm-storage` đã được tạo thành công
  - ✅ **Cấu hình:** basePath=/data/warm, provisioner=rancher.io/local-path
- [x] **Tạo StorageClass cho COLD storage (sda HDD):**
  - ✅ **Kết quả:** StorageClass `cold-storage` đã được tạo thành công
  - ✅ **Cấu hình:** basePath=/data/cold, provisioner=rancher.io/local-path
- [x] **Kiểm tra StorageClasses đã tạo:**
  - ✅ **Kết quả:** Tất cả 4 StorageClasses đang hoạt động:
    - `hot-storage` - basePath=/data/hot ✅
    - `warm-storage` - basePath=/data/warm ✅
    - `cold-storage` - basePath=/data/cold ✅
    - `local-path` (default) - basePath mặc định ✅
  
**Lưu ý:**
- Sử dụng `rancher.io/local-path` provisioner (có sẵn trong k3d)
- `volumeBindingMode: WaitForFirstConsumer` - đợi pod được tạo mới bind volume
- Mỗi StorageClass trỏ đến path tương ứng trên host

**Nếu StorageClass với basePath không hoạt động (local-path-provisioner không hỗ trợ):**

**Giải pháp thay thế: Sử dụng PersistentVolumes với hostPath**

- [ ] **Tạo PersistentVolumes cho HOT storage:**
  ```bash
  cat <<EOF | kubectl apply -f -
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: hot-storage-pv
  spec:
    capacity:
      storage: 200Gi
    accessModes:
      - ReadWriteOnce
    persistentVolumeReclaimPolicy: Retain
    storageClassName: hot-storage
    hostPath:
      path: /data/hot
  EOF
  ```

- [ ] **Tạo PersistentVolumes cho WARM storage:**
  ```bash
  cat <<EOF | kubectl apply -f -
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: warm-storage-pv
  spec:
    capacity:
      storage: 200Gi
    accessModes:
      - ReadWriteOnce
    persistentVolumeReclaimPolicy: Retain
    storageClassName: warm-storage
    hostPath:
      path: /data/warm
  EOF
  ```

- [ ] **Tạo PersistentVolumes cho COLD storage:**
  ```bash
  cat <<EOF | kubectl apply -f -
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: cold-storage-pv
  spec:
    capacity:
      storage: 800Gi
    accessModes:
      - ReadWriteOnce
    persistentVolumeReclaimPolicy: Retain
    storageClassName: cold-storage
    hostPath:
      path: /data/cold
  EOF
  ```

**Hoặc sử dụng hostPath volumes trực tiếp trong Deployment/Pod specs** (đơn giản nhất):
- Không cần StorageClass hoặc PV
- Mount trực tiếp hostPath trong pod spec
- Phù hợp cho single-node cluster

### Pods
- [ ] Hiểu khái niệm Pod
- [ ] Tạo pod từ YAML: `kubectl apply -f <pod.yaml>`
- [ ] Liệt kê pods: `kubectl get pods` hoặc `kubectl get pods -A`
- [ ] Xem pod details: `kubectl describe pod <pod-name>`
- [ ] Xem pod logs: `kubectl logs <pod-name>`
- [ ] Xóa pod: `kubectl delete pod <pod-name>`

### Deployments
- [ ] Hiểu khái niệm Deployment
- [ ] Tạo deployment: `kubectl create deployment <name> --image=<image>`
- [ ] Tạo deployment từ YAML: `kubectl apply -f <deployment.yaml>`
- [ ] Liệt kê deployments: `kubectl get deployments`
- [ ] Scale deployment: `kubectl scale deployment <name> --replicas=<number>`
- [ ] Xem deployment status: `kubectl rollout status deployment/<name>`
- [ ] Rollback deployment: `kubectl rollout undo deployment/<name>`

### Services
- [ ] Hiểu các loại Service (ClusterIP, NodePort, LoadBalancer)
- [ ] Tạo service: `kubectl create service <type> <name> --tcp=<port>`
- [ ] Tạo service từ YAML: `kubectl apply -f <service.yaml>`
- [ ] Liệt kê services: `kubectl get services` hoặc `kubectl get svc`
- [ ] Port forward: `kubectl port-forward service/<name> <local-port>:<service-port>`
- [ ] Expose deployment: `kubectl expose deployment <name> --type=<type> --port=<port>`

### ConfigMaps & Secrets
- [ ] Hiểu khái niệm ConfigMap
- [ ] Tạo ConfigMap: `kubectl create configmap <name> --from-literal=<key>=<value>`
- [ ] Tạo ConfigMap từ file: `kubectl create configmap <name> --from-file=<file>`
- [ ] Liệt kê ConfigMaps: `kubectl get configmaps`
- [ ] Hiểu khái niệm Secret
- [ ] Tạo Secret: `kubectl create secret generic <name> --from-literal=<key>=<value>`
- [ ] Liệt kê Secrets: `kubectl get secrets`

### Ingress
- [ ] Hiểu khái niệm Ingress
- [ ] Cài đặt Ingress Controller (nginx/traefik)
- [ ] Tạo Ingress resource: `kubectl apply -f <ingress.yaml>`
- [ ] Liệt kê Ingress: `kubectl get ingress`

---

## 🔄 Common Operations

### YAML Files
- [ ] Hiểu cấu trúc YAML cơ bản
- [ ] Tạo pod YAML: `kubectl run <name> --image=<image> --dry-run=client -o yaml`
- [ ] Tạo deployment YAML: `kubectl create deployment <name> --image=<image> --dry-run=client -o yaml`
- [ ] Validate YAML: `kubectl apply --dry-run=client -f <file.yaml>`
- [ ] Format YAML: `kubectl get <resource> <name> -o yaml`

### Debugging
- [ ] Xem logs: `kubectl logs <pod-name>`
- [ ] Xem logs với follow: `kubectl logs -f <pod-name>`
- [ ] Xem logs từ container cụ thể: `kubectl logs <pod-name> -c <container-name>`
- [ ] Exec vào pod: `kubectl exec -it <pod-name> -- /bin/sh`
- [ ] Describe resource: `kubectl describe <resource> <name>`
- [ ] Xem events: `kubectl get events --sort-by=.metadata.creationTimestamp`

### Resource Management
- [ ] Xem resource usage: `kubectl top nodes`
- [ ] Xem pod resource usage: `kubectl top pods`
- [ ] Xem tất cả resources: `kubectl get all`
- [ ] Xem resources trong namespace: `kubectl get all -n <namespace>`
- [ ] Xóa tất cả resources: `kubectl delete all --all`

### Labels & Selectors
- [ ] Hiểu khái niệm Labels và Selectors
- [ ] Thêm label: `kubectl label pod <name> <key>=<value>`
- [ ] Tìm pods theo label: `kubectl get pods -l <key>=<value>`
- [ ] Xóa label: `kubectl label pod <name> <key>-`

---

## 🐛 Troubleshooting

### Cluster Issues
- [ ] Kiểm tra cluster connectivity: `kubectl cluster-info`
- [ ] Kiểm tra nodes status: `kubectl get nodes`
- [ ] Kiểm tra node conditions: `kubectl describe node <node-name>`
- [ ] Restart k3d cluster: `k3d cluster stop <name> && k3d cluster start <name>`

### Pod Issues
- [ ] Kiểm tra pod status: `kubectl get pods`
- [ ] Xem pod events: `kubectl describe pod <pod-name>`
- [ ] Kiểm tra pod logs: `kubectl logs <pod-name>`
- [ ] Kiểm tra pod previous logs: `kubectl logs <pod-name> --previous`
- [ ] Kiểm tra image pull errors
- [ ] Kiểm tra resource limits

### Network Issues
- [ ] Kiểm tra service endpoints: `kubectl get endpoints`
- [ ] Kiểm tra service selector: `kubectl get svc <name> -o yaml`
- [ ] Test connectivity từ pod: `kubectl exec <pod-name> -- curl <service-url>`
- [ ] Kiểm tra DNS: `kubectl exec <pod-name> -- nslookup <service-name>`

### Storage Issues
- [ ] Kiểm tra PersistentVolumes: `kubectl get pv`
- [ ] Kiểm tra PersistentVolumeClaims: `kubectl get pvc`
- [ ] Kiểm tra StorageClass: `kubectl get storageclass`

### Common Commands
- [ ] Xem tất cả resources: `kubectl get all -A`
- [ ] Xem resource với wide output: `kubectl get pods -o wide`
- [ ] Xem resource YAML: `kubectl get <resource> <name> -o yaml`
- [ ] Xem resource JSON: `kubectl get <resource> <name> -o json`

---

## ✅ Best Practices

### Security
- [ ] Không hardcode credentials trong YAML
- [ ] Sử dụng Secrets cho sensitive data
- [ ] Sử dụng RBAC để quản lý permissions
- [ ] Regular update images và dependencies
- [ ] Scan images cho vulnerabilities

### Resource Management
- [ ] Set resource requests và limits cho pods
- [ ] Sử dụng namespaces để organize resources
- [ ] Clean up unused resources định kỳ
- [ ] Monitor resource usage

### Configuration
- [ ] Sử dụng ConfigMaps cho configuration
- [ ] Sử dụng environment variables hợp lý
- [ ] Version control cho YAML files
- [ ] Sử dụng Helm charts cho complex applications

### Development Workflow
- [ ] Sử dụng local k3d cluster cho development
- [ ] Test trên local trước khi deploy production
- [ ] Sử dụng GitOps workflow
- [ ] Document changes và configurations

### Monitoring & Logging
- [ ] Setup monitoring tools (Prometheus/Grafana)
- [ ] Centralized logging (ELK/Loki)
- [ ] Setup alerts cho critical issues
- [ ] Regular review logs và metrics

---

## 📚 Learning Resources

### Documentation
- [ ] Đọc Kubernetes official documentation
- [ ] Đọc k3d documentation
- [ ] Hiểu Kubernetes architecture
- [ ] Học về Kubernetes objects và resources

### Practice
- [ ] Deploy sample applications
- [ ] Practice với các scenarios khác nhau
- [ ] Experiment với các features
- [ ] Join Kubernetes community

### Tools to Learn
- [ ] kubectl commands và options
- [ ] k3d commands và options
- [ ] YAML syntax và structure
- [ ] Container images và Docker

---

## 🎯 Quick Reference Commands

```bash
# k3d
k3d cluster create mycluster
k3d cluster list
k3d cluster delete mycluster
k3d kubeconfig merge mycluster

# kubectl basics
kubectl get pods
kubectl get nodes
kubectl get services
kubectl get deployments

# Apply & Delete
kubectl apply -f file.yaml
kubectl delete -f file.yaml
kubectl delete pod <name>

# Debugging
kubectl logs <pod-name>
kubectl describe pod <pod-name>
kubectl exec -it <pod-name> -- /bin/sh

# Port forwarding
kubectl port-forward service/<name> 8080:80
kubectl port-forward pod/<name> 8080:80
```

---

## 🔄 GitOps Setup (ArgoCD) ⭐ RECOMMENDED

### ArgoCD Installation
- [ ] Install ArgoCD vào cluster
- [ ] Access ArgoCD UI
- [ ] Configure Git repository
- [ ] Setup repository credentials (nếu private)
- [ ] See: [ARGOCD_SETUP_GUIDE.md](./ARGOCD_SETUP_GUIDE.md)

### Git Repository Structure
- [ ] Create Git repository cho K8s manifests (hoặc folder trong repo hiện tại)
- [ ] Organize manifests theo structure (infrastructure/, services/, applications/)
- [ ] Setup Kustomize cho multi-environment (staging/production)
- [ ] Copy existing manifests vào repo structure

### ArgoCD Applications
- [ ] Create Infrastructure Application
- [ ] Create Support Services Application
- [ ] Create Core Services Application
- [ ] Create Integration Services Application
- [ ] Configure sync policies (automated cho staging, manual cho production)

### Deployment Workflow
- [ ] Initial deployment via ArgoCD
- [ ] Test sync từ Git
- [ ] Test rollback
- [ ] Setup CI/CD integration (optional)
- [ ] See: [STAGING_DEPLOYMENT_ARGOCD_PLAN.md](./STAGING_DEPLOYMENT_ARGOCD_PLAN.md)

---

## 🔄 CI/CD Setup (GitLab)

### GitLab CI/CD Configuration
- [ ] **Tạo file `.gitlab-ci.yml`**
  - ✅ **Kết quả:** File đã được tạo với các stages: build, test, build-docker, deploy
- [ ] **Cấu hình GitLab Variables:**
  - [ ] `CI_REGISTRY_USER` - GitLab registry username
  - [ ] `CI_REGISTRY_PASSWORD` - GitLab registry password
  - [ ] `CI_REGISTRY` - GitLab registry URL (registry.gitlab.com)
  - [ ] `K8S_SERVER_IP` - Server IP (192.168.1.112)
  - [ ] `K8S_USER` - SSH user (tuananh)
  - [ ] `K8S_SSH_PRIVATE_KEY` - SSH private key để connect đến server
  - [ ] `KUBERNETES_NAMESPACE` - Default namespace

### Pipeline Stages
- [ ] **Build Stage:**
  - [ ] Build Go services (19 microservices)
  - [ ] Build artifacts
  - [ ] Store artifacts
- [ ] **Test Stage:**
  - [ ] Run unit tests cho Go services
  - [ ] Run integration tests (nếu có)
  - [ ] Code coverage reports
- [ ] **Build Docker Stage:**
  - [ ] Build Docker images cho tất cả services
  - [ ] Tag images với commit SHA và latest
  - [ ] Push images lên GitLab Container Registry
  - [ ] Build Frontend (Next.js)
  - [ ] Build Admin Panel (React)
- [ ] **Deploy Stage:**
  - [ ] Deploy to Staging (develop branch)
  - [ ] Deploy to Production (main branch) - manual approval
  - [ ] Rollout status check
  - [ ] Health checks sau khi deploy

### GitLab Setup Tasks
- [ ] **Setup GitLab Repository:**
  - [ ] Push code lên GitLab
  - [ ] Configure repository settings
  - [ ] Setup branch protection rules
- [ ] **Setup GitLab Container Registry:**
  - [ ] Enable Container Registry trong GitLab project
  - [ ] Verify registry access
  - [ ] Test push/pull images
- [ ] **Setup SSH Keys:**
  - [ ] Generate SSH key pair cho CI/CD
  - [ ] Add public key vào server (authorized_keys)
  - [ ] Add private key vào GitLab CI/CD Variables (K8S_SSH_PRIVATE_KEY)
  - [ ] Test SSH connection từ GitLab runner
- [ ] **Setup Kubernetes Access:**
  - [ ] Copy kubeconfig từ server
  - [ ] Hoặc setup kubectl access qua SSH
  - [ ] Test kubectl commands từ GitLab runner
- [ ] **Create Kubernetes Manifests:**
  - [ ] Tạo thư mục `k8s/` trong repository
  - [ ] Tạo deployment manifests cho từng service
  - [ ] Tạo service manifests
  - [ ] Tạo configmaps và secrets
  - [ ] Tạo ingress resources (nếu cần)

### Kubernetes Manifests Structure
```
k8s/
├── infrastructure/          # Infrastructure services (PostgreSQL, Redis, etc.)
│   ├── postgresql.yaml
│   ├── redis.yaml
│   └── ...
├── services/               # Microservices
│   ├── auth-service/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── configmap.yaml
│   ├── user-service/
│   ├── customer-service/
│   └── ...
├── frontend/               # Frontend deployment
│   ├── deployment.yaml
│   └── service.yaml
└── admin-panel/            # Admin panel deployment
    ├── deployment.yaml
    └── service.yaml
```

### CI/CD Best Practices
- [ ] **Branch Strategy:**
  - [ ] `main` branch → Production deployment (manual approval)
  - [ ] `develop` branch → Staging deployment
  - [ ] Feature branches → Build and test only
- [ ] **Image Tagging:**
  - [ ] Use commit SHA for versioning
  - [ ] Tag latest for easy rollback
  - [ ] Semantic versioning cho releases
- [ ] **Deployment Strategy:**
  - [ ] Rolling updates
  - [ ] Health checks before marking ready
  - [ ] Rollback capability
  - [ ] Blue-green deployment (optional)
- [ ] **Security:**
  - [ ] Scan Docker images for vulnerabilities
  - [ ] Use secrets management (GitLab CI/CD Variables)
  - [ ] Limit SSH key permissions
  - [ ] Use service accounts với minimal permissions

### GitLab Runner Setup (Nếu cần self-hosted)
- [ ] **Install GitLab Runner:**
  - [ ] Trên server hoặc dedicated machine
  - [ ] Register runner với GitLab
  - [ ] Configure runner tags
- [ ] **Runner Configuration:**
  - [ ] Docker executor
  - [ ] Resource limits
  - [ ] Cache configuration

### Monitoring CI/CD
- [ ] **Pipeline Monitoring:**
  - [ ] Track pipeline success/failure rates
  - [ ] Monitor deployment times
  - [ ] Alert on failures
- [ ] **Deployment Monitoring:**
  - [ ] Monitor pod status sau khi deploy
  - [ ] Check service health endpoints
  - [ ] Monitor logs cho errors

---

**Lưu ý:** Checklist này là guide tổng quát. Tùy vào use case cụ thể, bạn có thể cần bổ sung thêm các items phù hợp.

**Ngày tạo:** $(date)
**Version:** 1.0


