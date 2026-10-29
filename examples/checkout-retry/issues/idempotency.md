## Outcome

Repeating a charge request with the same idempotency key returns the original charge and does not create another one.

## Context

Parent: the checkout-retry epic. The retry policy cannot ship until this is true, or a retry of a timed-out success would double-charge.

## Done when

- [ ] `POST /charges` accepts an idempotency key header
- [ ] A second request with the same key and the same body returns the stored response
- [ ] A second request with the same key and a different body is rejected
- [ ] Keys expire after 24 hours

## Out of scope

Client retries. This issue only makes the charge request safe to repeat.
