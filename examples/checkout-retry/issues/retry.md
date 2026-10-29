## Outcome

The checkout client retries the retryable list a bounded number of times, with jitter, and stops when the budget is spent.

## Context

Parent: the checkout-retry epic. Blocked by the retryable-error list and by idempotency keys. A retry without a key is a double charge.

## Done when

- [ ] The client retries only the errors from the classify task
- [ ] Every retry sends the same idempotency key as the first attempt
- [ ] The budget defaults to 3 attempts and is configurable
- [ ] Delay uses exponential backoff with jitter and a cap
- [ ] The final error is the last upstream error, not a generic timeout

## Out of scope

The dashboard. Metrics are recorded here only if the hook already exists. Otherwise that is the metrics task.
