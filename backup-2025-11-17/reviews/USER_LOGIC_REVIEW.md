# User Create/Update Logic Review

## Tổng quan
Review chi tiết logic tạo mới và update user, so sánh với customer service để tìm issues và best practices.

---

## 1. CREATE USER LOGIC ANALYSIS

### 📍 Flow: Service → Usecase → Repository

#### **Service Layer** (`user/internal/service/user.go:39`)

```go
func (s *UserService) CreateUser(ctx context.Context, req *pb.CreateUserRequest) (*pb.User, error) {
    // ✅ GOOD: Validate password
    if req.Password != "" {
        if err := bizUser.ValidatePassword(req.Password); err != nil {
            return nil, err
        }
    }
    
    // ✅ GOOD: Hash password
    hashed, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
    
    // ⚠️ ISSUE: Complex conversion chain (proto → DTO → model → biz)
    createInput := bizUser.CreateInput{...}
    modelUserInput := createInput.ToModel()
    user := &bizUser.User{...}  // Manual mapping
    
    // ✅ GOOD: Call usecase
    created, err := s.uc.CreateUser(ctx, user, req.InitialRoles)
    
    // ⚠️ ISSUE: Another conversion (biz → model → proto)
    modelUser := s.bizUserToModel(created)
    return modelUser.ToUserReply(), nil
}
```

**Issues**:
1. 🔴 **Too many conversions**: proto → DTO → model → biz → model → proto
2. 🔴 **No email validation** before creating user
3. 🔴 **No uniqueness check** for username/email
4. 🟡 **Password can be empty** - should be required

---

#### **Usecase Layer** (`user/internal/biz/user/user.go:200`)

```go
func (uc *UserUsecase) CreateUser(ctx context.Context, user *User, initialRoles []string) (*User, error) {
    uc.log.WithContext(ctx).Infof("Creating user: %s", user.Username)
    
    // ✅ GOOD: Generate UUID
    user.ID = uuid.New().String()
    
    // ✅ GOOD: Set default status
    if user.Status == 0 {
        user.Status = UserStatusActive
    }
    
    // ❌ CRITICAL: No validation!
    // - No email format check
    // - No username uniqueness check
    // - No email uniqueness check
    // - No required field validation
    
    // ✅ GOOD: Save user
    created, err := uc.userRepo.Save(ctx, user)
    
    // ✅ GOOD: Assign initial roles
    for _, roleIdentifier := range initialRoles {
        // Smart role assignment (by ID or name)
        ...
    }
    
    return created, nil
}
```

**Critical Issues**:
1. 🔴 **No validation** - Missing all business logic validation
2. 🔴 **No uniqueness check** - Can create duplicate users
3. 🔴 **No transaction** - Role assignment can fail after user creation
4. 🔴 **No cache** - No caching strategy
5. 🔴 **No events** - No event publishing

---

#### **Repository Layer** (`user/internal/data/postgres/user.go:44`)

```go
func (r *userRepo) Save(ctx context.Context, u *bizUser.User) (*bizUser.User, error) {
    now := commonTime.TimeToInt(time.Now())
    user := &User{
        ID:           u.ID,
        Username:     u.Username,
        Email:        u.Email,
        // ... other fields
        CreatedAt:    now,
        UpdatedAt:    now,
    }
    
    // ⚠️ ISSUE: Direct Create without checking duplicates
    if err := r.BaseRepo.DB(ctx).Create(user).Error; err != nil {
        return nil, err
    }
    
    return r.convertToBiz(user), nil
}
```

**Issues**:
1. 🟡 **No duplicate check** - Relies on database constraints
2. ✅ **Good**: Simple and clean implementation

---

## 2. UPDATE USER LOGIC ANALYSIS

### 📍 Flow: Service → Usecase → Repository

#### **Service Layer** (`user/internal/service/user.go:129`)

```go
func (s *UserService) UpdateUser(ctx context.Context, req *pb.UpdateUserRequest) (*pb.User, error) {
    // ⚠️ ISSUE: No validation
    
    // Convert proto to biz
    user := &bizUser.User{
        ID:         req.Id,
        FirstName:  updateInput.FirstName,
        LastName:   updateInput.LastName,
        Email:      updateInput.Email,
        Department: updateInput.Department,
        ManagerID:  updateInput.ManagerID,
        Status:     bizUser.UserStatus(updateInput.Status),
    }
    
    // ❌ CRITICAL: Missing Username field!
    // User can't update their username
    
    updated, err := s.uc.UpdateUser(ctx, user)
    
    return modelUser.ToUserReply(), nil
}
```

**Issues**:
1. 🔴 **Missing Username field** - Can't update username
2. 🔴 **No validation** - Email format, uniqueness
3. 🔴 **No existence check** - What if user doesn't exist?
4. 🔴 **No cache invalidation**
5. 🔴 **No event publishing**

---

#### **Usecase Layer** (`user/internal/biz/user/user.go:253`)

```go
func (uc *UserUsecase) UpdateUser(ctx context.Context, user *User) (*User, error) {
    // ❌ CRITICAL: Just passes through to repository!
    // No business logic at all!
    return uc.userRepo.Update(ctx, user)
}
```

**Critical Issues**:
1. 🔴 **No validation** - Zero business logic
2. 🔴 **No existence check**
3. 🔴 **No uniqueness check** for email/username changes
4. 🔴 **No cache invalidation**
5. 🔴 **No event publishing**
6. 🔴 **No transaction** (though not needed for single table)

---

#### **Repository Layer** (`user/internal/data/postgres/user.go:72`)

```go
func (r *userRepo) Update(ctx context.Context, u *bizUser.User) (*bizUser.User, error) {
    // ✅ GOOD: Build update map
    updates := map[string]interface{}{
        "updated_at": commonTime.TimeToInt(time.Now()),
    }
    
    // ✅ GOOD: Only update non-empty fields
    if u.Username != "" {
        updates["username"] = u.Username
    }
    if u.Email != "" {
        updates["email"] = u.Email
    }
    // ... other fields
    
    // ✅ EXCELLENT: Protect password from accidental updates
    if u.PasswordHash != "" {
        updates["password_hash"] = u.PasswordHash
    }
    
    // ✅ GOOD: Use Updates() to only modify specified fields
    if err := r.BaseRepo.DB(ctx).Model(&User{}).Where("id = ?", u.ID).Updates(updates).Error; err != nil {
        return nil, err
    }
    
    // ✅ GOOD: Fetch and return updated user
    return r.FindByID(ctx, u.ID)
}
```

**Good Points**:
1. ✅ **Selective updates** - Only updates provided fields
2. ✅ **Password protection** - Won't clear password accidentally
3. ✅ **Returns updated entity** - Good for verification

**Issues**:
1. 🟡 **No duplicate check** - Can update to duplicate email/username
2. 🟡 **Empty string handling** - Treats empty as "don't update" (might want to clear fields)

---

## 3. COMPARISON WITH CUSTOMER SERVICE

### Customer Service (Better Implementation)

#### **Create Customer** (`customer/internal/biz/customer/customer.go:109`)

```go
func (uc *CustomerUsecase) CreateCustomer(ctx context.Context, req *CreateCustomerRequest) (*model.Customer, error) {
    // ✅ EXCELLENT: Comprehensive validation
    if req.Email == "" {
        return nil, fmt.Errorf("email is required")
    }
    if !isValidEmail(req.Email) {
        return nil, fmt.Errorf("invalid email format")
    }
    
    // ✅ EXCELLENT: Check uniqueness
    existing, err := uc.repo.FindByEmail(ctx, req.Email)
    if existing != nil {
        return nil, fmt.Errorf("customer with email '%s' already exists", req.Email)
    }
    
    // ✅ EXCELLENT: Additional validation
    if req.Phone != "" && !isValidPhone(req.Phone) {
        return nil, fmt.Errorf("invalid phone format")
    }
    if req.DateOfBirth != nil && req.DateOfBirth.After(time.Now()) {
        return nil, fmt.Errorf("date of birth cannot be in the future")
    }
    
    // ✅ EXCELLENT: Transaction for multiple entities
    err = uc.transaction(ctx, func(ctx context.Context) error {
        // Create customer
        if err := uc.repo.Create(ctx, customer); err != nil {
            return fmt.Errorf("failed to create customer: %w", err)
        }
        
        // Create profile
        if err := uc.profileRepo.Create(ctx, profile); err != nil {
            return fmt.Errorf("failed to create customer profile: %w", err)
        }
        
        // Create preferences
        if err := uc.preferencesRepo.Create(ctx, preferences); err != nil {
            return fmt.Errorf("failed to create customer preferences: %w", err)
        }
        
        return nil
    })
    
    // ✅ EXCELLENT: Post-creation actions
    // - Auto-assign segments
    // - Cache the result
    // - Publish events
    
    return customer, nil
}
```

#### **Update Customer** (`customer/internal/biz/customer/customer.go:240`)

```go
func (uc *CustomerUsecase) UpdateCustomer(ctx context.Context, req *UpdateCustomerRequest) (*model.Customer, error) {
    // ✅ EXCELLENT: Get existing first
    existing, err := uc.repo.FindByID(ctx, req.ID.String())
    if existing == nil {
        return nil, fmt.Errorf("customer not found")
    }
    
    // ✅ EXCELLENT: Validate changes
    if req.Phone != "" && !isValidPhone(req.Phone) {
        return nil, fmt.Errorf("invalid phone format")
    }
    
    // ✅ EXCELLENT: Transaction for multiple entities
    err = uc.transaction(ctx, func(ctx context.Context) error {
        // Update customer
        // Update profile
        // Update preferences
        return nil
    })
    
    // ✅ EXCELLENT: Track changes for events
    changes := make(map[string]interface{})
    if req.FirstName != "" {
        changes["firstName"] = req.FirstName
    }
    
    // ✅ EXCELLENT: Cache invalidation
    if uc.cache != nil {
        uc.cache.InvalidateCustomer(ctx, existing.ID)
        uc.cache.SetCustomer(ctx, existing)
    }
    
    // ✅ EXCELLENT: Publish events with changes
    if uc.events != nil && len(changes) > 0 {
        uc.events.PublishCustomerUpdated(ctx, existing, changes)
    }
    
    return existing, nil
}
```

---

## 4. ISSUES SUMMARY

### 🔴 CRITICAL Issues (Must Fix)

#### Create User:
1. **No email validation** - Can create users with invalid emails
2. **No uniqueness check** - Can create duplicate users
3. **No required field validation** - Username, email, password should be required
4. **No transaction** - Role assignment can fail after user creation
5. **Password can be empty** - Should be required for new users

#### Update User:
1. **No validation** - Zero business logic in usecase
2. **No existence check** - Doesn't verify user exists before update
3. **No uniqueness check** - Can update to duplicate email/username
4. **Missing Username field** - Can't update username via UpdateUser
5. **No cache invalidation** - Stale data in cache
6. **No event publishing** - Other services won't know about changes

### 🟡 MEDIUM Issues (Should Fix)

1. **Too many conversions** - proto → DTO → model → biz → model → proto
2. **No caching strategy** - Unlike customer service
3. **No event publishing** - Unlike customer service
4. **Empty string handling** - Unclear if empty means "don't update" or "clear field"

### 🟢 GOOD Points

1. ✅ **Password hashing** - Properly hashed with bcrypt
2. ✅ **Password protection** - Repository won't accidentally clear password
3. ✅ **Smart role assignment** - Can assign by ID or name
4. ✅ **Selective updates** - Only updates provided fields
5. ✅ **UUID generation** - Proper ID generation

---

## 5. RECOMMENDED FIXES

### Fix 1: Add Validation to CreateUser

```go
func (uc *UserUsecase) CreateUser(ctx context.Context, user *User, initialRoles []string) (*User, error) {
    uc.log.WithContext(ctx).Infof("Creating user: %s", user.Username)
    
    // ✅ ADD: Validate required fields
    if user.Username == "" {
        return nil, fmt.Errorf("username is required")
    }
    if user.Email == "" {
        return nil, fmt.Errorf("email is required")
    }
    if user.PasswordHash == "" {
        return nil, fmt.Errorf("password is required")
    }
    
    // ✅ ADD: Validate email format
    if !validation.IsValidEmail(user.Email) {
        return nil, fmt.Errorf("invalid email format")
    }
    
    // ✅ ADD: Check username uniqueness
    existingByUsername, err := uc.userRepo.FindByUsername(ctx, user.Username)
    if err != nil && err != ErrUserNotFound {
        return nil, fmt.Errorf("failed to check username: %w", err)
    }
    if existingByUsername != nil {
        return nil, fmt.Errorf("username '%s' already exists", user.Username)
    }
    
    // ✅ ADD: Check email uniqueness
    existingByEmail, err := uc.userRepo.FindByEmail(ctx, user.Email)
    if err != nil && err != ErrUserNotFound {
        return nil, fmt.Errorf("failed to check email: %w", err)
    }
    if existingByEmail != nil {
        return nil, fmt.Errorf("email '%s' already exists", user.Email)
    }
    
    // Generate UUID
    user.ID = uuid.New().String()
    
    // Set default status
    if user.Status == 0 {
        user.Status = UserStatusActive
    }
    
    // ✅ ADD: Use transaction for user + roles
    var created *User
    err = uc.transaction(ctx, func(ctx context.Context) error {
        // Save user
        var err error
        created, err = uc.userRepo.Save(ctx, user)
        if err != nil {
            return fmt.Errorf("failed to create user: %w", err)
        }
        
        // Assign initial roles
        for _, roleIdentifier := range initialRoles {
            var roleID string
            
            if len(roleIdentifier) != 36 || roleIdentifier[8] != '-' {
                role, err := uc.roleRepo.FindByName(ctx, roleIdentifier)
                if err != nil || role == nil {
                    uc.log.WithContext(ctx).Warnf("Role not found: %s", roleIdentifier)
                    continue
                }
                roleID = role.ID
            } else {
                roleID = roleIdentifier
            }
            
            if roleID != "" {
                if err := uc.permissionRepo.AssignRole(ctx, created.ID, roleID, created.ID); err != nil {
                    return fmt.Errorf("failed to assign role: %w", err)
                }
            }
        }
        
        return nil
    })
    
    if err != nil {
        uc.log.WithContext(ctx).Errorf("Failed to create user: %v", err)
        return nil, err
    }
    
    // ✅ ADD: Cache the result (if cache available)
    if uc.cache != nil {
        if err := uc.cache.SetUser(ctx, created); err != nil {
            uc.log.WithContext(ctx).Warnf("Failed to cache user: %v", err)
        }
    }
    
    // ✅ ADD: Publish event (if events available)
    if uc.events != nil {
        uc.events.PublishUserCreated(ctx, created)
    }
    
    uc.log.WithContext(ctx).Infof("User created successfully: %s", created.ID)
    return created, nil
}
```

---

### Fix 2: Add Validation to UpdateUser

```go
func (uc *UserUsecase) UpdateUser(ctx context.Context, user *User) (*User, error) {
    uc.log.WithContext(ctx).Infof("Updating user: %s", user.ID)
    
    // ✅ ADD: Check if user exists
    existing, err := uc.userRepo.FindByID(ctx, user.ID)
    if err != nil {
        return nil, fmt.Errorf("failed to get user: %w", err)
    }
    if existing == nil {
        return nil, fmt.Errorf("user not found")
    }
    
    // ✅ ADD: Validate email format if changed
    if user.Email != "" && user.Email != existing.Email {
        if !validation.IsValidEmail(user.Email) {
            return nil, fmt.Errorf("invalid email format")
        }
        
        // Check email uniqueness
        existingByEmail, err := uc.userRepo.FindByEmail(ctx, user.Email)
        if err != nil && err != ErrUserNotFound {
            return nil, fmt.Errorf("failed to check email: %w", err)
        }
        if existingByEmail != nil && existingByEmail.ID != user.ID {
            return nil, fmt.Errorf("email '%s' already exists", user.Email)
        }
    }
    
    // ✅ ADD: Validate username uniqueness if changed
    if user.Username != "" && user.Username != existing.Username {
        existingByUsername, err := uc.userRepo.FindByUsername(ctx, user.Username)
        if err != nil && err != ErrUserNotFound {
            return nil, fmt.Errorf("failed to check username: %w", err)
        }
        if existingByUsername != nil && existingByUsername.ID != user.ID {
            return nil, fmt.Errorf("username '%s' already exists", user.Username)
        }
    }
    
    // ✅ ADD: Track changes for events
    changes := make(map[string]interface{})
    if user.FirstName != "" && user.FirstName != existing.FirstName {
        changes["firstName"] = user.FirstName
    }
    if user.LastName != "" && user.LastName != existing.LastName {
        changes["lastName"] = user.LastName
    }
    if user.Email != "" && user.Email != existing.Email {
        changes["email"] = user.Email
    }
    if user.Username != "" && user.Username != existing.Username {
        changes["username"] = user.Username
    }
    
    // Update user
    updated, err := uc.userRepo.Update(ctx, user)
    if err != nil {
        uc.log.WithContext(ctx).Errorf("Failed to update user: %v", err)
        return nil, fmt.Errorf("failed to update user: %w", err)
    }
    
    // ✅ ADD: Cache invalidation
    if uc.cache != nil {
        if err := uc.cache.InvalidateUser(ctx, user.ID); err != nil {
            uc.log.WithContext(ctx).Warnf("Failed to invalidate cache: %v", err)
        }
        // Re-cache updated user
        if err := uc.cache.SetUser(ctx, updated); err != nil {
            uc.log.WithContext(ctx).Warnf("Failed to cache updated user: %v", err)
        }
    }
    
    // ✅ ADD: Publish events with changes
    if uc.events != nil && len(changes) > 0 {
        uc.events.PublishUserUpdated(ctx, updated, changes)
    }
    
    uc.log.WithContext(ctx).Infof("User updated successfully: %s", updated.ID)
    return updated, nil
}
```

---

### Fix 3: Add Username to UpdateUser Service

```go
func (s *UserService) UpdateUser(ctx context.Context, req *pb.UpdateUserRequest) (*pb.User, error) {
    s.log.WithContext(ctx).Infof("UpdateUser: id=%s", req.Id)
    
    // Convert proto to biz
    user := &bizUser.User{
        ID:         req.Id,
        Username:   req.Username,    // ✅ ADD: Include username
        FirstName:  req.FirstName,
        LastName:   req.LastName,
        Email:      req.Email,
        Department: req.Department,
        ManagerID:  req.ManagerId,
        Status:     bizUser.UserStatus(req.Status),
    }
    
    updated, err := s.uc.UpdateUser(ctx, user)
    if err != nil {
        return nil, err
    }
    
    modelUser := s.bizUserToModel(updated)
    return modelUser.ToUserReply(), nil
}
```

---

## 6. TESTING CHECKLIST

### Create User Tests:
- [ ] Create with valid data succeeds
- [ ] Create with duplicate username fails
- [ ] Create with duplicate email fails
- [ ] Create with invalid email fails
- [ ] Create without username fails
- [ ] Create without email fails
- [ ] Create without password fails
- [ ] Role assignment works correctly
- [ ] Transaction rollback on role assignment failure
- [ ] Cache is populated after creation
- [ ] Event is published after creation

### Update User Tests:
- [ ] Update with valid data succeeds
- [ ] Update non-existent user fails
- [ ] Update to duplicate username fails
- [ ] Update to duplicate email fails
- [ ] Update with invalid email fails
- [ ] Can update username
- [ ] Can update email
- [ ] Can update status
- [ ] Password is not cleared on update
- [ ] Cache is invalidated after update
- [ ] Event is published with changes

---

## 7. MIGRATION PLAN

### Phase 1: Add Validation (Week 1)
1. Add email validation to CreateUser
2. Add uniqueness checks to CreateUser
3. Add required field validation
4. Add validation to UpdateUser
5. Add existence check to UpdateUser

### Phase 2: Add Transaction (Week 1)
1. Wrap CreateUser in transaction
2. Test rollback scenarios

### Phase 3: Add Cache & Events (Week 2)
1. Create cache helper for user
2. Add cache operations to CreateUser
3. Add cache operations to UpdateUser
4. Create event helper for user
5. Add event publishing

### Phase 4: Fix Service Layer (Week 2)
1. Add Username to UpdateUserRequest proto
2. Update service layer to include username
3. Simplify conversion chain

### Phase 5: Testing (Week 3)
1. Write unit tests
2. Write integration tests
3. Manual testing

---

## 8. ESTIMATED IMPACT

### Code Quality:
- ✅ Prevent duplicate users
- ✅ Prevent invalid data
- ✅ Consistent with customer service
- ✅ Better error messages
- ✅ Proper transaction handling

### Performance:
- ✅ Cache reduces database load
- ⚠️ Additional validation queries (acceptable trade-off)

### Maintainability:
- ✅ Clear business logic
- ✅ Easier to test
- ✅ Easier to debug

---

Generated: 2025-11-10
Services reviewed: user, customer
