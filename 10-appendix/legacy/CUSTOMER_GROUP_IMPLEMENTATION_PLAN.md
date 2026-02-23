# Customer Group Implementation Plan

## 📋 Tổng Quan

Hiện tại hệ thống có **Customer Segments** trong Customer Service nhưng thiếu **Customer Groups API** để:
1. Lấy danh sách groups của một customer
2. Lấy danh sách tất cả available groups
3. Mapping giữa segments và groups cho Catalog Service visibility rules

## 🔍 Phân Tích Hiện Trạng

### ✅ Đã Có

1. **Customer Service**:
   - ✅ Customer Segments table (`customer_segments`)
   - ✅ Segment memberships (`customer_segment_memberships`)
   - ✅ Segment management API (CRUD segments)
   - ✅ Segment assignment logic

2. **Catalog Service**:
   - ✅ `CustomerClient.GetCustomerGroups()` - đã có interface
   - ✅ `CustomerContextBuilder` - build context với groups
   - ✅ `CustomerGroupEvaluator` - evaluate visibility rules
   - ✅ Gọi API `/api/v1/customers/{id}/groups` (chưa tồn tại)

3. **Admin Dashboard**:
   - ✅ `getCustomerGroups()` - gọi `/v1/customer-groups` (chưa tồn tại)
   - ✅ Fallback hardcoded groups: `['VIP', 'Premium', 'B2B', 'Wholesale', 'Regular', 'New']`

### ❌ Thiếu

1. **Customer Service API Endpoints**:
   - ❌ `GET /api/v1/customers/{id}/groups` - Lấy groups của customer
   - ❌ `GET /api/v1/customer-groups` - Lấy danh sách tất cả groups
   - ❌ `GET /api/v1/customer-groups/{id}` - Lấy chi tiết một group

2. **Business Logic**:
   - ❌ Convert segments → groups (có thể segments = groups, hoặc cần mapping)
   - ❌ Get customer groups từ segment memberships
   - ❌ Cache customer groups để tối ưu performance

3. **Proto Definitions**:
   - ❌ `GetCustomerGroupsRequest/Reply` trong customer.proto
   - ❌ `ListCustomerGroupsRequest/Reply` trong customer.proto
   - ❌ `CustomerGroup` message definition

## 🎯 Mục Tiêu Implementation

### Phase 1: Core API (Priority: High)

1. **Proto Definitions**:
   - Thêm `CustomerGroup` message
   - Thêm `GetCustomerGroups` RPC
   - Thêm `ListCustomerGroups` RPC

2. **Business Logic**:
   - Implement `GetCustomerGroupsByCustomerID()` trong SegmentUsecase
   - Implement `ListAllCustomerGroups()` trong SegmentUsecase
   - Logic: Groups = Active Segments (segment name = group name)

3. **Service Layer**:
   - Implement `GetCustomerGroups()` handler
   - Implement `ListCustomerGroups()` handler

4. **HTTP Routes**:
   - `GET /api/v1/customers/{id}/groups` → `GetCustomerGroups`
   - `GET /api/v1/customer-groups` → `ListCustomerGroups`

### Phase 2: Optimization (Priority: Medium)

1. **Caching**:
   - Cache customer groups trong Redis (TTL: 5-10 phút)
   - Cache key: `customer:groups:{customer_id}`
   - Invalidate cache khi segment membership thay đổi

2. **Performance**:
   - Batch load groups cho multiple customers
   - Index optimization cho segment memberships query

### Phase 3: Advanced Features (Priority: Low)

1. **Group Management**:
   - CRUD operations cho groups (nếu khác segments)
   - Group hierarchy (parent-child groups)
   - Group permissions/roles

2. **Analytics**:
   - Group membership statistics
   - Group-based customer analytics

## 📝 Implementation Details

### 1. Proto Definitions

**File**: `customer/api/customer/v1/customer.proto`

```protobuf
// Customer Group message
message CustomerGroup {
  string id = 1;
  string name = 2;
  string description = 3;
  bool is_active = 4;
  int64 customer_count = 5;
  google.protobuf.Timestamp created_at = 6;
  google.protobuf.Timestamp updated_at = 7;
}

// Get customer groups for a specific customer
message GetCustomerGroupsRequest {
  string customer_id = 1;
}

message GetCustomerGroupsReply {
  repeated CustomerGroup groups = 1;
  repeated string group_names = 2; // Simple list of group names for compatibility
}

// List all available customer groups
message ListCustomerGroupsRequest {
  bool include_inactive = 1; // Include inactive groups
}

message ListCustomerGroupsReply {
  repeated CustomerGroup groups = 1;
  repeated string group_names = 2; // Simple list of group names for compatibility
}
```

**Add to CustomerService**:
```protobuf
service CustomerService {
  // ... existing methods ...
  
  // Get customer groups for a specific customer
  rpc GetCustomerGroups(GetCustomerGroupsRequest) returns (GetCustomerGroupsReply) {
    option (google.api.http) = {
      get: "/api/v1/customers/{customer_id}/groups"
    };
  }
  
  // List all available customer groups
  rpc ListCustomerGroups(ListCustomerGroupsRequest) returns (ListCustomerGroupsReply) {
    option (google.api.http) = {
      get: "/api/v1/customer-groups"
    };
  }
}
```

### 2. Business Logic

**File**: `customer/internal/biz/segment/segment.go`

```go
// GetCustomerGroupsByCustomerID gets all active groups (segments) for a customer
func (uc *SegmentUsecase) GetCustomerGroupsByCustomerID(ctx context.Context, customerID string) ([]string, error) {
    // Get active segment memberships
    memberships, err := uc.repo.GetActiveMembershipsByCustomerID(ctx, customerID)
    if err != nil {
        return nil, err
    }
    
    // Extract segment names as group names
    groups := make([]string, 0, len(memberships))
    for _, membership := range memberships {
        if membership.Segment != nil && membership.Segment.IsActive {
            groups = append(groups, membership.Segment.Name)
        }
    }
    
    return groups, nil
}

// ListAllCustomerGroups gets all active customer groups (segments)
func (uc *SegmentUsecase) ListAllCustomerGroups(ctx context.Context, includeInactive bool) ([]*CustomerGroup, error) {
    // Get all segments
    segments, err := uc.repo.ListSegments(ctx, includeInactive)
    if err != nil {
        return nil, err
    }
    
    // Convert segments to groups
    groups := make([]*CustomerGroup, 0, len(segments))
    for _, segment := range segments {
        if includeInactive || segment.IsActive {
            groups = append(groups, &CustomerGroup{
                ID:          segment.ID.String(),
                Name:        segment.Name,
                Description: segment.Description,
                IsActive:    segment.IsActive,
                CreatedAt:   segment.CreatedAt,
                UpdatedAt:   segment.UpdatedAt,
            })
        }
    }
    
    return groups, nil
}
```

### 3. Service Layer

**File**: `customer/internal/service/segment.go`

```go
// GetCustomerGroups gets customer groups for a specific customer
func (s *CustomerService) GetCustomerGroups(ctx context.Context, req *pb.GetCustomerGroupsRequest) (*pb.GetCustomerGroupsReply, error) {
    customerID, err := uuid.Parse(req.CustomerId)
    if err != nil {
        return nil, status.Error(codes.InvalidArgument, "invalid customer ID")
    }
    
    // Get group names
    groupNames, err := s.segmentUC.GetCustomerGroupsByCustomerID(ctx, customerID.String())
    if err != nil {
        return nil, err
    }
    
    // Get full group details
    allGroups, err := s.segmentUC.ListAllCustomerGroups(ctx, false)
    if err != nil {
        return nil, err
    }
    
    // Filter groups by names
    groups := make([]*pb.CustomerGroup, 0)
    groupMap := make(map[string]bool)
    for _, name := range groupNames {
        groupMap[name] = true
    }
    
    for _, group := range allGroups {
        if groupMap[group.Name] {
            groups = append(groups, &pb.CustomerGroup{
                Id:          group.ID,
                Name:        group.Name,
                Description: group.Description,
                IsActive:    group.IsActive,
                CreatedAt:   timestamppb.New(group.CreatedAt),
                UpdatedAt:   timestamppb.New(group.UpdatedAt),
            })
        }
    }
    
    return &pb.GetCustomerGroupsReply{
        Groups:     groups,
        GroupNames: groupNames,
    }, nil
}

// ListCustomerGroups lists all available customer groups
func (s *CustomerService) ListCustomerGroups(ctx context.Context, req *pb.ListCustomerGroupsRequest) (*pb.ListCustomerGroupsReply, error) {
    groups, err := s.segmentUC.ListAllCustomerGroups(ctx, req.IncludeInactive)
    if err != nil {
        return nil, err
    }
    
    // Convert to proto
    pbGroups := make([]*pb.CustomerGroup, 0, len(groups))
    groupNames := make([]string, 0, len(groups))
    for _, group := range groups {
        pbGroups = append(pbGroups, &pb.CustomerGroup{
            Id:          group.ID,
            Name:        group.Name,
            Description: group.Description,
            IsActive:    group.IsActive,
            CreatedAt:   timestamppb.New(group.CreatedAt),
            UpdatedAt:   timestamppb.New(group.UpdatedAt),
        })
        groupNames = append(groupNames, group.Name)
    }
    
    return &pb.ListCustomerGroupsReply{
        Groups:     pbGroups,
        GroupNames: groupNames,
    }, nil
}
```

### 4. Repository Methods

**File**: `customer/internal/data/postgres/segment.go`

```go
// GetActiveMembershipsByCustomerID gets active segment memberships for a customer
func (r *segmentRepo) GetActiveMembershipsByCustomerID(ctx context.Context, customerID string) ([]*model.CustomerSegmentMembership, error) {
    var memberships []*model.CustomerSegmentMembership
    
    err := r.data.db.WithContext(ctx).
        Preload("Segment").
        Where("customer_id = ? AND is_active = ?", customerID, true).
        Where("expires_at IS NULL OR expires_at > ?", time.Now()).
        Find(&memberships).Error
    
    return memberships, err
}
```

### 5. HTTP Routes

Routes sẽ được tự động generate từ proto annotations. Đảm bảo:
- `GET /api/v1/customers/{customer_id}/groups` → `GetCustomerGroups`
- `GET /api/v1/customer-groups` → `ListCustomerGroups`

## 🧪 Testing Plan

### Unit Tests

1. **SegmentUsecase Tests**:
   - `TestGetCustomerGroupsByCustomerID` - Test với customer có nhiều segments
   - `TestGetCustomerGroupsByCustomerID_NoSegments` - Test với customer không có segments
   - `TestListAllCustomerGroups` - Test list với include_inactive = true/false

2. **Service Tests**:
   - `TestGetCustomerGroups` - Test service handler
   - `TestListCustomerGroups` - Test service handler

### Integration Tests

1. **API Tests**:
   - Test `GET /api/v1/customers/{id}/groups` endpoint
   - Test `GET /api/v1/customer-groups` endpoint
   - Test với authentication/authorization

2. **Catalog Service Integration**:
   - Test Catalog Service gọi Customer Service API
   - Test visibility rules evaluation với customer groups

## 📊 Database Changes

**Không cần migration mới** - sử dụng existing tables:
- `customer_segments` - Groups = Active Segments
- `customer_segment_memberships` - Customer-Group relationships

**Optional Index Optimization**:
```sql
-- Index for faster customer groups lookup
CREATE INDEX IF NOT EXISTS idx_segment_memberships_customer_active 
ON customer_segment_memberships(customer_id, is_active) 
WHERE is_active = TRUE;
```

## 🚀 Deployment Steps

1. **Update Proto**:
   ```bash
   cd customer
   make api
   ```

2. **Implement Business Logic**:
   - Add methods to `SegmentUsecase`
   - Add repository methods

3. **Implement Service Handlers**:
   - Add handlers to `CustomerService`

4. **Update Wire**:
   - Ensure dependencies are wired correctly

5. **Test**:
   - Run unit tests
   - Run integration tests
   - Test với Catalog Service

6. **Deploy**:
   - Deploy Customer Service
   - Verify Catalog Service integration
   - Update Admin Dashboard (remove fallback)

## 📝 Notes

1. **Segments vs Groups**: 
   - Hiện tại: **Groups = Active Segments** (segment name = group name)
   - Có thể mở rộng sau: Groups có thể là subset của segments hoặc có mapping riêng

2. **Backward Compatibility**:
   - Admin Dashboard có fallback hardcoded groups
   - Sau khi implement, remove fallback và dùng API

3. **Performance**:
   - Consider caching customer groups trong Redis
   - Cache invalidation khi segment membership thay đổi

4. **Future Enhancements**:
   - Group hierarchy
   - Group permissions
   - Group-based pricing rules
   - Group analytics

## ✅ Checklist

### Phase 1: Core API
- [ ] Add proto definitions (`CustomerGroup`, `GetCustomerGroups`, `ListCustomerGroups`)
- [ ] Generate proto code (`make api`)
- [ ] Implement `GetCustomerGroupsByCustomerID()` in SegmentUsecase
- [ ] Implement `ListAllCustomerGroups()` in SegmentUsecase
- [ ] Add repository method `GetActiveMembershipsByCustomerID()`
- [ ] Implement `GetCustomerGroups()` service handler
- [ ] Implement `ListCustomerGroups()` service handler
- [ ] Add HTTP routes (auto-generated from proto)
- [ ] Write unit tests
- [ ] Write integration tests
- [ ] Test với Catalog Service
- [ ] Update Admin Dashboard (remove fallback)

### Phase 2: Optimization
- [ ] Add Redis caching for customer groups
- [ ] Add cache invalidation on segment membership changes
- [ ] Add database index optimization
- [ ] Performance testing

### Phase 3: Advanced Features
- [ ] Group CRUD operations (if needed)
- [ ] Group hierarchy support
- [ ] Group analytics

## 🔗 Related Files

- `customer/api/customer/v1/customer.proto` - Proto definitions
- `customer/internal/biz/segment/segment.go` - Business logic
- `customer/internal/service/segment.go` - Service handlers
- `customer/internal/data/postgres/segment.go` - Repository
- `catalog/internal/client/customer_client.go` - Catalog client
- `catalog/internal/biz/product_visibility_rule/customer_context.go` - Context builder
- `admin/src/lib/api/catalog-api.ts` - Admin API client

