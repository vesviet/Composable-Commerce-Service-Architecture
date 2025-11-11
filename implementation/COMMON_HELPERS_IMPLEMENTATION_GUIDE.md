# Common Helpers Implementation Guide

## Hướng dẫn implement các common helpers để reuse code

---

## 1. PAGINATION HELPER

### File: `common/utils/pagination/helper.go`

```go
package pagination

import (
	"math"
)

// PaginationInput represents pagination parameters
type PaginationInput struct {
	Page    int32
	Limit   int32
	Offset  int32
	PerPage int32
}

// PaginationOutput represents pagination result
type PaginationOutput struct {
	Page       int32
	Limit      int32
	Total      int32
	TotalPages int32
	HasNext    bool
	HasPrev    bool
}

// NormalizePagination normalizes and validates pagination parameters
func NormalizePagination(page, limit int32) PaginationInput {
	if page <= 0 {
		page = 1
	}
	if limit <= 0 {
		limit = 20 // Default
	}
	if limit > 100 {
		limit = 100 // Max limit
	}
	
	offset := (page - 1) * limit
	
	return PaginationInput{
		Page:    page,
		Limit:   limit,
		Offset:  offset,
		PerPage: limit,
	}
}

// CalculatePagination calculates pagination metadata
func CalculatePagination(page, limit, total int32) PaginationOutput {
	if total == 0 {
		return PaginationOutput{
			Page:       page,
			Limit:      limit,
			Total:      0,
			TotalPages: 1,
			HasNext:    false,
			HasPrev:    false,
		}
	}
	
	totalPages := int32(math.Ceil(float64(total) / float64(limit)))
	if totalPages == 0 {
		totalPages = 1
	}
	
	return PaginationOutput{
		Page:       page,
		Limit:      limit,
		Total:      total,
		TotalPages: totalPages,
		HasNext:    page < totalPages,
		HasPrev:    page > 1,
	}
}

// GetOffsetLimit converts page/limit to offset/limit
func GetOffsetLimit(page, limit int32) (offset, normalizedLimit int32) {
	input := NormalizePagination(page, limit)
	return input.Offset, input.Limit
}
```

### Usage Example:
```go
// In service layer
func (s *Service) ListItems(ctx context.Context, req *pb.ListRequest) (*pb.ListReply, error) {
	// Normalize pagination
	paging := pagination.NormalizePagination(req.Page, req.Limit)
	
	// Fetch data
	items, total, err := s.usecase.List(ctx, paging.Offset, paging.Limit)
	if err != nil {
		return nil, err
	}
	
	// Calculate pagination metadata
	pageMeta := pagination.CalculatePagination(paging.Page, paging.Limit, total)
	
	return &pb.ListReply{
		Items: convertToProto(items),
		Pagination: &v1.Pagination{
			Page:       pageMeta.Page,
			Limit:      pageMeta.Limit,
			Total:      pageMeta.Total,
			TotalPages: pageMeta.TotalPages,
		},
	}, nil
}
```

---

## 2. VALIDATION HELPER

### File: `common/utils/validation/validators.go`

```go
package validation

import (
	"regexp"
	"strings"
)

var (
	emailRegex = regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
	phoneRegex = regexp.MustCompile(`[\s\-\(\)]`)
)

// IsValidEmail validates email format
func IsValidEmail(email string) bool {
	if email == "" {
		return false
	}
	return emailRegex.MatchString(email)
}

// IsValidPhone validates phone format
// Supports international (+country code) and local formats
func IsValidPhone(phone string) bool {
	if phone == "" {
		return false
	}
	
	// Remove spaces, dashes, parentheses
	cleaned := phoneRegex.ReplaceAllString(phone, "")
	
	// International format: + followed by 1-15 digits
	if matched, _ := regexp.MatchString(`^\+[1-9]\d{1,14}$`, cleaned); matched {
		return true
	}
	
	// Local format: 8-15 digits
	if matched, _ := regexp.MatchString(`^\d{8,15}$`, cleaned); matched {
		return true
	}
	
	return false
}

// IsValidURL validates URL format
func IsValidURL(url string) bool {
	if url == "" {
		return false
	}
	return strings.HasPrefix(url, "http://") || strings.HasPrefix(url, "https://")
}

// GenerateSlug generates URL-friendly slug from text
func GenerateSlug(text string) string {
	slug := strings.ToLower(text)
	slug = strings.TrimSpace(slug)
	
	// Replace spaces and underscores with hyphens
	slug = strings.ReplaceAll(slug, " ", "-")
	slug = strings.ReplaceAll(slug, "_", "-")
	
	// Remove special characters (keep only alphanumeric and hyphens)
	slug = regexp.MustCompile(`[^a-z0-9-]+`).ReplaceAllString(slug, "")
	
	// Remove multiple consecutive hyphens
	slug = regexp.MustCompile(`-+`).ReplaceAllString(slug, "-")
	
	// Trim hyphens from start and end
	slug = strings.Trim(slug, "-")
	
	return slug
}

// IsValidPassword validates password strength
func IsValidPassword(password string) (bool, string) {
	if len(password) < 8 {
		return false, "password must be at least 8 characters"
	}
	if len(password) > 128 {
		return false, "password must be at most 128 characters"
	}
	
	// Check for at least one uppercase letter
	if matched, _ := regexp.MatchString(`[A-Z]`, password); !matched {
		return false, "password must contain at least one uppercase letter"
	}
	
	// Check for at least one lowercase letter
	if matched, _ := regexp.MatchString(`[a-z]`, password); !matched {
		return false, "password must contain at least one lowercase letter"
	}
	
	// Check for at least one digit
	if matched, _ := regexp.MatchString(`\d`, password); !matched {
		return false, "password must contain at least one digit"
	}
	
	return true, ""
}

// ValidateRequired checks if required fields are not empty
func ValidateRequired(fields map[string]string) (bool, string) {
	for name, value := range fields {
		if strings.TrimSpace(value) == "" {
			return false, name + " is required"
		}
	}
	return true, ""
}
```

### Usage Example:
```go
// In business logic
func (uc *CustomerUsecase) CreateCustomer(ctx context.Context, req *CreateRequest) error {
	// Validate email
	if !validation.IsValidEmail(req.Email) {
		return errors.NewValidationError("invalid email format")
	}
	
	// Validate phone
	if req.Phone != "" && !validation.IsValidPhone(req.Phone) {
		return errors.NewValidationError("invalid phone format")
	}
	
	// Validate required fields
	if valid, msg := validation.ValidateRequired(map[string]string{
		"email":     req.Email,
		"firstName": req.FirstName,
		"lastName":  req.LastName,
	}); !valid {
		return errors.NewValidationError(msg)
	}
	
	// ... rest of logic
}
```

---

## 3. CACHE HELPER (Generic)

### File: `common/utils/cache/redis_helper.go`

```go
package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/redis/go-redis/v9"
)

// RedisCache is a generic Redis cache helper
type RedisCache struct {
	rdb        *redis.Client
	prefix     string
	defaultTTL time.Duration
	log        *log.Helper
}

// NewRedisCache creates a new Redis cache helper
func NewRedisCache(rdb *redis.Client, prefix string, defaultTTL time.Duration, logger log.Logger) *RedisCache {
	if rdb == nil {
		return nil
	}
	
	return &RedisCache{
		rdb:        rdb,
		prefix:     prefix,
		defaultTTL: defaultTTL,
		log:        log.NewHelper(logger),
	}
}

// Get retrieves a value from cache
func (c *RedisCache) Get(ctx context.Context, key string, dest interface{}) error {
	if c == nil || c.rdb == nil {
		return nil // Cache not available
	}
	
	cacheKey := c.buildKey(key)
	data, err := c.rdb.Get(ctx, cacheKey).Result()
	if err == redis.Nil {
		return nil // Cache miss
	}
	if err != nil {
		c.log.WithContext(ctx).Warnf("Cache get error: %v", err)
		return err
	}
	
	if err := json.Unmarshal([]byte(data), dest); err != nil {
		c.log.WithContext(ctx).Warnf("Cache unmarshal error: %v", err)
		return err
	}
	
	return nil
}

// Set stores a value in cache
func (c *RedisCache) Set(ctx context.Context, key string, value interface{}, ttl ...time.Duration) error {
	if c == nil || c.rdb == nil {
		return nil
	}
	
	data, err := json.Marshal(value)
	if err != nil {
		c.log.WithContext(ctx).Warnf("Cache marshal error: %v", err)
		return err
	}
	
	cacheTTL := c.defaultTTL
	if len(ttl) > 0 {
		cacheTTL = ttl[0]
	}
	
	cacheKey := c.buildKey(key)
	if err := c.rdb.Set(ctx, cacheKey, data, cacheTTL).Err(); err != nil {
		c.log.WithContext(ctx).Warnf("Cache set error: %v", err)
		return err
	}
	
	return nil
}

// Delete removes a value from cache
func (c *RedisCache) Delete(ctx context.Context, keys ...string) error {
	if c == nil || c.rdb == nil {
		return nil
	}
	
	cacheKeys := make([]string, len(keys))
	for i, key := range keys {
		cacheKeys[i] = c.buildKey(key)
	}
	
	if err := c.rdb.Del(ctx, cacheKeys...).Err(); err != nil {
		c.log.WithContext(ctx).Warnf("Cache delete error: %v", err)
		return err
	}
	
	return nil
}

// DeletePattern deletes all keys matching a pattern
func (c *RedisCache) DeletePattern(ctx context.Context, pattern string) error {
	if c == nil || c.rdb == nil {
		return nil
	}
	
	cachePattern := c.buildKey(pattern)
	iter := c.rdb.Scan(ctx, 0, cachePattern, 0).Iterator()
	
	var keys []string
	for iter.Next(ctx) {
		keys = append(keys, iter.Val())
	}
	
	if err := iter.Err(); err != nil {
		c.log.WithContext(ctx).Warnf("Cache scan error: %v", err)
		return err
	}
	
	if len(keys) > 0 {
		if err := c.rdb.Del(ctx, keys...).Err(); err != nil {
			c.log.WithContext(ctx).Warnf("Cache delete pattern error: %v", err)
			return err
		}
	}
	
	return nil
}

// Exists checks if a key exists in cache
func (c *RedisCache) Exists(ctx context.Context, key string) (bool, error) {
	if c == nil || c.rdb == nil {
		return false, nil
	}
	
	cacheKey := c.buildKey(key)
	count, err := c.rdb.Exists(ctx, cacheKey).Result()
	if err != nil {
		c.log.WithContext(ctx).Warnf("Cache exists error: %v", err)
		return false, err
	}
	
	return count > 0, nil
}

// buildKey builds cache key with prefix
func (c *RedisCache) buildKey(key string) string {
	if c.prefix == "" {
		return key
	}
	return fmt.Sprintf("%s:%s", c.prefix, key)
}
```

### Usage Example:
```go
// In usecase
type CustomerUsecase struct {
	repo  CustomerRepo
	cache *cache.RedisCache
	log   *log.Helper
}

func NewCustomerUsecase(repo CustomerRepo, rdb *redis.Client, logger log.Logger) *CustomerUsecase {
	return &CustomerUsecase{
		repo:  repo,
		cache: cache.NewRedisCache(rdb, "customer", 5*time.Minute, logger),
		log:   log.NewHelper(logger),
	}
}

func (uc *CustomerUsecase) GetCustomer(ctx context.Context, id string) (*model.Customer, error) {
	// Try cache first
	var customer model.Customer
	if err := uc.cache.Get(ctx, id, &customer); err == nil && customer.ID != "" {
		return &customer, nil
	}
	
	// Cache miss - fetch from database
	customer, err := uc.repo.FindByID(ctx, id)
	if err != nil {
		return nil, err
	}
	
	// Cache result
	_ = uc.cache.Set(ctx, id, customer)
	
	return customer, nil
}

func (uc *CustomerUsecase) UpdateCustomer(ctx context.Context, req *UpdateRequest) error {
	// Update in database
	if err := uc.repo.Update(ctx, req); err != nil {
		return err
	}
	
	// Invalidate cache
	_ = uc.cache.Delete(ctx, req.ID)
	
	return nil
}
```

---

## 4. REPOSITORY BASE INTERFACE

### File: `common/utils/repository/base_interface.go`

```go
package repository

import (
	"context"
)

// BaseRepository defines common repository operations
// T is the model type, ID is the ID type (usually string or int64)
type BaseRepository[T any, ID any] interface {
	// CRUD Operations
	FindByID(ctx context.Context, id ID) (*T, error)
	Create(ctx context.Context, entity *T) (*T, error)
	Update(ctx context.Context, entity *T, params interface{}) error
	Save(ctx context.Context, entity *T) error
	DeleteByID(ctx context.Context, id ID) error
	DeleteByIDs(ctx context.Context, ids []ID) error
	
	// Batch Operations
	CreateBatch(ctx context.Context, entities []*T) error
	UpdateBatch(ctx context.Context, entities []*T) error
	
	// Query Operations
	FindAll(ctx context.Context) ([]*T, error)
	Count(ctx context.Context) (int64, error)
	Exists(ctx context.Context, id ID) (bool, error)
}

// ListRepository defines list and search operations
type ListRepository[T any] interface {
	List(ctx context.Context, input *ListInput) ([]*T, *Paging, error)
	Search(ctx context.Context, input *ListInput) ([]*T, *Paging, error)
}

// ListInput represents common list/search input
type ListInput struct {
	// Filters
	Keyword  string
	Status   string
	Statuses []string
	
	// Pagination
	Page    int32
	PerPage int32
	Offset  int32
	Limit   int32
	
	// Sorting
	OrderBy   []string
	SortOrder string // ASC or DESC
}

// Paging represents pagination information
type Paging struct {
	Page       int32
	PerPage    int32
	Total      int32
	TotalPages int32
}
```

### Usage Example:
```go
// In your service repository
type CustomerRepository interface {
	repository.BaseRepository[model.Customer, string]
	repository.ListRepository[model.Customer]
	
	// Custom methods specific to Customer
	FindByEmail(ctx context.Context, email string) (*model.Customer, error)
	FindByPhone(ctx context.Context, phone string) (*model.Customer, error)
}
```

---

## 5. EVENT PUBLISHER HELPER

### File: `common/events/publisher_helper.go`

```go
package events

import (
	"context"
	"encoding/json"
	"time"

	"github.com/go-kratos/kratos/v2/log"
)

// EventPublisher interface for publishing events
type EventPublisher interface {
	PublishEvent(ctx context.Context, topic string, event interface{}) error
}

// EventHelper helps with event publishing
type EventHelper struct {
	publisher   EventPublisher
	serviceName string
	log         *log.Helper
}

// NewEventHelper creates a new event helper
func NewEventHelper(publisher EventPublisher, serviceName string, logger log.Logger) *EventHelper {
	if publisher == nil {
		return nil
	}
	
	return &EventHelper{
		publisher:   publisher,
		serviceName: serviceName,
		log:         log.NewHelper(logger),
	}
}

// BaseEvent represents common event fields
type BaseEvent struct {
	EventType   string                 `json:"event_type"`
	ServiceName string                 `json:"service_name"`
	Timestamp   time.Time              `json:"timestamp"`
	Data        map[string]interface{} `json:"data"`
}

// PublishCreated publishes entity created event
func (h *EventHelper) PublishCreated(ctx context.Context, entityType, entityID string, data map[string]interface{}) {
	if h == nil {
		return
	}
	
	event := BaseEvent{
		EventType:   entityType + ".created",
		ServiceName: h.serviceName,
		Timestamp:   time.Now(),
		Data:        data,
	}
	
	if data == nil {
		event.Data = make(map[string]interface{})
	}
	event.Data["entity_id"] = entityID
	
	h.publish(ctx, event.EventType, event)
}

// PublishUpdated publishes entity updated event
func (h *EventHelper) PublishUpdated(ctx context.Context, entityType, entityID string, changes map[string]interface{}) {
	if h == nil {
		return
	}
	
	event := BaseEvent{
		EventType:   entityType + ".updated",
		ServiceName: h.serviceName,
		Timestamp:   time.Now(),
		Data: map[string]interface{}{
			"entity_id": entityID,
			"changes":   changes,
		},
	}
	
	h.publish(ctx, event.EventType, event)
}

// PublishDeleted publishes entity deleted event
func (h *EventHelper) PublishDeleted(ctx context.Context, entityType, entityID string) {
	if h == nil {
		return
	}
	
	event := BaseEvent{
		EventType:   entityType + ".deleted",
		ServiceName: h.serviceName,
		Timestamp:   time.Now(),
		Data: map[string]interface{}{
			"entity_id": entityID,
		},
	}
	
	h.publish(ctx, event.EventType, event)
}

// PublishCustom publishes custom event
func (h *EventHelper) PublishCustom(ctx context.Context, eventType string, data map[string]interface{}) {
	if h == nil {
		return
	}
	
	event := BaseEvent{
		EventType:   eventType,
		ServiceName: h.serviceName,
		Timestamp:   time.Now(),
		Data:        data,
	}
	
	h.publish(ctx, eventType, event)
}

// publish is internal method to publish event
func (h *EventHelper) publish(ctx context.Context, topic string, event interface{}) {
	if err := h.publisher.PublishEvent(ctx, topic, event); err != nil {
		// Log error but don't fail the operation
		h.log.WithContext(ctx).Warnf("Failed to publish event %s: %v", topic, err)
		
		// Optionally: send to dead letter queue or retry mechanism
		h.logFailedEvent(ctx, topic, event, err)
	}
}

// logFailedEvent logs failed event for debugging
func (h *EventHelper) logFailedEvent(ctx context.Context, topic string, event interface{}, err error) {
	eventJSON, _ := json.Marshal(event)
	h.log.WithContext(ctx).Errorf("Failed event - Topic: %s, Event: %s, Error: %v", 
		topic, string(eventJSON), err)
}
```

### Usage Example:
```go
// In usecase
type CustomerUsecase struct {
	repo   CustomerRepo
	events *events.EventHelper
	log    *log.Helper
}

func NewCustomerUsecase(
	repo CustomerRepo,
	eventPublisher events.EventPublisher,
	logger log.Logger,
) *CustomerUsecase {
	return &CustomerUsecase{
		repo:   repo,
		events: events.NewEventHelper(eventPublisher, "customer-service", logger),
		log:    log.NewHelper(logger),
	}
}

func (uc *CustomerUsecase) CreateCustomer(ctx context.Context, req *CreateRequest) (*model.Customer, error) {
	// Create customer
	customer, err := uc.repo.Create(ctx, req)
	if err != nil {
		return nil, err
	}
	
	// Publish event
	uc.events.PublishCreated(ctx, "customer", customer.ID, map[string]interface{}{
		"email":      customer.Email,
		"first_name": customer.FirstName,
		"last_name":  customer.LastName,
	})
	
	return customer, nil
}

func (uc *CustomerUsecase) UpdateCustomer(ctx context.Context, req *UpdateRequest) error {
	// Update customer
	if err := uc.repo.Update(ctx, req); err != nil {
		return err
	}
	
	// Publish event with changes
	changes := map[string]interface{}{
		"first_name": req.FirstName,
		"last_name":  req.LastName,
	}
	uc.events.PublishUpdated(ctx, "customer", req.ID, changes)
	
	return nil
}
```

---

## MIGRATION CHECKLIST

### Phase 1: Create Common Helpers
- [ ] Create `common/utils/pagination/helper.go`
- [ ] Create `common/utils/validation/validators.go`
- [ ] Create `common/utils/cache/redis_helper.go`
- [ ] Create `common/utils/repository/base_interface.go`
- [ ] Create `common/events/publisher_helper.go`

### Phase 2: Update Existing Services
- [ ] Update catalog service to use common helpers
- [ ] Update customer service to use common helpers
- [ ] Update warehouse service to use common helpers
- [ ] Update user service to use common helpers
- [ ] Update auth service to use common helpers

### Phase 3: Documentation & Testing
- [ ] Write unit tests for each helper
- [ ] Update service documentation
- [ ] Create migration guide for other services
- [ ] Add examples to README

---

Generated: 2025-11-10
