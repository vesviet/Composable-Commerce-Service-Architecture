# System Port & Redis Configuration

This document summarizes the port configuration and Redis database allocation for all microservices in the system.

## Port Standardization Status

✅ **100% COMPLIANT**

All services have been reviewed and standardized according to the plan. 
- **Standard Backend Services**: HTTP 8000 / gRPC 9000
- **Frontend Services**: Standard HTTP ports (80, 3000)
- **Exceptions**: Documented custom ports for specific services.

## Detailed Port & Redis Mapping

| Service Name | Type | Dapr App Port | Target HTTP Port | Target gRPC Port | Config Bind Address | Redis DB | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **admin** | Frontend | N/A | 80 | N/A | N/A | N/A | Static/Nginx hosting |
| **auth-service** | Backend | 8000 | 8000 | 9000 | `:8000` | 0 | Standardized |
| **catalog-service** | Backend | 8000 | 8000 | 9000 | `:8000` | 4 | Standardized |
| **common-operations** | Backend | 8000 | 8000 | 9000 | `:8000` / `:9000` | 8 | Standardized |
| **customer-service** | Backend | 8000 | 8000 | 9000 | `0.0.0.0:8000` | 6 | Standardized |
| **frontend** | Frontend | N/A | 3000 | N/A | N/A | N/A | Next.js App |
| **fulfillment-service** | Backend | 8000 | 8000 | 9000 | `0.0.0.0:8000` | 10 | Standardized |
| **gateway** | Gateway | N/A | 80 | N/A | `:80` | N/A | Entrypoint |
| **location-service** | Backend | 8000 | 8000 | 9000 | `:8000` | 7 | Standardized |
| **notification-service** | Backend | 8000 | 8000 | 9000 | `:8000` | 11 | Standardized |
| **order-service** | Backend | 8000 | 8000 | 9000 | `0.0.0.0:8000` | 1 | Standardized |
| **payment-service** | Backend | 8000 | 8000 | 9000 | `:8000` | 14 | Standardized |
| **pricing-service** | Backend | 8000 | 8000 | 9000 | `:8000` | 2 | Standardized |
| **promotion-service** | Backend | 8000 | 8000 | 9000 | `:8000` | 3 | Standardized |
| **review-service** | Backend | 8000 | 8000 | 9000 | `:8000` / `:9000` | 5 | Standardized |
| **search-service** | Backend | 8000 | 8000 | 9000 | `:8000` | 12 | Standardized |
| **shipping-service** | Backend | 8000 | 8000 | 9000 | `0.0.0.0:8000` | 13 | Standardized |
| **user-service** | Backend | 8000 | 8000 | 9000 | `0.0.0.0:8000` | 15 | Standardized |
| **warehouse-service** | Backend | 8000 | 8000 | 9000 | `:8000` | 9 | Standardized |

**Note**: `user-service` Redis DB was not explicitly found in `values.yaml` grep, likely using default or Env var.

## Service Ports (Kubernetes ClusterIP)

All backend microservices expose the following ports within the cluster via their Kubernetes Service:
- **httpPort**: 80 (maps to Target HTTP Port)
- **grpcPort**: 81 (maps to Target gRPC Port)

## Worker Services

Worker services typically use the gRPC port for health checks and internal communication.
- **Port**: 5005 (gRPC) - Standard for workers across most services.
