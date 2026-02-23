# 📖 Project Glossary

> Central reference for all project terminology, event codes, enums, and shared domain language. Update this file on any cross-team agreement or new entity/event type.

## Key Terms

- **Order:** Customer purchase order, root concept for all transactional flows.
- **SKU:** Stock Keeping Unit, unique inventory identifier within the system.
- **Event:** Asynchronous message, publish/subscriber pattern, versioned via JSON Schema.
- **Bounded Context:** Domain boundary in DDD, examples: `Order`, `Product`, `Discount`, etc.
- **OpenAPI Spec:** Standardized API contract description, used for codegen, testing, automated review.

## Common Enums

- **OrderStatus:** `PENDING`, `CONFIRMED`, `SHIPPED`, `DELIVERED`, `CANCELLED`, etc.
- **PaymentStatus:** `INITIATED`, `SUCCESS`, `FAILED`, etc.

## Events

- `order.created`: Published when a new order is created.
- `stock.updated`: Published when inventory stock level changes.
- `payment.processed`: Published when payment transaction is successfully processed.
- ... (add new events as needed)

---

**Update this file as a source of truth for: naming conventions, field naming, status codes, cross-service identifiers, etc.**
