# Service Port Mapping

Tài liệu này mô tả port mapping cho tất cả services trong hệ thống.

## Port Mapping Pattern

**Standard Pattern:**
- **Container Ports:** Tất cả services chạy trên port `80` (HTTP) và `81` (gRPC) trong container
- **Host Ports:** Mỗi service có port riêng trên host để tránh conflict

## Service Port Mapping

| Service | Container Ports | Host Ports | Description |
|---------|-----------------|------------|-------------|
| Auth | 80/81 | 8000/9000 | Authentication service |
| User | 80/81 | 8014/9014 | User management service |
| Catalog | 80/81 | 8015/9015 | Product catalog service |
| Customer | 80/81 | 8016/9016 | Customer management service |
| Warehouse Inventory | 80/81 | 8008/9008 | Warehouse and inventory management |
| Order | 80/81 | 8004/9004 | Order management service |
| Payment | 80/81 | 8005/9005 | Payment processing service |
| Shipping | 80/81 | 8006/9006 | Shipping and fulfillment service |
| Notification | 80/81 | 8009/9009 | Notification service |
| Search | 80/81 | 8010/9010 | Search service |
| Review | 80/81 | 8011/9011 | Review and rating service |
| Promotion | 80/81 | 8012/9012 | Promotion and discount service |
| Pricing | 80/81 | 8002/9002 | Pricing service |
| Loyalty Rewards | 80/81 | 8013/9013 | Loyalty and rewards service |
| Gateway | 8080 | 8080 | API Gateway (Kratos) |

## Service Discovery

Tất cả services đăng ký với Consul và có thể được truy cập qua service name:
- **Internal Communication:** `http://service-name:80` hoặc `grpc://service-name:81`
- **External Access:** `http://localhost:XXXX` (host port)

## Example Service Endpoints

```yaml
# Internal (container-to-container)
catalog_service: http://catalog-service:80
user_service: http://user-service:80
warehouse_inventory_service: http://warehouse-inventory-service:80

# External (host access)
catalog_service: http://localhost:8015
user_service: http://localhost:8014
warehouse_inventory_service: http://localhost:8008
```

## Notes

- Tất cả services sử dụng Consul để service discovery
- Health checks chạy trên port 80 trong container
- gRPC services chạy trên port 81 trong container
- Database và Redis services sử dụng shared instances từ main docker-compose

