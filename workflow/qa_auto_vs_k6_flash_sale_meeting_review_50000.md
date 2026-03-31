# 🏛️ QA-Auto vs k6 Flash Sale Load Test (50000 Rounds) — Multi-Agent Meeting Review

> **Date**: 2026-03-31
> **Topic**: Đánh giá chuyên sâu chiến lược QA automation và k6 cho Flash Sale tải lớn (50,000 rounds)
> **Scope**: `qa-auto/`, `qa-auto/k6/`, `gateway/scripts/`, `docs/10-appendix/references/CODEBASE_INDEX.md`
> **Panel**: Agent A (Architect), Agent B (Security/Performance), Agent C (Senior Go/Backend), Agent E (DevOps/SRE), Agent F (QA Lead)

---

## 👥 Panel Members

| Agent | Role | Why in this session |
|---|---|---|
| 📐 Agent A | System Architect | Kiểm tra boundary giữa E2E QA và performance engineering |
| 🛡️ Agent B | Security & Performance Engineer | Đánh giá bottleneck, metric validity, threshold correctness |
| 💻 Agent C | Senior Backend Engineer | Review tính đúng đắn endpoint flow và business signal instrumentation |
| 🛠️ Agent E | DevOps/SRE | Đánh giá workflow vận hành, reproducibility, CI/CD readiness |
| 🧪 Agent F | QA Lead/Test Engineer | Đánh giá test strategy tổng thể, risk regression, coverage gap |

---

## 1. Architecture and Scope Review

### 📐 Agent A (Architect)
> `qa-auto/package.json` đang kết hợp Playwright E2E (`test:*`) và k6 performance (`perf:flash-sale*`) trong cùng module. Cách này giúp team thao tác nhanh, nhưng boundary logic chưa đủ rõ: E2E pass không đồng nghĩa hệ thống chịu tải tốt, còn k6 pass chưa chứng minh đầy đủ business correctness.

### 🧪 Agent F (QA Lead)
> Tôi đồng ý một phần, nhưng việc đặt chung `qa-auto` giúp giảm friction onboarding. Vấn đề không phải cùng repo, mà là thiếu test matrix chính thức định nghĩa rõ "E2E gate" vs "Performance gate" vs "Business SLO gate".

### 🛠️ Agent E (DevOps/SRE)
> Tôi không đồng ý với việc giữ trạng thái thủ công hiện tại lâu dài. `qa-auto` chưa có pipeline CI riêng để chạy performance regression theo lịch/tier. Khi không có automation orchestration, kết quả load test bị phụ thuộc cá nhân chạy script.

### 🛡️ Agent B (Perf)
> Tranh luận này đúng trọng tâm: kiến trúc hiện tại usable cho tactical testing, nhưng chưa đạt strategic load engineering. Đặc biệt, report hiện tại vẫn có khả năng "pass kỹ thuật nhưng fail business" nếu sample checkout không đủ.

---

## 2. Core Logic Review (qa-auto vs k6)

### 🚨 Issue 2.1 — Report metric mismatch với route thực tế (P0)

**Location**: `qa-auto/k6/generate_report.js`, `qa-auto/k6/flash-sale.js`, `qa-auto/k6/lib/config.js`

**📐 Agent A**: Kiến trúc metrics không đồng nhất giữa producer và reporter. Script load đo `checkout-start`, nhưng report đọc `checkout-confirm` và `checkout_confirm_success_rate`, tạo blind spot.

**🛡️ Agent B**: Đây là data integrity issue cho observability. Decision dựa trên metric sai mapping có thể dẫn tới kết luận capacity sai hoàn toàn.

**💻 Agent C**: Trong `flash-sale.js` chỉ có route `checkout-start` được record thành `checkoutStartSuccessRate`; chưa thấy route/metric `checkout-confirm` thực thi. Report parser cần đổi theo metric thực hoặc bổ sung flow confirm tương ứng.

**🧪 Agent F**: Với trạng thái này, QA có thể nghĩ checkout "NOT TESTED" dù thực tế có traffic checkout-start. Đây là false-negative và gây lệch ưu tiên bug triage.

**🛠️ Agent E**: Nếu giữ mismatch này, dashboard SRE sẽ drift so với report markdown. Cần chuẩn hóa metric dictionary duy nhất giữa k6 script và report generator.

---

### 🚨 Issue 2.2 — `run_500_scale.sh` hardcode customer credentials, pool không đa dạng (P0)

**Location**: `qa-auto/k6/run_500_scale.sh`

**📐 Agent A**: Hardcode `CUSTOMER_EMAIL`/`CUSTOMER_PASSWORD` + `FLASH_SALE_CUSTOMER_IDS=auto` làm pattern test không đại diện realistic multi-shopper competition.

**🛡️ Agent B**: Một tài khoản hoặc pool nhỏ dưới tải cao làm tăng session collision và per-customer throttling giả tạo; kết quả bị bias, khó tách bottleneck hệ thống với bottleneck dữ liệu test.

**💻 Agent C**: Script `flash-sale.js` đã có guardrail `recommendedCustomerPool` tốt. Vấn đề là runner chưa tận dụng `FLASH_SALE_AUTH_TOKENS`/`FLASH_SALE_CUSTOMER_IDS` đủ lớn.

**🧪 Agent F**: Tôi phản biện nhẹ: hardcode giúp quick smoke. Nhưng với mục tiêu "50000 rounds chuyên sâu", pool động là bắt buộc để tránh invalid scientific result.

**🛠️ Agent E**: Đồng ý với QA. Cần chuyển sang secret-backed env set (CI variables), có manifest theo tier: 100/200/300/400/500 với pool size tối thiểu tương ứng `maxVUs`.

---

### 🚨 Issue 2.3 — Host-level dependency assumptions cho k6/report tooling (P1)

**Location**: `qa-auto/package.json`, `qa-auto/k6/run_500_scale.sh`, `qa-auto/k6/README.md`

**📐 Agent A**: Workspace rule ưu tiên Docker-first cho runtime; tuy nhiên `package.json` đang gọi `k6 run` trực tiếp, và `run_500_scale.sh` dùng `node generate_report.js` ở host.

**🛡️ Agent B**: Host drift (k6/node version khác nhau) làm khó so sánh run-to-run. Reproducibility yếu sẽ làm benchmark mất giá trị.

**💻 Agent C**: Có thể giữ local shortcut cho dev, nhưng cần một "canonical command path" dựa Docker cho baseline và release gating.

**🛠️ Agent E**: Tôi không đồng ý việc ưu tiên host shortcut trong tài liệu chính. Nên tài liệu hóa Docker-first, host-mode đặt thành optional debug.

**🧪 Agent F**: Chốt theo SRE hợp lý hơn cho QA governance: một nguồn sự thật duy nhất giúp giảm tranh cãi khi kết quả khác nhau giữa máy.

---

### 🚨 Issue 2.4 — Gap giữa E2E coverage và perf scenario objective (P1)

**Location**: `qa-auto/package.json`, `qa-auto/k6/README.md`

**📐 Agent A**: E2E suite rất rộng domain-level, nhưng chưa có mapping chính thức từ luồng business critical sang từng phase flash-sale (`preview_warmup`, `drop_open`, `checkout_rush`, `sold_out_fallback`).

**🧪 Agent F**: Chính xác. Nếu deploy bản mới, chưa có checklist nào trả lời câu hỏi "test nào bắt được regression của queue/sold_out/voucher rejection trong peak event?".

**🛡️ Agent B**: Chưa kể metrics soft-failure hiện có nhưng chưa có incident rubric rõ (khi nào queue_rate cao vẫn chấp nhận, khi nào phải fail release).

**🛠️ Agent E**: Cần gắn thêm SLO profile theo event type (normal campaign vs mega flash sale), tránh áp một threshold cứng cho mọi chiến dịch.

---

### 🚨 Issue 2.5 — Existing final report signals inconsistent sample depth (P2)

**Location**: `qa-auto/k6/results/FINAL_REPORT.md`

**📐 Agent A**: Report thể hiện `0p95` và success rate 0% nhiều tier, dấu hiệu dữ liệu chưa đủ hoặc route đo chưa khớp.

**🛡️ Agent B**: Đây là cảnh báo chất lượng dữ liệu, không nên dùng làm capacity sign-off.

**💻 Agent C**: Cần bắt buộc report ghi thêm sample count per business metric (passes/fails/total), không chỉ rate.

**🧪 Agent F**: Tôi đồng ý; QA sign-off phải dựa trên sample floor tối thiểu.

---

## 3. Codebase Index (Detailed for this review)

### 3.1 QA-Auto Core
- `qa-auto/package.json`: entrypoint script matrix cho Playwright và k6.
- `qa-auto/README.md`: hướng dẫn tổng quan test automation.
- `qa-auto/playwright.config.ts`: runtime setup cho E2E browser tests.

### 3.2 k6 Flash Sale Suite
- `qa-auto/k6/flash-sale.js`: scenario engine (4 phases), business soft-failure signals, customer pool guardrails.
- `qa-auto/k6/lib/config.js`: env parsing, scenario/threshold generation, phase rate logic, options export.
- `qa-auto/k6/README.md`: operational guidance và env contract.
- `qa-auto/k6/.env.example`: baseline biến môi trường cho team.
- `qa-auto/k6/run_500_scale.sh`: runner tự động 100->500%.
- `qa-auto/k6/generate_report.js`: parser JSON summary -> markdown report.
- `qa-auto/k6/results/*.json`, `qa-auto/k6/results/FINAL_REPORT.md`: artifacts lịch sử.

### 3.3 Supporting Perf Test Layer
- `gateway/scripts/performance-test.sh`: perf sanity script khác stack (hey-based) để cross-check API gateway behavior.
- `gateway/scripts/smoke-test.sh`: smoke checks cơ bản trước load.

### 3.4 Governance/Reference
- `docs/10-appendix/references/CODEBASE_INDEX.md`: codebase reference lớn, dùng cho scoping ownership và điều phối review.

---

## 4. PENDING ISSUES (Consolidated)

### 🚨 Critical (P0)
| # | Issue | Impact (Business) | Action Required |
|---|---|---|---|
| 1 | Metric/report mismatch (`checkout-start` vs `checkout-confirm`) | Quyết định capacity sai, risk release không đúng | Chuẩn hóa metric contracts giữa k6 script và report parser |
| 2 | Customer pool hardcode/small in 500-scale runner | Kết quả stress test thiếu đại diện, false bottleneck | Chuyển qua pool nhiều account bằng env/secret và enforce guardrail |

### 🟡 High Priority (P1)
| # | Issue | Impact (Business) |
|---|---|---|
| 3 | Host drift trong k6/report run path | Kết quả benchmark không tái lập, tranh cãi giữa team |
| 4 | Chưa có map E2E <-> Perf <-> Business SLO | QA sign-off không đủ bằng chứng cho flash sale release |

### 🔵 Nice to Have (P2)
| # | Issue | Value |
|---|---|---|
| 5 | Report thiếu sample floor và confidence hints | Tăng độ tin cậy và khả năng audit hậu kiểm |

---

## 5. Meeting Decisions (for 50000-Round Program)

1. **Adopt single source of truth for metrics**: canonical route/metric dictionary cho `flash-sale.js` và `generate_report.js`.
2. **Customer pool policy**: mọi run >200% scale phải có pool size theo công thức guardrail; bật enforce khi chạy pre-release.
3. **Docker-first reproducibility**: định nghĩa command chuẩn cho benchmark, host command chỉ dùng debug cá nhân.
4. **Dual-gate release policy**: release flash sale chỉ pass khi cả E2E critical journeys và k6 business thresholds đạt yêu cầu.
5. **Data quality gate**: report phải hiển thị sample counts và đánh dấu "insufficient sample" thay vì diễn giải rate đơn lẻ.

---

## 6. 7-Day Action Plan

- **Day 1-2**: Chuẩn hóa metrics names + update report parser (k6 owner + QA owner).
- **Day 2-3**: Refactor `run_500_scale.sh` nhận customer pools từ env secrets, bỏ hardcode credentials.
- **Day 3-4**: Tạo profile threshold theo event class (normal/flash/mega) và publish runbook.
- **Day 4-5**: Định nghĩa test matrix "E2E vs Perf vs Business signals" cho flash sale go/no-go.
- **Day 6-7**: Chạy lại full 100->500 tiers và phát hành report có sample floor + decision log.

---

## 🎯 Executive Summary

### Agent A (Architect)
QA-Auto và k6 đã có nền tảng tốt, nhưng chưa hoàn chỉnh ở lớp governance metric và release gate. Cần khóa chặt hợp đồng đo lường để tránh quyết định sai.

### Agent B (Security/Performance)
Rủi ro lớn nhất là chất lượng dữ liệu đo (metric mismatch, customer pool bias), không phải thiếu script. Fix đúng điểm này sẽ tăng độ tin cậy capacity planning đáng kể.

### Agent C (Senior Backend)
`flash-sale.js` đã có nhiều thành phần tốt (phase model, guardrails, business signals). Bước kế tiếp là đồng bộ reporter/runner để phản ánh đúng những gì script thực sự đo.

### Agent E (DevOps/SRE)
Cần chuẩn hóa Docker-first benchmark workflow và secret-driven load identities để kết quả tái lập, audit được, và dùng được trong CI/CD decision.

### Agent F (QA Lead)
Để đạt mục tiêu "50000 rounds chuyên sâu", cần hợp nhất E2E + perf + business acceptance thành một ma trận sign-off rõ ràng trước mỗi event flash sale.
