# Location & Address/Zone Flow - Issues Checklist

## ✅ Reviewed Areas
- Service layer filtering + validation
- Usecase cache + tree logic
- Search and children filters

## 🔎 Re-review (2026-01-19)

### Fixed
- [x] **IsActive filter không thể set false**: hỗ trợ `is_active` query param để filter `false`. [location/internal/service/location.go](location/internal/service/location.go#L109-L147)
- [x] **SearchLocations dùng enum string không map về DB type**: map enum → DB type và bỏ filter khi UNSPECIFIED. [location/internal/service/location.go](location/internal/service/location.go#L201-L216)
- [x] **GetChildren dùng enum string không map về DB type**: map enum → DB type và bỏ filter khi UNSPECIFIED. [location/internal/service/location.go](location/internal/service/location.go#L234-L250)
- [x] **Cache invalidation thiếu cho tree**: thêm invalidation cho `location:tree:*`. [location/internal/biz/location/location_usecase.go](location/internal/biz/location/location_usecase.go#L165-L198)

## 🧩 Issues / Gaps
- None in this pass.

## Notes
- Nếu cần hỗ trợ inactive cho admin, cân nhắc thêm `include_inactive` hoặc tri-state boolean trong API.
