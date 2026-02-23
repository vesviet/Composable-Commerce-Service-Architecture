# Gateway Service - Code Review Issues

**Last Updated**: 2026-01-21

This document lists issues found during the review of the Gateway Service, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## 🚩 PENDING ISSUES (Unfixed)
- [Medium] [GW-P2-02 Fixed-delay retries in proxy path]: `makeRequestWithRetry` uses a constant delay which can amplify load during outages. Required: implement exponential backoff with jitter in [gateway/internal/router/route_manager.go](gateway/internal/router/route_manager.go#L56-L139).
- [Medium] [GW-P2-03 Middleware assembly split across router + manager]: Middleware chains are still assembled in `wrapHandlerWithMiddleware` inside the router, not centralized. Required: move chain assembly into `MiddlewareManager` and have the router call a single chain builder. See [gateway/internal/router/kratos_router.go](gateway/internal/router/kratos_router.go#L268-L311) and [gateway/internal/middleware/manager.go](gateway/internal/middleware/manager.go).

## 🆕 NEWLY DISCOVERED ISSUES
- None

## ✅ RESOLVED / FIXED
- [FIXED ✅] GW-P2-01 Deprecated `routes` section removed from gateway config; routing is now exclusively under `routing.patterns` in [gateway/configs/gateway.yaml](gateway/configs/gateway.yaml).
