# 🌐 I18n Migration to Notification Service - Complete Checklist

**Target**: Integrate i18n system directly into Notification Service  
**Timeline**: 8-10 weeks  
**Goal**: Complete Vietnamese + English support across all services

---

## 📋 **PHASE 1: NOTIFICATION SERVICE FOUNDATION (Weeks 1-2)**

### Week 1: Database & Model Setup

#### Day 1: Database Schema
- [ ] **Create i18n migration file**
  ```bash
  # notification/migrations/003_create_i18n_messages.sql
  ```
- [ ] **Design messages table schema**
  ```sql
  CREATE TABLE messages (
    id BIGSERIAL PRIMARY KEY,
    key VARCHAR(255) UNIQUE NOT NULL,
    category VARCHAR(100),
    description TEXT,
    translations JSONB DEFAULT '{}' NOT NULL,
    variables JSONB DEFAULT '{}' NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
  );
  ```
- [ ] **Add indexes for performance**
  ```sql
  CREATE INDEX idx_messages_key ON messages(key);
  CREATE INDEX idx_messages_category ON messages(category);
  CREATE INDEX idx_messages_translations ON messages USING GIN(translations);
  ```
- [ ] **Run migration on dev environment**
- [ ] **Test migration rollback**

#### Day 2: Data Models
- [ ] **Create message model**
  ```go
  // notification/internal/model/message.go
  type Message struct {
    ID           int64           `gorm:"primaryKey"`
    Key          string          `gorm:"uniqueIndex;not null"`
    Category     string          `gorm:"size:100"`
    Description  string          `gorm:"type:text"`
    Translations json.RawMessage `gorm:"type:jsonb;default:'{}'"`
    Variables    json.RawMessage `gorm:"type:jsonb;default:'{}'"`
    CreatedAt    time.Time
    UpdatedAt    time.Time
  }
  ```
- [ ] **Add translation helper methods**
  ```go
  func (m *Message) GetTranslation(language string) (*Translation, error)
  func (m *Message) SetTranslation(language, content string, variables map[string]string) error
  ```
- [ ] **Create translation struct**
  ```go
  type Translation struct {
    Language  string            `json:"language"`
    Content   string            `json:"content"`
    Variables map[string]string `json:"variables,omitempty"`
  }
  ```
- [ ] **Update wire.go for new dependencies**

#### Day 3: Repository Layer
- [ ] **Create message repository interface**
  ```go
  // notification/internal/biz/message/repository.go
  type MessageRepo interface {
    GetMessage(ctx context.Context, key string) (*model.Message, error)
    GetMessages(ctx context.Context, keys []string) ([]*model.Message, error)
    UpsertMessage(ctx context.Context, message *model.Message) error
    ListMessages(ctx context.Context, category string, page, pageSize int) ([]*model.Message, int, error)
    DeleteMessage(ctx context.Context, key string) error
  }
  ```
- [ ] **Implement PostgreSQL repository**
  ```go
  // notification/internal/data/message_repo.go
  type messageRepository struct {
    db *gorm.DB
  }
  ```
- [ ] **Add repository to data provider**
- [ ] **Write repository unit tests**

#### Day 4: Business Logic Layer
- [ ] **Create message usecase**
  ```go
  // notification/internal/biz/message/message.go
  type MessageUsecase struct {
    repo      MessageRepo
    cache     MessageCache
    publisher EventPublisher
  }
  ```
- [ ] **Implement core methods**
  ```go
  func (uc *MessageUsecase) GetMessage(ctx context.Context, key, language string, variables map[string]string) (string, bool, error)
  func (uc *MessageUsecase) GetMessages(ctx context.Context, keys []string, language string, variables map[string]map[string]string) (map[string]string, []string, error)
  func (uc *MessageUsecase) UpsertMessage(ctx context.Context, req *UpsertMessageRequest) (*model.Message, error)
  ```
- [ ] **Add variable replacement logic**
- [ ] **Add fallback mechanism (vi → en → key)**
- [ ] **Write business logic unit tests**

#### Day 5: Cache Layer
- [ ] **Create message cache interface**
  ```go
  // notification/internal/cache/message_cache.go
  type MessageCache interface {
    GetMessage(ctx context.Context, key, language string) (string, error)
    SetMessage(ctx context.Context, key, language, content string, ttl time.Duration) error
    InvalidateMessage(ctx context.Context, key string) error
    InvalidateCategory(ctx context.Context, category string) error
  }
  ```
- [ ] **Implement Redis cache**
  ```go
  type messageCache struct {
    rdb *redis.Client
    ttl time.Duration
  }
  ```
- [ ] **Add cache warming strategy**
- [ ] **Add cache metrics**
- [ ] **Test cache performance**

### Week 2: API & Service Layer

#### Day 6: Proto Definitions
- [ ] **Extend notification.proto with i18n methods**
  ```protobuf
  // api/notification/v1/notification.proto
  service NotificationService {
    // Existing methods...
    
    // i18n methods
    rpc GetMessage(GetMessageRequest) returns (GetMessageResponse);
    rpc GetMessages(GetMessagesRequest) returns (GetMessagesResponse);
    rpc UpsertMessage(UpsertMessageRequest) returns (UpsertMessageResponse);
    rpc ListMessages(ListMessagesRequest) returns (ListMessagesResponse);
  }
  ```
- [ ] **Define request/response messages**
- [ ] **Generate Go code from proto**
  ```bash
  make api
  ```
- [ ] **Update API documentation**

#### Day 7: gRPC Service Implementation
- [ ] **Extend NotificationService struct**
  ```go
  // notification/internal/service/notification_service.go
  type NotificationService struct {
    // Existing fields...
    messageUC *message.MessageUsecase
  }
  ```
- [ ] **Implement i18n gRPC methods**
  ```go
  func (s *NotificationService) GetMessage(ctx context.Context, req *pb.GetMessageRequest) (*pb.GetMessageResponse, error)
  func (s *NotificationService) GetMessages(ctx context.Context, req *pb.GetMessagesRequest) (*pb.GetMessagesResponse, error)
  func (s *NotificationService) UpsertMessage(ctx context.Context, req *pb.UpsertMessageRequest) (*pb.UpsertMessageResponse, error)
  ```
- [ ] **Add input validation**
- [ ] **Add error handling**
- [ ] **Write service unit tests**

#### Day 8: HTTP API Layer
- [ ] **Add HTTP endpoints**
  ```go
  // notification/internal/server/http.go
  // GET /api/v1/messages/{key}
  // POST /api/v1/messages/batch
  // POST /api/v1/messages
  // GET /api/v1/messages
  ```
- [ ] **Implement HTTP handlers**
- [ ] **Add OpenAPI documentation**
- [ ] **Test HTTP endpoints with Postman**

#### Day 9: Integration with Existing Templates
- [ ] **Update template service to use i18n**
  ```go
  // notification/internal/biz/template/template.go
  func (uc *TemplateUsecase) RenderTemplate(templateID, language string, data map[string]interface{}) (*RenderResult, error) {
    // Get localized template content
    template := uc.getLocalizedTemplate(templateID, language)
    
    // Render with i18n message lookups
    content := uc.renderWithI18n(template, data, language)
    
    return &RenderResult{Content: content}, nil
  }
  ```
- [ ] **Add backward compatibility for existing templates**
- [ ] **Create migration script for existing templates**
- [ ] **Test template rendering with i18n**

#### Day 10: Comprehensive Message Seeding
- [ ] **Create comprehensive seed script**
  ```sql
  -- notification/scripts/seed-comprehensive-i18n-messages.sql
  
  -- ================================
  -- VALIDATION MESSAGES
  -- ================================
  INSERT INTO messages (key, category, description, translations) VALUES
  ('error.validation.required', 'validation', 'Required field validation error', '{
    "en": {"language": "en", "content": "This field is required"},
    "vi": {"language": "vi", "content": "Trường này là bắt buộc"}
  }'),
  ('error.validation.email', 'validation', 'Email format validation error', '{
    "en": {"language": "en", "content": "Please enter a valid email address"},
    "vi": {"language": "vi", "content": "Vui lòng nhập địa chỉ email hợp lệ"}
  }'),
  ('error.validation.phone', 'validation', 'Phone format validation error', '{
    "en": {"language": "en", "content": "Please enter a valid phone number"},
    "vi": {"language": "vi", "content": "Vui lòng nhập số điện thoại hợp lệ"}
  }'),
  ('error.validation.password_weak', 'validation', 'Weak password error', '{
    "en": {"language": "en", "content": "Password must be at least 8 characters with uppercase, lowercase, and numbers"},
    "vi": {"language": "vi", "content": "Mật khẩu phải có ít nhất 8 ký tự bao gồm chữ hoa, chữ thường và số"}
  }'),
  
  -- ================================
  -- AUTHENTICATION MESSAGES
  -- ================================
  ('error.auth.invalid_credentials', 'auth', 'Invalid login credentials', '{
    "en": {"language": "en", "content": "Invalid email or password"},
    "vi": {"language": "vi", "content": "Email hoặc mật khẩu không đúng"}
  }'),
  ('error.auth.unauthorized', 'auth', 'Unauthorized access', '{
    "en": {"language": "en", "content": "You are not authorized to perform this action"},
    "vi": {"language": "vi", "content": "Bạn không có quyền thực hiện hành động này"}
  }'),
  ('error.auth.account_locked', 'auth', 'Account locked error', '{
    "en": {"language": "en", "content": "Your account has been locked due to multiple failed login attempts"},
    "vi": {"language": "vi", "content": "Tài khoản của bạn đã bị khóa do nhiều lần đăng nhập thất bại"}
  }'),
  ('success.auth.login', 'auth', 'Successful login', '{
    "en": {"language": "en", "content": "Welcome back, {{name}}!"},
    "vi": {"language": "vi", "content": "Chào mừng trở lại, {{name}}!"}
  }'),
  ('success.auth.logout', 'auth', 'Successful logout', '{
    "en": {"language": "en", "content": "You have been logged out successfully"},
    "vi": {"language": "vi", "content": "Bạn đã đăng xuất thành công"}
  }'),
  
  -- ================================
  -- ORDER MESSAGES
  -- ================================
  ('success.order.created', 'order', 'Order creation success', '{
    "en": {"language": "en", "content": "Order {{order_number}} created successfully"},
    "vi": {"language": "vi", "content": "Đơn hàng {{order_number}} được tạo thành công"}
  }'),
  ('success.order.updated', 'order', 'Order update success', '{
    "en": {"language": "en", "content": "Order {{order_number}} updated successfully"},
    "vi": {"language": "vi", "content": "Đơn hàng {{order_number}} được cập nhật thành công"}
  }'),
  ('success.order.cancelled', 'order', 'Order cancellation success', '{
    "en": {"language": "en", "content": "Order {{order_number}} has been cancelled"},
    "vi": {"language": "vi", "content": "Đơn hàng {{order_number}} đã được hủy"}
  }'),
  ('error.order.not_found', 'order', 'Order not found error', '{
    "en": {"language": "en", "content": "Order {{order_number}} not found"},
    "vi": {"language": "vi", "content": "Không tìm thấy đơn hàng {{order_number}}"}
  }'),
  ('error.order.cannot_cancel', 'order', 'Cannot cancel order error', '{
    "en": {"language": "en", "content": "Order {{order_number}} cannot be cancelled as it is already {{status}}"},
    "vi": {"language": "vi", "content": "Không thể hủy đơn hàng {{order_number}} vì đã {{status}}"}
  }'),
  
  -- Order Status Messages
  ('order.status.pending', 'order', 'Order status: Pending', '{
    "en": {"language": "en", "content": "Pending"},
    "vi": {"language": "vi", "content": "Đang chờ"}
  }'),
  ('order.status.confirmed', 'order', 'Order status: Confirmed', '{
    "en": {"language": "en", "content": "Confirmed"},
    "vi": {"language": "vi", "content": "Đã xác nhận"}
  }'),
  ('order.status.processing', 'order', 'Order status: Processing', '{
    "en": {"language": "en", "content": "Processing"},
    "vi": {"language": "vi", "content": "Đang xử lý"}
  }'),
  ('order.status.shipped', 'order', 'Order status: Shipped', '{
    "en": {"language": "en", "content": "Shipped"},
    "vi": {"language": "vi", "content": "Đã gửi"}
  }'),
  ('order.status.delivered', 'order', 'Order status: Delivered', '{
    "en": {"language": "en", "content": "Delivered"},
    "vi": {"language": "vi", "content": "Đã giao"}
  }'),
  ('order.status.cancelled', 'order', 'Order status: Cancelled', '{
    "en": {"language": "en", "content": "Cancelled"},
    "vi": {"language": "vi", "content": "Đã hủy"}
  }'),
  
  -- ================================
  -- PAYMENT MESSAGES
  -- ================================
  ('success.payment.completed', 'payment', 'Payment completion success', '{
    "en": {"language": "en", "content": "Payment of {{amount}} completed successfully"},
    "vi": {"language": "vi", "content": "Thanh toán {{amount}} hoàn tất thành công"}
  }'),
  ('error.payment.failed', 'payment', 'Payment failure error', '{
    "en": {"language": "en", "content": "Payment failed: {{reason}}"},
    "vi": {"language": "vi", "content": "Thanh toán thất bại: {{reason}}"}
  }'),
  ('error.payment.insufficient_funds', 'payment', 'Insufficient funds error', '{
    "en": {"language": "en", "content": "Insufficient funds in your account"},
    "vi": {"language": "vi", "content": "Tài khoản của bạn không đủ số dư"}
  }'),
  ('error.payment.card_declined', 'payment', 'Card declined error', '{
    "en": {"language": "en", "content": "Your card was declined. Please try a different payment method"},
    "vi": {"language": "vi", "content": "Thẻ của bạn bị từ chối. Vui lòng thử phương thức thanh toán khác"}
  }'),
  ('payment.status.processing', 'payment', 'Payment processing status', '{
    "en": {"language": "en", "content": "Processing"},
    "vi": {"language": "vi", "content": "Đang xử lý"}
  }'),
  ('payment.status.completed', 'payment', 'Payment completed status', '{
    "en": {"language": "en", "content": "Completed"},
    "vi": {"language": "vi", "content": "Hoàn thành"}
  }'),
  ('payment.status.failed', 'payment', 'Payment failed status', '{
    "en": {"language": "en", "content": "Failed"},
    "vi": {"language": "vi", "content": "Thất bại"}
  }'),
  
  -- ================================
  -- CUSTOMER MESSAGES
  -- ================================
  ('success.customer.registered', 'customer', 'Customer registration success', '{
    "en": {"language": "en", "content": "Welcome {{name}}! Your account has been created successfully"},
    "vi": {"language": "vi", "content": "Chào mừng {{name}}! Tài khoản của bạn đã được tạo thành công"}
  }'),
  ('success.customer.profile_updated', 'customer', 'Profile update success', '{
    "en": {"language": "en", "content": "Your profile has been updated successfully"},
    "vi": {"language": "vi", "content": "Hồ sơ của bạn đã được cập nhật thành công"}
  }'),
  ('error.customer.email_exists', 'customer', 'Email already exists error', '{
    "en": {"language": "en", "content": "An account with this email already exists"},
    "vi": {"language": "vi", "content": "Đã tồn tại tài khoản với email này"}
  }'),
  
  -- ================================
  -- PRODUCT/CATALOG MESSAGES
  -- ================================
  ('success.product.created', 'catalog', 'Product creation success', '{
    "en": {"language": "en", "content": "Product {{product_name}} ({{sku}}) created successfully"},
    "vi": {"language": "vi", "content": "Sản phẩm {{product_name}} ({{sku}}) được tạo thành công"}
  }'),
  ('error.product.not_found', 'catalog', 'Product not found error', '{
    "en": {"language": "en", "content": "Product not found"},
    "vi": {"language": "vi", "content": "Không tìm thấy sản phẩm"}
  }'),
  ('error.product.out_of_stock', 'catalog', 'Product out of stock error', '{
    "en": {"language": "en", "content": "{{product_name}} is currently out of stock"},
    "vi": {"language": "vi", "content": "{{product_name}} hiện đang hết hàng"}
  }'),
  
  -- ================================
  -- SEARCH MESSAGES
  -- ================================
  ('search.no_results', 'search', 'No search results found', '{
    "en": {"language": "en", "content": "No results found for \"{{query}}\""},
    "vi": {"language": "vi", "content": "Không tìm thấy kết quả cho \"{{query}}\""}
  }'),
  ('search.results_found', 'search', 'Search results found', '{
    "en": {"language": "en", "content": "Found {{count}} results for \"{{query}}\""},
    "vi": {"language": "vi", "content": "Tìm thấy {{count}} kết quả cho \"{{query}}\""}
  }'),
  ('search.suggestions', 'search', 'Search suggestions', '{
    "en": {"language": "en", "content": "Did you mean: {{suggestions}}?"},
    "vi": {"language": "vi", "content": "Có phải bạn muốn tìm: {{suggestions}}?"}
  }'),
  
  -- ================================
  -- INVENTORY/WAREHOUSE MESSAGES
  -- ================================
  ('inventory.low_stock_alert', 'inventory', 'Low stock alert', '{
    "en": {"language": "en", "content": "Low stock alert: {{product_name}} has only {{current_stock}} units left (threshold: {{threshold}})"},
    "vi": {"language": "vi", "content": "Cảnh báo tồn kho thấp: {{product_name}} chỉ còn {{current_stock}} đơn vị (ngưỡng: {{threshold}})"}
  }'),
  ('inventory.stock_updated', 'inventory', 'Stock update success', '{
    "en": {"language": "en", "content": "Stock for {{product_name}} updated to {{new_stock}} units"},
    "vi": {"language": "vi", "content": "Tồn kho cho {{product_name}} đã cập nhật thành {{new_stock}} đơn vị"}
  }'),
  ('inventory.stock_reserved', 'inventory', 'Stock reservation success', '{
    "en": {"language": "en", "content": "Reserved {{quantity}} units of {{product_name}} for order {{order_number}}"},
    "vi": {"language": "vi", "content": "Đã dành {{quantity}} đơn vị {{product_name}} cho đơn hàng {{order_number}}"}
  }'),
  
  -- ================================
  -- SHIPPING MESSAGES
  -- ================================
  ('shipping.no_options_available', 'shipping', 'No shipping options available', '{
    "en": {"language": "en", "content": "No shipping options available for {{destination}}"},
    "vi": {"language": "vi", "content": "Không có tùy chọn vận chuyển cho {{destination}}"}
  }'),
  ('shipping.options_calculated', 'shipping', 'Shipping options calculated', '{
    "en": {"language": "en", "content": "{{options_count}} shipping options available"},
    "vi": {"language": "vi", "content": "Có {{options_count}} tùy chọn vận chuyển"}
  }'),
  ('shipping.package_picked_up', 'shipping', 'Package picked up', '{
    "en": {"language": "en", "content": "Your package {{tracking_number}} has been picked up from {{location}}"},
    "vi": {"language": "vi", "content": "Gói hàng {{tracking_number}} đã được lấy từ {{location}}"}
  }'),
  ('shipping.package_in_transit', 'shipping', 'Package in transit', '{
    "en": {"language": "en", "content": "Your package {{tracking_number}} is in transit. Current location: {{location}}"},
    "vi": {"language": "vi", "content": "Gói hàng {{tracking_number}} đang trên đường vận chuyển. Vị trí hiện tại: {{location}}"}
  }'),
  ('shipping.out_for_delivery', 'shipping', 'Package out for delivery', '{
    "en": {"language": "en", "content": "Your package {{tracking_number}} is out for delivery. Expected delivery: {{estimated_delivery}}"},
    "vi": {"language": "vi", "content": "Gói hàng {{tracking_number}} đang được giao. Dự kiến giao: {{estimated_delivery}}"}
  }'),
  ('shipping.package_delivered', 'shipping', 'Package delivered', '{
    "en": {"language": "en", "content": "Your package {{tracking_number}} has been delivered to {{location}}"},
    "vi": {"language": "vi", "content": "Gói hàng {{tracking_number}} đã được giao tại {{location}}"}
  }'),
  
  -- ================================
  -- FULFILLMENT MESSAGES
  -- ================================
  ('fulfillment.order_received', 'fulfillment', 'Order received for fulfillment', '{
    "en": {"language": "en", "content": "Order {{order_number}} received for fulfillment ({{items_count}} items)"},
    "vi": {"language": "vi", "content": "Đơn hàng {{order_number}} đã nhận để thực hiện ({{items_count}} sản phẩm)"}
  }'),
  ('fulfillment.order_picking', 'fulfillment', 'Order picking in progress', '{
    "en": {"language": "en", "content": "Order {{order_number}} is being picked"},
    "vi": {"language": "vi", "content": "Đơn hàng {{order_number}} đang được lấy hàng"}
  }'),
  ('fulfillment.order_packing', 'fulfillment', 'Order packing in progress', '{
    "en": {"language": "en", "content": "Order {{order_number}} is being packed"},
    "vi": {"language": "vi", "content": "Đơn hàng {{order_number}} đang được đóng gói"}
  }'),
  ('fulfillment.quality_check', 'fulfillment', 'Quality check in progress', '{
    "en": {"language": "en", "content": "Order {{order_number}} is undergoing quality check"},
    "vi": {"language": "vi", "content": "Đơn hàng {{order_number}} đang được kiểm tra chất lượng"}
  }'),
  ('fulfillment.ready_to_ship', 'fulfillment', 'Order ready to ship', '{
    "en": {"language": "en", "content": "Order {{order_number}} is ready to ship"},
    "vi": {"language": "vi", "content": "Đơn hàng {{order_number}} sẵn sàng để gửi"}
  }'),
  ('fulfillment.partial_pick', 'fulfillment', 'Partial pick notification', '{
    "en": {"language": "en", "content": "{{product_name}}: Ordered {{ordered}}, Picked {{picked}}. Reason: {{reason}}"},
    "vi": {"language": "vi", "content": "{{product_name}}: Đặt {{ordered}}, Lấy {{picked}}. Lý do: {{reason}}"}
  }'),
  
  -- ================================
  -- PRICING MESSAGES
  -- ================================
  ('pricing.discount_applied', 'pricing', 'Discount applied message', '{
    "en": {"language": "en", "content": "Discount applied! Original: {{original_price}}, Discount: {{discount_amount}}, Final: {{final_price}}. Reason: {{discount_reason}}"},
    "vi": {"language": "vi", "content": "Đã áp dụng giảm giá! Gốc: {{original_price}}, Giảm: {{discount_amount}}, Cuối: {{final_price}}. Lý do: {{discount_reason}}"}
  }'),
  ('pricing.price_calculated', 'pricing', 'Price calculated message', '{
    "en": {"language": "en", "content": "Price calculated: {{price}}"},
    "vi": {"language": "vi", "content": "Giá đã tính: {{price}}"}
  }'),
  
  -- ================================
  -- PROMOTION MESSAGES
  -- ================================
  ('promotion.coupon_applied', 'promotion', 'Coupon applied successfully', '{
    "en": {"language": "en", "content": "Coupon {{coupon_code}} applied! Discount: {{discount_amount}} ({{discount_type}})"},
    "vi": {"language": "vi", "content": "Mã giảm giá {{coupon_code}} đã áp dụng! Giảm: {{discount_amount}} ({{discount_type}})"}
  }'),
  ('promotion.coupon_expired', 'promotion', 'Coupon expired error', '{
    "en": {"language": "en", "content": "Coupon {{coupon_code}} has expired on {{expiry_date}}"},
    "vi": {"language": "vi", "content": "Mã giảm giá {{coupon_code}} đã hết hạn vào {{expiry_date}}"}
  }'),
  ('promotion.coupon_already_used', 'promotion', 'Coupon already used error', '{
    "en": {"language": "en", "content": "Coupon {{coupon_code}} has already been used"},
    "vi": {"language": "vi", "content": "Mã giảm giá {{coupon_code}} đã được sử dụng"}
  }'),
  ('promotion.coupon_not_found', 'promotion', 'Coupon not found error', '{
    "en": {"language": "en", "content": "Coupon {{coupon_code}} not found"},
    "vi": {"language": "vi", "content": "Không tìm thấy mã giảm giá {{coupon_code}}"}
  }'),
  ('promotion.minimum_amount_not_met', 'promotion', 'Minimum amount not met error', '{
    "en": {"language": "en", "content": "Minimum order amount {{minimum_amount}} required for coupon {{coupon_code}}"},
    "vi": {"language": "vi", "content": "Yêu cầu đơn hàng tối thiểu {{minimum_amount}} cho mã giảm giá {{coupon_code}}"}
  }'),
  
  -- ================================
  -- LOYALTY/REWARDS MESSAGES
  -- ================================
  ('loyalty.points_earned', 'loyalty', 'Points earned message', '{
    "en": {"language": "en", "content": "You earned {{points}} points for {{reason}}! Total points: {{total_points}}"},
    "vi": {"language": "vi", "content": "Bạn đã kiếm được {{points}} điểm cho {{reason}}! Tổng điểm: {{total_points}}"}
  }'),
  ('loyalty.tier_upgraded', 'loyalty', 'Tier upgrade message', '{
    "en": {"language": "en", "content": "Congratulations! You have been upgraded from {{old_tier}} to {{new_tier}}! New benefits: {{benefits}}"},
    "vi": {"language": "vi", "content": "Chúc mừng! Bạn đã được nâng cấp từ {{old_tier}} lên {{new_tier}}! Quyền lợi mới: {{benefits}}"}
  }'),
  ('loyalty.insufficient_points', 'loyalty', 'Insufficient points error', '{
    "en": {"language": "en", "content": "Insufficient points. Required: {{required_points}}, Available: {{available_points}}, Shortage: {{shortage}}"},
    "vi": {"language": "vi", "content": "Không đủ điểm. Cần: {{required_points}}, Có: {{available_points}}, Thiếu: {{shortage}}"}
  }'),
  ('loyalty.redemption_success', 'loyalty', 'Redemption success message', '{
    "en": {"language": "en", "content": "Successfully redeemed {{reward_name}} for {{points_used}} points! Remaining points: {{remaining_points}}"},
    "vi": {"language": "vi", "content": "Đã đổi thành công {{reward_name}} với {{points_used}} điểm! Điểm còn lại: {{remaining_points}}"}
  }'),
  
  -- ================================
  -- REVIEW MESSAGES
  -- ================================
  ('review.submission_success', 'review', 'Review submission success', '{
    "en": {"language": "en", "content": "Thank you for reviewing {{product_name}}! Your {{rating}}-star review has been submitted"},
    "vi": {"language": "vi", "content": "Cảm ơn bạn đã đánh giá {{product_name}}! Đánh giá {{rating}} sao của bạn đã được gửi"}
  }'),
  ('review.under_moderation', 'review', 'Review under moderation', '{
    "en": {"language": "en", "content": "Your review (ID: {{review_id}}) is under moderation and will be published within {{estimated_time}}"},
    "vi": {"language": "vi", "content": "Đánh giá của bạn (ID: {{review_id}}) đang được kiểm duyệt và sẽ được xuất bản trong {{estimated_time}}"}
  }'),
  ('review.moderation_approved', 'review', 'Review moderation approved', '{
    "en": {"language": "en", "content": "Your review for {{product_name}} (ID: {{review_id}}) has been approved and published"},
    "vi": {"language": "vi", "content": "Đánh giá của bạn cho {{product_name}} (ID: {{review_id}}) đã được duyệt và xuất bản"}
  }'),
  ('review.moderation_rejected', 'review', 'Review moderation rejected', '{
    "en": {"language": "en", "content": "Your review (ID: {{review_id}}) was rejected. Reason: {{reason}}"},
    "vi": {"language": "vi", "content": "Đánh giá của bạn (ID: {{review_id}}) đã bị từ chối. Lý do: {{reason}}"}
  }'),
  
  -- ================================
  -- USER MANAGEMENT MESSAGES
  -- ================================
  ('user.creation_success', 'user', 'User creation success', '{
    "en": {"language": "en", "content": "User {{username}} ({{email}}) created successfully with roles: {{roles}}"},
    "vi": {"language": "vi", "content": "Người dùng {{username}} ({{email}}) được tạo thành công với vai trò: {{roles}}"}
  }'),
  ('user.password_policy', 'user', 'Password policy message', '{
    "en": {"language": "en", "content": "Please ensure your password meets security requirements"},
    "vi": {"language": "vi", "content": "Vui lòng đảm bảo mật khẩu đáp ứng yêu cầu bảo mật"}
  }'),
  
  -- ================================
  -- GENERAL SUCCESS MESSAGES
  -- ================================
  ('success.created', 'general', 'Item created successfully', '{
    "en": {"language": "en", "content": "Item created successfully"},
    "vi": {"language": "vi", "content": "Tạo mục thành công"}
  }'),
  ('success.updated', 'general', 'Item updated successfully', '{
    "en": {"language": "en", "content": "Item updated successfully"},
    "vi": {"language": "vi", "content": "Cập nhật mục thành công"}
  }'),
  ('success.deleted', 'general', 'Item deleted successfully', '{
    "en": {"language": "en", "content": "Item deleted successfully"},
    "vi": {"language": "vi", "content": "Xóa mục thành công"}
  }'),
  ('success.saved', 'general', 'Changes saved successfully', '{
    "en": {"language": "en", "content": "Changes saved successfully"},
    "vi": {"language": "vi", "content": "Lưu thay đổi thành công"}
  }'),
  
  -- ================================
  -- GENERAL ERROR MESSAGES
  -- ================================
  ('error.not_found', 'general', 'Resource not found', '{
    "en": {"language": "en", "content": "The requested resource was not found"},
    "vi": {"language": "vi", "content": "Không tìm thấy tài nguyên được yêu cầu"}
  }'),
  ('error.internal_server', 'general', 'Internal server error', '{
    "en": {"language": "en", "content": "Internal server error. Please try again later"},
    "vi": {"language": "vi", "content": "Lỗi máy chủ nội bộ. Vui lòng thử lại sau"}
  }'),
  ('error.network', 'general', 'Network connection error', '{
    "en": {"language": "en", "content": "Network error. Please check your connection"},
    "vi": {"language": "vi", "content": "Lỗi mạng. Vui lòng kiểm tra kết nối"}
  }'),
  ('error.forbidden', 'general', 'Access forbidden', '{
    "en": {"language": "en", "content": "Access denied"},
    "vi": {"language": "vi", "content": "Truy cập bị từ chối"}
  }'),
  
  -- ================================
  -- NOTIFICATION TEMPLATES
  -- ================================
  ('notification.order.confirmed.subject', 'notification', 'Order confirmation email subject', '{
    "en": {"language": "en", "content": "Order Confirmed - #{{order_number}}", "variables": {"order_number": "Order number"}},
    "vi": {"language": "vi", "content": "Xác nhận đơn hàng - #{{order_number}}", "variables": {"order_number": "Số đơn hàng"}}
  }'),
  ('notification.order.confirmed.content', 'notification', 'Order confirmation email content', '{
    "en": {"language": "en", "content": "Dear {{customer_name}}, your order #{{order_number}} has been confirmed and is being processed. Total amount: {{total_amount}}. Expected delivery: {{delivery_date}}.", "variables": {"customer_name": "Customer name", "order_number": "Order number", "total_amount": "Total amount", "delivery_date": "Delivery date"}},
    "vi": {"language": "vi", "content": "Kính chào {{customer_name}}, đơn hàng #{{order_number}} của bạn đã được xác nhận và đang được xử lý. Tổng tiền: {{total_amount}}. Dự kiến giao hàng: {{delivery_date}}.", "variables": {"customer_name": "Tên khách hàng", "order_number": "Số đơn hàng", "total_amount": "Tổng tiền", "delivery_date": "Ngày giao hàng"}}
  }'),
  ('notification.order.shipped.subject', 'notification', 'Order shipped email subject', '{
    "en": {"language": "en", "content": "Order Shipped - #{{order_number}}", "variables": {"order_number": "Order number"}},
    "vi": {"language": "vi", "content": "Đơn hàng đã gửi - #{{order_number}}", "variables": {"order_number": "Số đơn hàng"}}
  }'),
  ('notification.order.shipped.content', 'notification', 'Order shipped email content', '{
    "en": {"language": "en", "content": "Dear {{customer_name}}, your order #{{order_number}} has been shipped via {{carrier}}. Tracking number: {{tracking_number}}. Expected delivery: {{delivery_date}}.", "variables": {"customer_name": "Customer name", "order_number": "Order number", "carrier": "Shipping carrier", "tracking_number": "Tracking number", "delivery_date": "Delivery date"}},
    "vi": {"language": "vi", "content": "Kính chào {{customer_name}}, đơn hàng #{{order_number}} của bạn đã được gửi qua {{carrier}}. Mã vận đơn: {{tracking_number}}. Dự kiến giao hàng: {{delivery_date}}.", "variables": {"customer_name": "Tên khách hàng", "order_number": "Số đơn hàng", "carrier": "Đơn vị vận chuyển", "tracking_number": "Mã vận đơn", "delivery_date": "Ngày giao hàng"}}
  }'),
  ('notification.payment.failed.subject', 'notification', 'Payment failed email subject', '{
    "en": {"language": "en", "content": "Payment Failed - Order #{{order_number}}", "variables": {"order_number": "Order number"}},
    "vi": {"language": "vi", "content": "Thanh toán thất bại - Đơn hàng #{{order_number}}", "variables": {"order_number": "Số đơn hàng"}}
  }'),
  ('notification.payment.failed.content', 'notification', 'Payment failed email content', '{
    "en": {"language": "en", "content": "Dear {{customer_name}}, the payment for your order #{{order_number}} has failed. Reason: {{failure_reason}}. Please update your payment method to complete the order.", "variables": {"customer_name": "Customer name", "order_number": "Order number", "failure_reason": "Failure reason"}},
    "vi": {"language": "vi", "content": "Kính chào {{customer_name}}, thanh toán cho đơn hàng #{{order_number}} của bạn đã thất bại. Lý do: {{failure_reason}}. Vui lòng cập nhật phương thức thanh toán để hoàn tất đơn hàng.", "variables": {"customer_name": "Tên khách hàng", "order_number": "Số đơn hàng", "failure_reason": "Lý do thất bại"}}
  }');
  ```

- [ ] **Run comprehensive seed script**
  ```bash
  psql $DATABASE_URL < notification/scripts/seed-comprehensive-i18n-messages.sql
  ```

- [ ] **Verify seeded data**
  ```sql
  -- Check message counts by category
  SELECT category, COUNT(*) as message_count 
  FROM messages 
  GROUP BY category 
  ORDER BY message_count DESC;
  
  -- Check language coverage
  SELECT 
    key,
    CASE WHEN translations ? 'en' THEN 'Y' ELSE 'N' END as has_english,
    CASE WHEN translations ? 'vi' THEN 'Y' ELSE 'N' END as has_vietnamese
  FROM messages
  WHERE translations ? 'en' = false OR translations ? 'vi' = false;
  ```

- [ ] **Test message retrieval**
  ```bash
  # Test API endpoints
  curl -X GET "http://localhost:8080/api/v1/messages/success.order.created?language=vi"
  curl -X GET "http://localhost:8080/api/v1/messages/error.payment.failed?language=en"
  ```

- [ ] **Create message management scripts**
  ```bash
  # notification/scripts/manage-messages.sh
  #!/bin/bash
  
  # Add new message
  add_message() {
    local key=$1
    local category=$2
    local description=$3
    local en_content=$4
    local vi_content=$5
    
    psql $DATABASE_URL -c "
    INSERT INTO messages (key, category, description, translations) VALUES 
    ('$key', '$category', '$description', '{
      \"en\": {\"language\": \"en\", \"content\": \"$en_content\"},
      \"vi\": {\"language\": \"vi\", \"content\": \"$vi_content\"}
    }');
    "
  }
  
  # Update message
  update_message() {
    local key=$1
    local language=$2
    local content=$3
    
    psql $DATABASE_URL -c "
    UPDATE messages 
    SET translations = jsonb_set(translations, '{$language,content}', '\"$content\"')
    WHERE key = '$key';
    "
  }
  
  # Export messages to JSON
  export_messages() {
    psql $DATABASE_URL -c "
    SELECT json_agg(
      json_build_object(
        'key', key,
        'category', category,
        'description', description,
        'translations', translations
      )
    ) FROM messages;
    " > messages_export.json
  }
  ```

---

## 📋 **PHASE 2: SERVICE INTEGRATION (Weeks 3-5)**

### Week 3: Core Services Integration

#### Day 11: API Gateway Language Middleware
- [ ] **Create language detection middleware**
  ```go
  // gateway/middleware/language.go
  func LanguageMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
      // 1. Check Accept-Language header
      // 2. Check customer preference (if authenticated)
      // 3. Set language in context
      // 4. Forward to downstream services
    }
  }
  ```
- [ ] **Add language header forwarding**
- [ ] **Test language detection logic**
- [ ] **Update gateway configuration**

#### Day 12: Customer Service Integration
- [ ] **Add notification client to customer service**
  ```go
  // customer/internal/client/notification_client.go
  type NotificationClient struct {
    client pb.NotificationServiceClient
  }
  
  func (c *NotificationClient) GetMessage(key, language string, variables map[string]string) (string, error)
  ```
- [ ] **Update customer registration messages**
- [ ] **Update profile update messages**
- [ ] **Update authentication error messages**
- [ ] **Test customer service with i18n**

#### Day 13: Order Service Integration
- [ ] **Add notification client to order service**
- [ ] **Update order creation messages**
  ```go
  // order/internal/biz/order/order.go
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, req *CreateOrderRequest) (*Order, error) {
    // ... order creation logic
    
    // Get localized success message
    language := getLanguageFromContext(ctx)
    message, _ := uc.notificationClient.GetMessage("success.order.created", language, map[string]string{
      "order_number": order.Number,
    })
    
    return &CreateOrderResponse{
      Success: true,
      Message: message,
      Order:   order,
    }, nil
  }
  ```
- [ ] **Update order status messages**
- [ ] **Update order cancellation messages**
- [ ] **Test order service with i18n**

#### Day 14: Payment Service Integration
- [ ] **Add notification client to payment service**
- [ ] **Update payment error messages**
- [ ] **Update payment success messages**
- [ ] **Update payment status messages**
- [ ] **Test payment service with i18n**

#### Day 15: Auth Service Integration
- [ ] **Add notification client to auth service**
- [ ] **Update login error messages**
- [ ] **Update registration messages**
- [ ] **Update password reset messages**
- [ ] **Test auth service with i18n**

### Week 4: Additional Services Integration

#### Day 16: Catalog Service Integration
- [ ] **Add notification client to catalog service**
  ```go
  // catalog/internal/client/notification_client.go
  type NotificationClient struct {
    client pb.NotificationServiceClient
  }
  ```
- [ ] **Update product creation messages**
  ```go
  // catalog/internal/biz/product/product.go
  func (uc *ProductUsecase) CreateProduct(ctx context.Context, req *CreateProductRequest) (*Product, error) {
    // ... product creation logic
    
    language := getLanguageFromContext(ctx)
    message, _ := uc.notificationClient.GetMessage("success.product.created", language, map[string]string{
      "product_name": product.Name,
      "sku": product.SKU,
    })
    
    return &CreateProductResponse{
      Success: true,
      Message: message,
      Product: product,
    }, nil
  }
  ```
- [ ] **Update search result messages**
  ```go
  // Search no results message
  noResultsMsg, _ := uc.notificationClient.GetMessage("search.no_results", language, map[string]string{
    "query": searchQuery,
  })
  
  // Search suggestions
  suggestionsMsg, _ := uc.notificationClient.GetMessage("search.suggestions", language, nil)
  ```
- [ ] **Update category messages**
- [ ] **Update product validation errors**
- [ ] **Test catalog service with Vietnamese**

#### Day 17: Warehouse Service Integration
- [ ] **Add notification client to warehouse service**
  ```go
  // warehouse/internal/client/notification_client.go
  ```
- [ ] **Update inventory messages**
  ```go
  // warehouse/internal/biz/inventory/inventory.go
  func (uc *InventoryUsecase) UpdateStock(ctx context.Context, req *UpdateStockRequest) (*UpdateStockResponse, error) {
    // ... stock update logic
    
    language := getLanguageFromContext(ctx)
    
    // Low stock alert
    if newStock < threshold {
      alertMsg, _ := uc.notificationClient.GetMessage("inventory.low_stock_alert", language, map[string]string{
        "product_name": product.Name,
        "current_stock": strconv.Itoa(newStock),
        "threshold": strconv.Itoa(threshold),
      })
      
      // Send alert to admin
      uc.sendAlert(alertMsg)
    }
    
    // Success message
    successMsg, _ := uc.notificationClient.GetMessage("inventory.stock_updated", language, map[string]string{
      "product_name": product.Name,
      "new_stock": strconv.Itoa(newStock),
    })
    
    return &UpdateStockResponse{
      Success: true,
      Message: successMsg,
    }, nil
  }
  ```
- [ ] **Update stock reservation messages**
  ```go
  // Stock reservation
  reservationMsg, _ := uc.notificationClient.GetMessage("inventory.stock_reserved", language, map[string]string{
    "quantity": strconv.Itoa(req.Quantity),
    "product_name": product.Name,
    "order_number": req.OrderNumber,
  })
  ```
- [ ] **Update warehouse transfer messages**
- [ ] **Update stock adjustment messages**
- [ ] **Test warehouse service with Vietnamese**

#### Day 18: Shipping Service Integration
- [ ] **Add notification client to shipping service**
  ```go
  // shipping/internal/client/notification_client.go
  ```
- [ ] **Update shipping calculation messages**
  ```go
  // shipping/internal/biz/shipping/shipping.go
  func (uc *ShippingUsecase) CalculateShippingCost(ctx context.Context, req *CalculateShippingRequest) (*CalculateShippingResponse, error) {
    // ... calculation logic
    
    language := getLanguageFromContext(ctx)
    
    // No shipping available message
    if len(options) == 0 {
      noShippingMsg, _ := uc.notificationClient.GetMessage("shipping.no_options_available", language, map[string]string{
        "destination": req.DestinationAddress,
      })
      
      return &CalculateShippingResponse{
        Success: false,
        Message: noShippingMsg,
      }, nil
    }
    
    // Success message with options
    successMsg, _ := uc.notificationClient.GetMessage("shipping.options_calculated", language, map[string]string{
      "options_count": strconv.Itoa(len(options)),
    })
    
    return &CalculateShippingResponse{
      Success: true,
      Message: successMsg,
      Options: options,
    }, nil
  }
  ```
- [ ] **Update tracking messages**
  ```go
  // Tracking updates
  func (uc *ShippingUsecase) UpdateTracking(ctx context.Context, req *UpdateTrackingRequest) error {
    language := getLanguageFromContext(ctx)
    
    var messageKey string
    switch req.Status {
    case "picked_up":
      messageKey = "shipping.package_picked_up"
    case "in_transit":
      messageKey = "shipping.package_in_transit"
    case "out_for_delivery":
      messageKey = "shipping.out_for_delivery"
    case "delivered":
      messageKey = "shipping.package_delivered"
    }
    
    trackingMsg, _ := uc.notificationClient.GetMessage(messageKey, language, map[string]string{
      "tracking_number": req.TrackingNumber,
      "location": req.CurrentLocation,
      "estimated_delivery": req.EstimatedDelivery.Format("02/01/2006"),
    })
    
    // Send notification to customer
    return uc.sendTrackingNotification(req.OrderID, trackingMsg)
  }
  ```
- [ ] **Update delivery attempt messages**
- [ ] **Update shipping label generation messages**
- [ ] **Test shipping service with Vietnamese**

#### Day 19: Fulfillment Service Integration
- [ ] **Add notification client to fulfillment service**
  ```go
  // fulfillment/internal/client/notification_client.go
  ```
- [ ] **Update order processing messages**
  ```go
  // fulfillment/internal/biz/fulfillment/fulfillment.go
  func (uc *FulfillmentUsecase) ProcessOrder(ctx context.Context, req *ProcessOrderRequest) (*ProcessOrderResponse, error) {
    language := getLanguageFromContext(ctx)
    
    // Order received message
    receivedMsg, _ := uc.notificationClient.GetMessage("fulfillment.order_received", language, map[string]string{
      "order_number": req.OrderNumber,
      "items_count": strconv.Itoa(len(req.Items)),
    })
    
    // Processing stages
    stages := []struct {
      status string
      messageKey string
    }{
      {"picking", "fulfillment.order_picking"},
      {"packing", "fulfillment.order_packing"},
      {"quality_check", "fulfillment.quality_check"},
      {"ready_to_ship", "fulfillment.ready_to_ship"},
    }
    
    for _, stage := range stages {
      stageMsg, _ := uc.notificationClient.GetMessage(stage.messageKey, language, map[string]string{
        "order_number": req.OrderNumber,
        "stage": stage.status,
      })
      
      // Update order status and notify
      uc.updateOrderStatus(req.OrderID, stage.status, stageMsg)
    }
    
    return &ProcessOrderResponse{
      Success: true,
      Message: receivedMsg,
    }, nil
  }
  ```
- [ ] **Update picking messages**
  ```go
  // Picking process
  func (uc *FulfillmentUsecase) PickItems(ctx context.Context, req *PickItemsRequest) error {
    language := getLanguageFromContext(ctx)
    
    for _, item := range req.Items {
      if item.QuantityPicked < item.QuantityOrdered {
        // Partial pick message
        partialMsg, _ := uc.notificationClient.GetMessage("fulfillment.partial_pick", language, map[string]string{
          "product_name": item.ProductName,
          "ordered": strconv.Itoa(item.QuantityOrdered),
          "picked": strconv.Itoa(item.QuantityPicked),
          "reason": item.PartialReason,
        })
        
        uc.logPartialPick(item.ProductID, partialMsg)
      }
    }
    
    return nil
  }
  ```
- [ ] **Update packing messages**
- [ ] **Update quality control messages**
- [ ] **Test fulfillment service with Vietnamese**

#### Day 20: Review Service Integration
- [ ] **Add notification client to review service**
  ```go
  // review/internal/client/notification_client.go
  ```
- [ ] **Update review submission messages**
  ```go
  // review/internal/biz/review/review.go
  func (uc *ReviewUsecase) CreateReview(ctx context.Context, req *CreateReviewRequest) (*CreateReviewResponse, error) {
    language := getLanguageFromContext(ctx)
    
    // Review submission success
    successMsg, _ := uc.notificationClient.GetMessage("review.submission_success", language, map[string]string{
      "product_name": product.Name,
      "rating": strconv.Itoa(req.Rating),
    })
    
    // Moderation message (if needed)
    if req.RequiresModeration {
      moderationMsg, _ := uc.notificationClient.GetMessage("review.under_moderation", language, map[string]string{
        "review_id": review.ID,
        "estimated_time": "24 giờ", // Could be localized
      })
      
      return &CreateReviewResponse{
        Success: true,
        Message: successMsg + " " + moderationMsg,
        Review: review,
      }, nil
    }
    
    return &CreateReviewResponse{
      Success: true,
      Message: successMsg,
      Review: review,
    }, nil
  }
  ```
- [ ] **Update moderation messages**
  ```go
  // Review moderation
  func (uc *ReviewUsecase) ModerateReview(ctx context.Context, req *ModerateReviewRequest) error {
    language := getLanguageFromContext(ctx)
    
    var messageKey string
    switch req.Action {
    case "approved":
      messageKey = "review.moderation_approved"
    case "rejected":
      messageKey = "review.moderation_rejected"
    case "requires_edit":
      messageKey = "review.moderation_requires_edit"
    }
    
    moderationMsg, _ := uc.notificationClient.GetMessage(messageKey, language, map[string]string{
      "review_id": req.ReviewID,
      "reason": req.Reason,
      "product_name": review.ProductName,
    })
    
    // Notify customer about moderation result
    return uc.notifyCustomer(review.CustomerID, moderationMsg)
  }
  ```
- [ ] **Update helpful vote messages**
- [ ] **Update review report messages**
- [ ] **Test review service with Vietnamese**

### Week 5: Advanced Services & Patterns

#### Day 21: Pricing Service Integration
- [ ] **Add notification client to pricing service**
  ```go
  // pricing/internal/client/notification_client.go
  ```
- [ ] **Update pricing calculation messages**
  ```go
  // pricing/internal/biz/pricing/pricing.go
  func (uc *PricingUsecase) CalculatePrice(ctx context.Context, req *CalculatePriceRequest) (*CalculatePriceResponse, error) {
    language := getLanguageFromContext(ctx)
    
    // Price calculation success
    if price.HasDiscount {
      discountMsg, _ := uc.notificationClient.GetMessage("pricing.discount_applied", language, map[string]string{
        "original_price": formatCurrency(price.OriginalPrice, language),
        "discount_amount": formatCurrency(price.DiscountAmount, language),
        "final_price": formatCurrency(price.FinalPrice, language),
        "discount_reason": price.DiscountReason,
      })
      
      return &CalculatePriceResponse{
        Success: true,
        Message: discountMsg,
        Price: price,
      }, nil
    }
    
    // Regular price message
    regularMsg, _ := uc.notificationClient.GetMessage("pricing.price_calculated", language, map[string]string{
      "price": formatCurrency(price.FinalPrice, language),
    })
    
    return &CalculatePriceResponse{
      Success: true,
      Message: regularMsg,
      Price: price,
    }, nil
  }
  ```
- [ ] **Update bulk pricing messages**
- [ ] **Update price change notifications**
- [ ] **Add currency formatting helpers**
- [ ] **Test pricing service with Vietnamese**

#### Day 22: Promotion Service Integration
- [ ] **Add notification client to promotion service**
  ```go
  // promotion/internal/client/notification_client.go
  ```
- [ ] **Update coupon application messages**
  ```go
  // promotion/internal/biz/promotion/promotion.go
  func (uc *PromotionUsecase) ApplyCoupon(ctx context.Context, req *ApplyCouponRequest) (*ApplyCouponResponse, error) {
    language := getLanguageFromContext(ctx)
    
    // Validate coupon
    if !coupon.IsValid {
      var messageKey string
      switch coupon.InvalidReason {
      case "expired":
        messageKey = "promotion.coupon_expired"
      case "used":
        messageKey = "promotion.coupon_already_used"
      case "not_found":
        messageKey = "promotion.coupon_not_found"
      case "minimum_not_met":
        messageKey = "promotion.minimum_amount_not_met"
      }
      
      errorMsg, _ := uc.notificationClient.GetMessage(messageKey, language, map[string]string{
        "coupon_code": req.CouponCode,
        "minimum_amount": formatCurrency(coupon.MinimumAmount, language),
        "expiry_date": coupon.ExpiryDate.Format("02/01/2006"),
      })
      
      return &ApplyCouponResponse{
        Success: false,
        Message: errorMsg,
      }, nil
    }
    
    // Coupon applied successfully
    successMsg, _ := uc.notificationClient.GetMessage("promotion.coupon_applied", language, map[string]string{
      "coupon_code": req.CouponCode,
      "discount_amount": formatCurrency(coupon.DiscountAmount, language),
      "discount_type": coupon.DiscountType, // "percentage" or "fixed"
    })
    
    return &ApplyCouponResponse{
      Success: true,
      Message: successMsg,
      Discount: coupon.DiscountAmount,
    }, nil
  }
  ```
- [ ] **Update promotion eligibility messages**
- [ ] **Update campaign messages**
- [ ] **Test promotion service with Vietnamese**

#### Day 23: Loyalty-Rewards Service Integration
- [ ] **Add notification client to loyalty-rewards service**
  ```go
  // loyalty-rewards/internal/client/notification_client.go
  ```
- [ ] **Update points earning messages**
  ```go
  // loyalty-rewards/internal/biz/account/account.go
  func (uc *AccountUsecase) EarnPoints(ctx context.Context, req *EarnPointsRequest) (*EarnPointsResponse, error) {
    language := getLanguageFromContext(ctx)
    
    // Points earned message
    earnedMsg, _ := uc.notificationClient.GetMessage("loyalty.points_earned", language, map[string]string{
      "points": strconv.Itoa(req.Points),
      "reason": req.Reason,
      "total_points": strconv.Itoa(account.TotalPoints),
    })
    
    // Tier upgrade check
    if account.TierUpgraded {
      tierMsg, _ := uc.notificationClient.GetMessage("loyalty.tier_upgraded", language, map[string]string{
        "old_tier": account.PreviousTier,
        "new_tier": account.CurrentTier,
        "benefits": account.NewTierBenefits,
      })
      
      return &EarnPointsResponse{
        Success: true,
        Message: earnedMsg + " " + tierMsg,
        Account: account,
      }, nil
    }
    
    return &EarnPointsResponse{
      Success: true,
      Message: earnedMsg,
      Account: account,
    }, nil
  }
  ```
- [ ] **Update redemption messages**
  ```go
  // Points redemption
  func (uc *RedemptionUsecase) RedeemPoints(ctx context.Context, req *RedeemPointsRequest) (*RedeemPointsResponse, error) {
    language := getLanguageFromContext(ctx)
    
    // Insufficient points
    if account.Points < req.PointsRequired {
      insufficientMsg, _ := uc.notificationClient.GetMessage("loyalty.insufficient_points", language, map[string]string{
        "required_points": strconv.Itoa(req.PointsRequired),
        "available_points": strconv.Itoa(account.Points),
        "shortage": strconv.Itoa(req.PointsRequired - account.Points),
      })
      
      return &RedeemPointsResponse{
        Success: false,
        Message: insufficientMsg,
      }, nil
    }
    
    // Redemption success
    successMsg, _ := uc.notificationClient.GetMessage("loyalty.redemption_success", language, map[string]string{
      "reward_name": reward.Name,
      "points_used": strconv.Itoa(req.PointsRequired),
      "remaining_points": strconv.Itoa(account.Points - req.PointsRequired),
    })
    
    return &RedeemPointsResponse{
      Success: true,
      Message: successMsg,
      Redemption: redemption,
    }, nil
  }
  ```
- [ ] **Update referral messages**
- [ ] **Update campaign participation messages**
- [ ] **Test loyalty-rewards service with Vietnamese**

#### Day 24: Search Service Integration
- [ ] **Add notification client to search service**
  ```go
  // search/internal/client/notification_client.go
  ```
- [ ] **Update search result messages**
  ```go
  // search/internal/biz/search/search.go
  func (uc *SearchUsecase) SearchProducts(ctx context.Context, req *SearchProductsRequest) (*SearchProductsResponse, error) {
    language := getLanguageFromContext(ctx)
    
    // No results found
    if len(results) == 0 {
      noResultsMsg, _ := uc.notificationClient.GetMessage("search.no_results", language, map[string]string{
        "query": req.Query,
      })
      
      // Get search suggestions
      suggestions := uc.getSuggestions(req.Query, language)
      if len(suggestions) > 0 {
        suggestionsMsg, _ := uc.notificationClient.GetMessage("search.suggestions", language, map[string]string{
          "suggestions": strings.Join(suggestions, ", "),
        })
        
        return &SearchProductsResponse{
          Success: false,
          Message: noResultsMsg + " " + suggestionsMsg,
          Results: []Product{},
          Suggestions: suggestions,
        }, nil
      }
      
      return &SearchProductsResponse{
        Success: false,
        Message: noResultsMsg,
        Results: []Product{},
      }, nil
    }
    
    // Results found
    resultsMsg, _ := uc.notificationClient.GetMessage("search.results_found", language, map[string]string{
      "count": strconv.Itoa(len(results)),
      "query": req.Query,
      "total": strconv.Itoa(totalResults),
    })
    
    return &SearchProductsResponse{
      Success: true,
      Message: resultsMsg,
      Results: results,
      Total: totalResults,
    }, nil
  }
  ```
- [ ] **Update filter messages**
- [ ] **Update autocomplete messages**
- [ ] **Test search service with Vietnamese**

#### Day 25: User Service Integration
- [ ] **Add notification client to user service**
  ```go
  // user/internal/client/notification_client.go
  ```
- [ ] **Update user management messages**
  ```go
  // user/internal/biz/user/user.go
  func (uc *UserUsecase) CreateUser(ctx context.Context, req *CreateUserRequest) (*CreateUserResponse, error) {
    language := getLanguageFromContext(ctx)
    
    // User creation success
    successMsg, _ := uc.notificationClient.GetMessage("user.creation_success", language, map[string]string{
      "username": req.Username,
      "email": req.Email,
      "roles": strings.Join(req.Roles, ", "),
    })
    
    // Password policy message
    policyMsg, _ := uc.notificationClient.GetMessage("user.password_policy", language, nil)
    
    return &CreateUserResponse{
      Success: true,
      Message: successMsg + " " + policyMsg,
      User: user,
    }, nil
  }
  ```
- [ ] **Update role assignment messages**
- [ ] **Update permission messages**
- [ ] **Test user service with Vietnamese**
- [ ] **Define message categories**
  ```
  - validation: Form validation errors
  - auth: Authentication messages
  - order: Order-related messages
  - payment: Payment messages
  - notification: Email/SMS templates
  - success: Success confirmations
  - error: General error messages
  ```
- [ ] **Organize existing messages by category**
- [ ] **Add category-based caching**
- [ ] **Create category management API**

#### Day 22: Variable Handling & Templates
- [ ] **Enhance variable replacement**
  ```go
  // Support complex variables
  variables := map[string]string{
    "customer_name": "Nguyễn Văn A",
    "order_number": "ORD-12345",
    "amount": "1,500,000 VND",
    "date": "27/12/2025",
  }
  ```
- [ ] **Add variable validation**
- [ ] **Add template syntax support**
- [ ] **Test complex message rendering**

#### Day 23: Fallback & Error Handling
- [ ] **Implement robust fallback chain**
  ```
  1. Requested language (vi)
  2. Default language (en)
  3. Message key as fallback
  4. Generic error message
  ```
- [ ] **Add error tracking**
- [ ] **Add missing message alerts**
- [ ] **Test fallback scenarios**

#### Day 24: Performance Optimization
- [ ] **Implement message preloading**
- [ ] **Add bulk message retrieval**
- [ ] **Optimize database queries**
- [ ] **Add connection pooling**
- [ ] **Performance testing**

#### Day 25: Monitoring & Observability
- [ ] **Add i18n metrics**
  ```go
  // Prometheus metrics
  - message_lookup_duration_seconds
  - message_cache_hit_ratio
  - message_fallback_total
  - missing_message_total
  ```
- [ ] **Add distributed tracing**
- [ ] **Add health checks**
- [ ] **Create monitoring dashboard**

---

## 📋 **PHASE 3: FRONTEND INTEGRATION (Weeks 6-7)**

### Week 6: Common Integration Patterns & Helpers

#### Day 26: Common Integration Patterns
- [ ] **Create shared i18n client package**
  ```go
  // common/client/i18n/client.go
  package i18n
  
  type Client struct {
    notificationClient pb.NotificationServiceClient
    defaultLanguage    string
    cache             *sync.Map // Local cache for frequently used messages
  }
  
  func NewClient(notificationClient pb.NotificationServiceClient) *Client {
    return &Client{
      notificationClient: notificationClient,
      defaultLanguage:    "en",
      cache:             &sync.Map{},
    }
  }
  
  func (c *Client) GetMessage(ctx context.Context, key, language string, variables map[string]string) (string, error) {
    // Check local cache first
    cacheKey := fmt.Sprintf("%s:%s", key, language)
    if cached, ok := c.cache.Load(cacheKey); ok && len(variables) == 0 {
      return cached.(string), nil
    }
    
    // Call notification service
    resp, err := c.notificationClient.GetMessage(ctx, &pb.GetMessageRequest{
      Key:       key,
      Language:  language,
      Variables: variables,
    })
    
    if err != nil {
      // Fallback to key
      return key, err
    }
    
    // Cache simple messages (no variables)
    if len(variables) == 0 {
      c.cache.Store(cacheKey, resp.Content)
    }
    
    return resp.Content, nil
  }
  
  func (c *Client) GetMessages(ctx context.Context, keys []string, language string, variables map[string]map[string]string) (map[string]string, error) {
    resp, err := c.notificationClient.GetMessages(ctx, &pb.GetMessagesRequest{
      Keys:      keys,
      Language:  language,
      Variables: variables,
    })
    
    if err != nil {
      // Return keys as fallback
      result := make(map[string]string)
      for _, key := range keys {
        result[key] = key
      }
      return result, err
    }
    
    return resp.Messages, nil
  }
  ```

- [ ] **Create language context helpers**
  ```go
  // common/context/language.go
  package context
  
  type LanguageContext struct {
    Language string
    Country  string
    Region   string
  }
  
  const LanguageContextKey = "language_context"
  
  func WithLanguage(ctx context.Context, language string) context.Context {
    langCtx := &LanguageContext{
      Language: language,
      Country:  getCountryFromLanguage(language),
      Region:   getRegionFromLanguage(language),
    }
    return context.WithValue(ctx, LanguageContextKey, langCtx)
  }
  
  func GetLanguage(ctx context.Context) string {
    if langCtx, ok := ctx.Value(LanguageContextKey).(*LanguageContext); ok {
      return langCtx.Language
    }
    return "en" // Default fallback
  }
  
  func GetLanguageContext(ctx context.Context) *LanguageContext {
    if langCtx, ok := ctx.Value(LanguageContextKey).(*LanguageContext); ok {
      return langCtx
    }
    return &LanguageContext{Language: "en", Country: "US", Region: "Americas"}
  }
  
  func getCountryFromLanguage(language string) string {
    switch language {
    case "vi":
      return "VN"
    case "en":
      return "US"
    default:
      return "US"
    }
  }
  ```

- [ ] **Create formatting helpers**
  ```go
  // common/format/currency.go
  package format
  
  import (
    "golang.org/x/text/currency"
    "golang.org/x/text/language"
    "golang.org/x/text/message"
  )
  
  func FormatCurrency(amount float64, lang string) string {
    var tag language.Tag
    var curr currency.Unit
    
    switch lang {
    case "vi":
      tag = language.Vietnamese
      curr = currency.VND
    case "en":
      tag = language.English
      curr = currency.USD
    default:
      tag = language.English
      curr = currency.USD
    }
    
    p := message.NewPrinter(tag)
    return p.Sprintf("%.0f %s", amount, curr.String())
  }
  
  func FormatDate(date time.Time, lang string) string {
    switch lang {
    case "vi":
      return date.Format("02/01/2006") // DD/MM/YYYY
    case "en":
      return date.Format("01/02/2006") // MM/DD/YYYY
    default:
      return date.Format("2006-01-02") // ISO format
    }
  }
  
  func FormatNumber(number int, lang string) string {
    var tag language.Tag
    
    switch lang {
    case "vi":
      tag = language.Vietnamese
    case "en":
      tag = language.English
    default:
      tag = language.English
    }
    
    p := message.NewPrinter(tag)
    return p.Sprintf("%d", number)
  }
  ```

#### Day 27: Error Handling Patterns
- [ ] **Create i18n error wrapper**
  ```go
  // common/errors/i18n_error.go
  package errors
  
  type I18nError struct {
    Code       ErrorCode
    MessageKey string
    Variables  map[string]string
    Language   string
    StatusCode int
    Cause      error
  }
  
  func NewI18n(code ErrorCode, messageKey string, language string) *I18nError {
    return &I18nError{
      Code:       code,
      MessageKey: messageKey,
      Language:   language,
      StatusCode: getDefaultStatusCode(code),
      Variables:  make(map[string]string),
    }
  }
  
  func (e *I18nError) WithVariable(key, value string) *I18nError {
    e.Variables[key] = value
    return e
  }
  
  func (e *I18nError) WithCause(cause error) *I18nError {
    e.Cause = cause
    return e
  }
  
  func (e *I18nError) Error() string {
    if e.Cause != nil {
      return fmt.Sprintf("%s: %v", e.MessageKey, e.Cause)
    }
    return e.MessageKey
  }
  
  // Usage example:
  // return errors.NewI18n(errors.ValidationError, "error.validation.required", language).
  //   WithVariable("field", "email").
  //   WithCause(originalError)
  ```

- [ ] **Create error response helpers**
  ```go
  // common/response/i18n_response.go
  package response
  
  func ErrorResponse(i18nClient *i18n.Client, ctx context.Context, err error) *pb.ErrorResponse {
    language := context.GetLanguage(ctx)
    
    if i18nErr, ok := err.(*errors.I18nError); ok {
      message, _ := i18nClient.GetMessage(ctx, i18nErr.MessageKey, language, i18nErr.Variables)
      
      return &pb.ErrorResponse{
        Code:    int32(i18nErr.Code),
        Message: message,
        Details: getErrorDetails(i18nErr),
      }
    }
    
    // Fallback for non-i18n errors
    fallbackMsg, _ := i18nClient.GetMessage(ctx, "error.internal_server", language, nil)
    return &pb.ErrorResponse{
      Code:    500,
      Message: fallbackMsg,
    }
  }
  
  func SuccessResponse(i18nClient *i18n.Client, ctx context.Context, messageKey string, variables map[string]string, data interface{}) *pb.SuccessResponse {
    language := context.GetLanguage(ctx)
    message, _ := i18nClient.GetMessage(ctx, messageKey, language, variables)
    
    return &pb.SuccessResponse{
      Success: true,
      Message: message,
      Data:    data,
    }
  }
  ```

#### Day 28: Middleware Integration
- [ ] **Update API Gateway middleware**
  ```go
  // gateway/middleware/language.go
  func LanguageMiddleware(customerClient pb.CustomerServiceClient) gin.HandlerFunc {
    return func(c *gin.Context) {
      var language string
      
      // 1. Check explicit language parameter
      if lang := c.Query("lang"); lang != "" {
        language = lang
      } else if lang := c.GetHeader("Accept-Language"); lang != "" {
        // 2. Parse Accept-Language header
        language = parseAcceptLanguage(lang)
      } else {
        // 3. Check customer preference (if authenticated)
        if customerID := c.GetString("customer_id"); customerID != "" {
          if custLang := getCustomerLanguage(customerClient, customerID); custLang != "" {
            language = custLang
          }
        }
      }
      
      // Default to English if nothing found
      if language == "" {
        language = "en"
      }
      
      // Validate language (only support en, vi for now)
      if language != "en" && language != "vi" {
        language = "en"
      }
      
      // Set in context and forward to services
      c.Set("language", language)
      c.Header("X-Language", language)
      
      c.Next()
    }
  }
  
  func getCustomerLanguage(client pb.CustomerServiceClient, customerID string) string {
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    
    resp, err := client.GetCustomer(ctx, &pb.GetCustomerRequest{Id: customerID})
    if err != nil {
      return ""
    }
    
    if prefs := resp.Customer.Preferences; prefs != nil {
      if lang, ok := prefs.Fields["language"]; ok {
        return lang.GetStringValue()
      }
    }
    
    return ""
  }
  
  func parseAcceptLanguage(acceptLang string) string {
    // Parse Accept-Language header (e.g., "vi-VN,vi;q=0.9,en;q=0.8")
    languages := strings.Split(acceptLang, ",")
    for _, lang := range languages {
      lang = strings.TrimSpace(lang)
      if strings.HasPrefix(lang, "vi") {
        return "vi"
      }
      if strings.HasPrefix(lang, "en") {
        return "en"
      }
    }
    return "en"
  }
  ```

- [ ] **Create service middleware for language propagation**
  ```go
  // common/middleware/language.go
  package middleware
  
  func LanguagePropagation() grpc.UnaryServerInterceptor {
    return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
      // Extract language from metadata
      if md, ok := metadata.FromIncomingContext(ctx); ok {
        if langs := md.Get("x-language"); len(langs) > 0 {
          ctx = context.WithLanguage(ctx, langs[0])
        }
      }
      
      return handler(ctx, req)
    }
  }
  
  func LanguageForwarding() grpc.UnaryClientInterceptor {
    return func(ctx context.Context, method string, req, reply interface{}, cc *grpc.ClientConn, invoker grpc.UnaryInvoker, opts ...grpc.CallOption) error {
      // Forward language to downstream services
      if language := context.GetLanguage(ctx); language != "" {
        ctx = metadata.AppendToOutgoingContext(ctx, "x-language", language)
      }
      
      return invoker(ctx, method, req, reply, cc, opts...)
    }
  }
  ```

#### Day 29: Testing Patterns
- [ ] **Create i18n testing helpers**
  ```go
  // common/testing/i18n_test_helper.go
  package testing
  
  type MockI18nClient struct {
    messages map[string]map[string]string // key -> language -> message
  }
  
  func NewMockI18nClient() *MockI18nClient {
    return &MockI18nClient{
      messages: make(map[string]map[string]string),
    }
  }
  
  func (m *MockI18nClient) AddMessage(key, language, message string) {
    if m.messages[key] == nil {
      m.messages[key] = make(map[string]string)
    }
    m.messages[key][language] = message
  }
  
  func (m *MockI18nClient) GetMessage(ctx context.Context, key, language string, variables map[string]string) (string, error) {
    if langMap, ok := m.messages[key]; ok {
      if message, ok := langMap[language]; ok {
        // Simple variable replacement for testing
        result := message
        for k, v := range variables {
          result = strings.ReplaceAll(result, "{{"+k+"}}", v)
        }
        return result, nil
      }
    }
    return key, nil // Fallback to key
  }
  
  // Test helper functions
  func SetupI18nTest() *MockI18nClient {
    client := NewMockI18nClient()
    
    // Add common test messages
    client.AddMessage("success.created", "en", "Item created successfully")
    client.AddMessage("success.created", "vi", "Tạo mục thành công")
    client.AddMessage("error.not_found", "en", "Item not found")
    client.AddMessage("error.not_found", "vi", "Không tìm thấy mục")
    
    return client
  }
  ```

- [ ] **Create integration test patterns**
  ```go
  // Example integration test
  func TestOrderCreationWithI18n(t *testing.T) {
    // Setup
    mockI18n := testing.SetupI18nTest()
    orderService := setupOrderService(mockI18n)
    
    tests := []struct {
      name     string
      language string
      expected string
    }{
      {
        name:     "English order creation",
        language: "en",
        expected: "Order ORD-123 created successfully",
      },
      {
        name:     "Vietnamese order creation", 
        language: "vi",
        expected: "Đơn hàng ORD-123 được tạo thành công",
      },
    }
    
    for _, tt := range tests {
      t.Run(tt.name, func(t *testing.T) {
        ctx := context.WithLanguage(context.Background(), tt.language)
        
        resp, err := orderService.CreateOrder(ctx, &pb.CreateOrderRequest{
          // ... order data
        })
        
        assert.NoError(t, err)
        assert.Contains(t, resp.Message, tt.expected)
      })
    }
  }
  ```

#### Day 30: Performance Optimization
- [ ] **Implement message preloading**
  ```go
  // common/cache/message_preloader.go
  package cache
  
  type MessagePreloader struct {
    i18nClient *i18n.Client
    cache      *sync.Map
    preloadKeys []string
  }
  
  func NewMessagePreloader(i18nClient *i18n.Client) *MessagePreloader {
    return &MessagePreloader{
      i18nClient: i18nClient,
      cache:      &sync.Map{},
      preloadKeys: []string{
        // Common messages to preload
        "error.validation.required",
        "error.validation.email", 
        "error.not_found",
        "success.created",
        "success.updated",
        "success.deleted",
      },
    }
  }
  
  func (p *MessagePreloader) Preload(ctx context.Context, languages []string) error {
    for _, lang := range languages {
      messages, err := p.i18nClient.GetMessages(ctx, p.preloadKeys, lang, nil)
      if err != nil {
        return err
      }
      
      for key, message := range messages {
        cacheKey := fmt.Sprintf("%s:%s", key, lang)
        p.cache.Store(cacheKey, message)
      }
    }
    
    return nil
  }
  
  func (p *MessagePreloader) GetCachedMessage(key, language string) (string, bool) {
    cacheKey := fmt.Sprintf("%s:%s", key, language)
    if message, ok := p.cache.Load(cacheKey); ok {
      return message.(string), true
    }
    return "", false
  }
  ```

- [ ] **Add connection pooling for notification service**
- [ ] **Implement circuit breaker pattern**
- [ ] **Add request batching for multiple message lookups**
- [ ] **Install i18next in admin**
  ```bash
  cd admin
  npm install i18next react-i18next i18next-browser-languagedetector
  ```
- [ ] **Configure i18next**
  ```typescript
  // admin/src/i18n/index.ts
  import i18n from 'i18next';
  import { initReactI18next } from 'react-i18next';
  ```
- [ ] **Create translation files structure**
  ```
  admin/src/i18n/locales/
  ├── en/
  │   ├── common.json
  │   ├── orders.json
  │   ├── customers.json
  │   └── errors.json
  └── vi/
      ├── common.json
      ├── orders.json
      ├── customers.json
      └── errors.json
  ```

#### Day 27: Admin API Integration
- [ ] **Create i18n API client**
  ```typescript
  // admin/src/services/i18nService.ts
  class I18nService {
    async getMessage(key: string, language: string, variables?: Record<string, string>): Promise<string>
    async getMessages(keys: string[], language: string): Promise<Record<string, string>>
  }
  ```
- [ ] **Integrate with notification service API**
- [ ] **Add error handling**
- [ ] **Test API integration**

#### Day 28: Admin Components Update
- [ ] **Update error handling components**
- [ ] **Update success message components**
- [ ] **Update order status displays**
- [ ] **Update form validation messages**
- [ ] **Add language switcher component**

#### Day 29: Admin Message Management
- [ ] **Create message management page**
  ```typescript
  // admin/src/pages/MessageManagement.tsx
  - List all messages by category
  - Edit message translations
  - Add new messages
  - Preview message rendering
  ```
- [ ] **Add message editor component**
- [ ] **Add translation management**
- [ ] **Test message management workflow**

#### Day 30: Admin Testing
- [ ] **Test admin panel in Vietnamese**
- [ ] **Test language switching**
- [ ] **Test message management**
- [ ] **Fix UI/UX issues**

### Week 7: Customer Frontend Integration

#### Day 31-35: Customer Website
- [ ] **Setup i18next in customer frontend**
- [ ] **Create customer translation files**
- [ ] **Update customer-facing components**
- [ ] **Add language switcher**
- [ ] **Test customer experience in Vietnamese**

---

## 📋 **PHASE 4: TESTING & DEPLOYMENT (Weeks 8-10)**

### Week 8: Comprehensive Testing

#### Day 36: Unit Testing
- [ ] **Message repository tests**
- [ ] **Message usecase tests**
- [ ] **Cache layer tests**
- [ ] **Service layer tests**
- [ ] **Achieve >90% test coverage**

#### Day 37: Integration Testing
- [ ] **Service-to-service i18n tests**
- [ ] **End-to-end message flow tests**
- [ ] **Cache integration tests**
- [ ] **Database integration tests**

#### Day 38: Performance Testing
- [ ] **Load test message lookup API**
  ```
  Target: 1000 req/sec, <50ms response time
  ```
- [ ] **Stress test cache layer**
- [ ] **Test fallback performance**
- [ ] **Memory usage testing**

#### Day 39: User Acceptance Testing
- [ ] **Vietnamese customer journey testing**
- [ ] **Admin panel Vietnamese testing**
- [ ] **Cross-browser testing**
- [ ] **Mobile responsiveness testing**

#### Day 40: Security Testing
- [ ] **Input validation testing**
- [ ] **SQL injection testing**
- [ ] **XSS prevention testing**
- [ ] **Access control testing**

### Week 9: Production Preparation

#### Day 41: Database Migration
- [ ] **Prepare production migration scripts**
- [ ] **Test migration on staging**
- [ ] **Create rollback procedures**
- [ ] **Schedule maintenance window**

#### Day 42: Deployment Scripts
- [ ] **Update Docker configurations**
- [ ] **Update Kubernetes manifests**
- [ ] **Update ArgoCD configurations**
- [ ] **Test deployment pipeline**

#### Day 43: Monitoring Setup
- [ ] **Deploy monitoring dashboard**
- [ ] **Configure alerts**
- [ ] **Set up log aggregation**
- [ ] **Test monitoring system**

#### Day 44: Documentation
- [ ] **API documentation**
- [ ] **Integration guide for other services**
- [ ] **Admin user guide**
- [ ] **Troubleshooting guide**

#### Day 45: Team Training
- [ ] **Train development teams**
- [ ] **Train support teams**
- [ ] **Train admin users**
- [ ] **Create training materials**

### Week 10: Production Deployment

#### Day 46: Staging Deployment
- [ ] **Deploy to staging environment**
- [ ] **Run full test suite**
- [ ] **Performance validation**
- [ ] **User acceptance testing**

#### Day 47: Production Deployment
- [ ] **Deploy notification service updates**
- [ ] **Run database migrations**
- [ ] **Deploy other service updates**
- [ ] **Deploy frontend updates**

#### Day 48: Post-Deployment Validation
- [ ] **Verify all services are working**
- [ ] **Check Vietnamese message display**
- [ ] **Monitor performance metrics**
- [ ] **Check error rates**

#### Day 49: Rollout Monitoring
- [ ] **Monitor user adoption**
- [ ] **Track performance metrics**
- [ ] **Monitor error logs**
- [ ] **Collect user feedback**

#### Day 50: Project Completion
- [ ] **Final performance review**
- [ ] **Document lessons learned**
- [ ] **Plan future enhancements**
- [ ] **Project retrospective**

---

## 🎯 **SUCCESS CRITERIA**

### **Technical Metrics**
- [ ] **Message lookup time**: <50ms (95th percentile)
- [ ] **Cache hit rate**: >95%
- [ ] **Service availability**: 99.9%
- [ ] **Error rate**: <0.1%

### **Business Metrics**
- [ ] **Vietnamese customer engagement**: +30%
- [ ] **Support tickets**: -50% language-related
- [ ] **User experience score**: >4.5/5 for Vietnamese users
- [ ] **Time to add new language**: <2 weeks

### **Quality Metrics**
- [ ] **Test coverage**: >90%
- [ ] **Code review**: 100% reviewed
- [ ] **Documentation**: Complete
- [ ] **Security scan**: No critical issues

---

## 🚨 **RISK MITIGATION**

### **Performance Risks**
- [ ] **Implement circuit breakers**
- [ ] **Add request rate limiting**
- [ ] **Monitor memory usage**
- [ ] **Plan capacity scaling**

### **Data Risks**
- [ ] **Database backup strategy**
- [ ] **Migration rollback plan**
- [ ] **Data validation checks**
- [ ] **Corruption detection**

### **Integration Risks**
- [ ] **Backward compatibility testing**
- [ ] **Gradual rollout plan**
- [ ] **Feature flags for rollback**
- [ ] **Service dependency mapping**

---

## 📞 **SUPPORT & ESCALATION**

### **Team Contacts**
- **Notification Service Team**: Primary implementation
- **Platform Team**: Infrastructure support
- **Frontend Team**: UI/UX integration
- **QA Team**: Testing and validation

### **Escalation Path**
1. **Technical Issues**: Notification Service Team Lead
2. **Performance Issues**: Platform Team Lead
3. **Business Issues**: Product Manager
4. **Critical Issues**: Engineering Manager

---

**Checklist Created**: December 27, 2025  
**Estimated Completion**: March 7, 2026 (10 weeks)  
**Next Review**: Weekly progress reviews every Friday