# 🏗️ Security Architecture

**Purpose**: Complete security framework and architecture design  
**Last Updated**: 2026-03-02  
**Status**: 🔄 In Progress - Architecture defined, implementation ongoing

---

## 📋 Overview

This document describes the comprehensive security architecture for our microservices platform. The architecture follows defense-in-depth principles with multiple layers of security controls to protect against various threats.

---

## 🎯 Security Principles

### **Defense in Depth**
- **Multiple Layers**: Security controls at every layer
- **Redundancy**: Multiple security mechanisms
- **Diversity**: Different security approaches
- **Compromise Containment**: Limit blast radius

### **Zero Trust Architecture**
- **Never Trust**: Always verify authentication and authorization
- **Least Privilege**: Minimum necessary access
- **Micro-Segmentation**: Network and application segmentation
- **Continuous Monitoring**: Real-time security monitoring

### **Security by Design**
- **Built-in Security**: Security considerations from design
- **Default Secure**: Secure configurations by default
- **Fail Secure**: Secure failure modes
- **Transparency**: Open and auditable security

---

## 🏗️ Security Architecture Overview

### **Layered Security Model**

```mermaid
graph TB
    subgraph "External Security Layer"
        A1[WAF Protection]
        A2[DDoS Protection]
        A3[CDN Security]
        A4[Rate Limiting]
    end
    
    subgraph "Network Security Layer"
        B1[Firewall Rules]
        B2[Network Segmentation]
        B3[Service Mesh]
        B4[Ingress Control]
    end
    
    subgraph "Application Security Layer"
        C1[API Gateway]
        C2[Service Authentication]
        C3[Authorization]
        C4[Input Validation]
    end
    
    subgraph "Data Security Layer"
        D1[Encryption at Rest]
        D2[Encryption in Transit]
        D3[Key Management]
        D4[Access Controls]
    end
    
    subgraph "Identity & Access Layer"
        E1[Authentication]
        E2[Authorization]
        E3[Session Management]
        E4[Audit Logging]
    end
    
    A1 --> B1
    A2 --> B2
    A3 --> B3
    A4 --> B4
    
    B1 --> C1
    B2 --> C2
    B3 --> C3
    B4 --> C4
    
    C1 --> D1
    C2 --> D2
    C3 --> D3
    C4 --> D4
    
    D1 --> E1
    D2 --> E2
    D3 --> E3
    D4 --> E4
```

---

## 🔐 Identity & Access Management

### **Authentication Architecture**

#### **Multi-Factor Authentication (MFA)**
```mermaid
sequenceDiagram
    participant User
    participant Gateway
    participant Auth Service
    participant MFA Service
    participant Identity Provider
    
    User->>Gateway: Login Request
    Gateway->>Auth Service: Authenticate
    Auth Service->>Identity Provider: Validate Credentials
    Identity Provider-->>Auth Service: User Validated
    Auth Service->>MFA Service: Send MFA Challenge
    MFA Service-->>User: MFA Prompt
    User->>MFA Service: MFA Response
    MFA Service-->>Auth Service: MFA Validated
    Auth Service-->>Gateway: JWT Token
    Gateway-->>User: Authentication Success
```

#### **JWT Token Structure**
```json
{
  "header": {
    "alg": "RS256",
    "typ": "JWT",
    "kid": "key-id"
  },
  "payload": {
    "sub": "user-123",
    "iss": "auth-service",
    "aud": "api-gateway",
    "exp": 1643942400,
    "iat": 1643938800,
    "jti": "token-id",
    "scope": ["read", "write"],
    "roles": ["admin", "user"],
    "permissions": ["orders:read", "payments:write"]
  },
  "signature": "signature-hash"
}
```

### **Authorization Architecture**

#### **Role-Based Access Control (RBAC)**
```yaml
# Role Definitions
roles:
  - name: "admin"
    permissions:
      - "*:*"  # All permissions
    
  - name: "order-manager"
    permissions:
      - "orders:*"
      - "customers:read"
      - "products:read"
    
  - name: "customer-service"
    permissions:
      - "customers:*"
      - "orders:read"
      - "products:read"

# Service Permissions
services:
  - name: "order-service"
    permissions:
      - "orders:create"
      - "orders:read"
      - "orders:update"
      - "payments:create"
    
  - name: "payment-service"
    permissions:
      - "payments:*"
      - "orders:read"
```

---

## 🌐 Network Security

### **Network Segmentation**

#### **Kubernetes Network Policies**
```yaml
# Default deny all traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

---
# Allow traffic from gateway to services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-gateway-to-services
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: order-service
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api-gateway
    ports:
    - protocol: TCP
      port: 8080

---
# Allow service-to-service communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-service-to-service
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: payment-service
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: order-service
    ports:
    - protocol: TCP
      port: 8080
```

#### **Service Mesh Security (Dapr)**

Our platform uses **Dapr** as the service mesh for inter-service communication. Dapr sidecars handle mTLS, access control, and service invocation.

```yaml
# Dapr sidecar mTLS is enabled by default when Dapr is installed
# with mtls.enabled=true in the Dapr system configuration.
#
# Service-to-service communication is secured via:
# 1. Dapr sidecar-to-sidecar mTLS (automatic certificate rotation)
# 2. Dapr access control policies (app-level authorization)
# 3. Kubernetes Network Policies (network-level isolation)

apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: dapr-config
  namespace: production
spec:
  mtls:
    enabled: true
    workloadCertTTL: "24h"
    allowedClockSkew: "15m"
  accessControl:
    defaultAction: deny
    policies:
    - appId: order-service
      defaultAction: deny
      operations:
      - name: /api/*
        httpVerb: ["GET", "POST", "PUT", "DELETE"]
        action: allow
```


---

## 🛡️ Application Security

### **API Security Architecture**

#### **Custom API Gateway Security**

Our platform uses a **custom Go-based API gateway** (not Kong). The gateway handles JWT validation, RBAC, rate limiting, and request routing.

```yaml
# Gateway security configuration (configs/config.yaml)
gateway:
  port: 8080
  timeout: 30s

authentication:
  jwt:
    issuer: "auth-service"
    algorithms: ["RS256"]
    public_key_path: "/etc/gateway/jwt-public.pem"

rate_limiting:
  default:
    requests_per_second: 100
    burst: 200
  per_user:
    requests_per_second: 50
    burst: 100

routing:
  services:
    - name: order-service
      prefix: /api/v1/orders
      methods: [GET, POST, PUT, DELETE]
      auth_required: true
      roles: [admin, order-manager]
```


#### **Input Validation**
```go
// Input validation middleware
func ValidationMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Validate content type
        if r.Header.Get("Content-Type") != "application/json" {
            http.Error(w, "Invalid content type", http.StatusBadRequest)
            return
        }
        
        // Validate request size
        if r.ContentLength > 10*1024*1024 { // 10MB limit
            http.Error(w, "Request too large", http.StatusRequestEntityTooLarge)
            return
        }
        
        // Validate JSON structure
        var body map[string]interface{}
        if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
            http.Error(w, "Invalid JSON", http.StatusBadRequest)
            return
        }
        
        next.ServeHTTP(w, r)
    })
}
```

---

## 💾 Data Security

### **Encryption Architecture**

#### **Encryption at Rest**
```yaml
# Kubernetes Secret Encryption
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64-encoded-32-byte-key>
      - identity: {}

---
# Persistent Volume Encryption
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: encrypted-pvc
  namespace: production
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: encrypted-ssd
  resources:
    requests:
      storage: 100Gi
```

#### **Encryption in Transit**
```yaml
# TLS Configuration
apiVersion: v1
kind: Secret
metadata:
  name: tls-certificate
  namespace: production
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-certificate>
  tls.key: <base64-encoded-private-key>

---
# Service TLS Configuration
apiVersion: v1
kind: Service
metadata:
  name: secure-service
  namespace: production
spec:
  selector:
    app: secure-service
  ports:
  - port: 443
    targetPort: 8443
  tls:
    - secretName: tls-certificate
      ports:
        - port: 443
```

### **Key Management**

#### **HashiCorp Vault Integration (🔄 Planned)**

> **Note**: Vault integration is planned but not yet deployed. Currently, secrets are managed via Kubernetes Sealed Secrets.

```yaml
# Target Vault Configuration (planned)
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-config
  namespace: production
data:
  vault.hcl: |
    ui = true
    
    listener "tcp" {
      address = "0.0.0.0:8200"
      tls_disable = 1
    }
    
    storage "consul" {
      address = "consul.production.svc.cluster.local:8500"
      path = "vault/"
    }
    
    api_addr = "http://vault.production.svc.cluster.local:8200"
    cluster_addr = "http://vault.production.svc.cluster.local:8201"
```

---

## 🔍 Security Monitoring

### **Threat Detection Architecture**

#### **Security Information and Event Management (SIEM)**
```mermaid
graph LR
    A[Applications] --> B[Log Collectors]
    C[Infrastructure] --> B
    D[Network Devices] --> B
    
    B --> E[Log Aggregation]
    E --> F[SIEM Engine]
    
    F --> G[Correlation Rules]
    F --> H[Threat Intelligence]
    F --> I[Machine Learning]
    
    G --> J[Alert Generation]
    H --> J
    I --> J
    
    J --> K[Security Dashboard]
    J --> L[Incident Response]
```

#### **Falco Security Rules (🔄 Planned)**

> **Note**: Falco is planned for runtime container security monitoring but not yet deployed.

```yaml
# Target Falco Rules for Container Security (planned)
- rule: Detect shell in container
  desc: >
    A shell was spawned by a process in a container.
  condition: >
    spawned_process and
    container and
    proc.name in (bash, sh, zsh, fish, csh, tcsh, ksh) and
    not user_expected_shell_spawn
  output: >
    Shell spawned in container (user=%user.name container=%container.name
    shell=%proc.name parent=%proc.pname cmdline=%proc.cmdline)
  priority: WARNING
  tags: [container, shell]

- rule: Detect sudo usage in container
  desc: >
    Sudo was executed in a container.
  condition: >
    spawned_process and
    container and
    proc.name = sudo and
    not user_expected_sudo_usage
  output: >
    Sudo executed in container (user=%user.name container=%container.name
    command=%proc.cmdline)
  priority: WARNING
  tags: [container, sudo]
```

---

## 🚨 Incident Response Architecture

### **Incident Response Workflow**

```mermaid
graph TB
    A[Security Event] --> B{Threat Detection}
    B -->|Automated| C[SIEM Alert]
    B -->|Manual| D[Security Team]
    
    C --> E[Alert Triage]
    D --> E
    
    E --> F{Incident Severity}
    F -->|Critical| G[Immediate Response]
    F -->|High| H[Priority Response]
    F -->|Medium| I[Standard Response]
    F -->|Low| J[Informational]
    
    G --> K[Incident Commander]
    H --> L[Security Analyst]
    I --> M[On-call Engineer]
    J --> N[Documentation]
    
    K --> O[Containment]
    L --> O
    M --> O
    
    O --> P[Eradication]
    P --> Q[Recovery]
    Q --> R[Post-Incident Review]
```

### **Automated Response**

#### **Security Automation**
```yaml
# Automated Security Response
apiVersion: v1
kind: ConfigMap
metadata:
  name: security-automation
  namespace: production
data:
  automation.yaml: |
    rules:
      - name: isolate-compromised-pod
        trigger:
          event_type: security_alert
          severity: critical
          source: falco
          rule: detect_shell_in_container
        actions:
          - type: isolate_pod
            parameters:
              pod_name: "{{ .container.name }}"
              namespace: "{{ .kubernetes.namespace_name }}"
          - type: create_ticket
            parameters:
              title: "Security Incident: Compromised Container"
              severity: "critical"
              description: "Container {{ .container.name }} isolated due to suspicious activity"
          - type: notify_team
            parameters:
              channel: "#security-incidents"
              message: "Critical security incident detected in {{ .container.name }}"
```

---

## 🔧 Implementation Details

### **Kubernetes Security**

#### **Pod Security Standards**

We use **Pod Security Standards** (which replaced the deprecated PodSecurityPolicy in K8s 1.25+) to enforce security baselines at the namespace level.

```yaml
# Enforce restricted Pod Security Standards on production namespace
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

All deployments must comply with the restricted profile:
- Containers run as non-root (`runAsNonRoot: true`)
- No privilege escalation (`allowPrivilegeEscalation: false`)
- All capabilities dropped (`drop: ["ALL"]`)
- Read-only root filesystem (`readOnlyRootFilesystem: true`)
- Restricted volume types only

```yaml
# Example compliant pod security context
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: order-service
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
```


#### **RBAC Configuration**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: service-account-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: service-account-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: order-service
  namespace: production
roleRef:
  kind: Role
  name: service-account-role
  apiGroup: rbac.authorization.k8s.io
```

---

## 📊 Security Metrics

### **Key Security Indicators (KSIs)**

#### **Security Posture Metrics**
- **Vulnerability Score**: CVSS score aggregation
- **Compliance Score**: Regulatory compliance percentage
- **Security Coverage**: Security controls coverage
- **Risk Score**: Overall security risk assessment

#### **Operational Metrics**
- **Mean Time to Detect (MTTD)**: Threat detection time
- **Mean Time to Respond (MTTR)**: Incident response time
- **False Positive Rate**: Alert accuracy
- **Security Incident Rate**: Incidents per month

#### **Compliance Metrics**
- **Policy Compliance**: Security policy adherence
- **Audit Findings**: Internal/external audit results
- **Training Completion**: Security training coverage
- **Access Review Completion**: Access certification rate

---

## 📚 Related Documentation

### **Implementation Guides**
- [Authentication & Authorization](./AUTH_AUTHZ.md) - Identity management
- [Incident Response](./INCIDENT_RESPONSE.md) - Security incidents

---

**Last Updated**: 2026-03-02  
**Review Cycle**: Monthly  
**Maintained By**: Security & Platform Engineering Teams
