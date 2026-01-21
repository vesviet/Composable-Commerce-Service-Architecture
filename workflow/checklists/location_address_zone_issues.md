# Location & Address/Zone Flow - Issues Checklist

**Last Updated**: 2026-01-21

## ✅ Reviewed Areas
- Service layer filtering + validation
- Usecase cache + tree logic
- Search and children filters

## 🚩 PENDING ISSUES (Unfixed)
- None

## 🆕 NEWLY DISCOVERED ISSUES
- None

## ✅ RESOLVED / FIXED
- [FIXED ✅] IsActive filter supports false via `is_active` query param. See [location/internal/service/location.go](location/internal/service/location.go#L109-L147).
- [FIXED ✅] SearchLocations maps enum → DB type and skips filter when UNSPECIFIED. See [location/internal/service/location.go](location/internal/service/location.go#L201-L216).
- [FIXED ✅] GetChildren maps enum → DB type and skips filter when UNSPECIFIED. See [location/internal/service/location.go](location/internal/service/location.go#L234-L250).
- [FIXED ✅] Cache invalidation added for `location:tree:*`. See [location/internal/biz/location/location_usecase.go](location/internal/biz/location/location_usecase.go#L165-L198).

## Notes
- Nếu cần hỗ trợ inactive cho admin, cân nhắc thêm `include_inactive` hoặc tri-state boolean trong API.
