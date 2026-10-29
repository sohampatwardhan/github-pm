## Outcome

The client and the server share one list of checkout errors that are safe to retry.

## Context

Parent: the checkout-retry epic. Nothing else is blocked on the wording of the list except the retry policy, which must not retry a 400.

## Done when

- [ ] Document which HTTP statuses and gateway error codes are retryable
- [ ] A 400, a 401, and a card-declined code are not retryable
- [ ] A 408, a 429, and a 503 are retryable
- [ ] The list lives in one module the retry policy can import

## Out of scope

The retry loop itself, and idempotency keys.
