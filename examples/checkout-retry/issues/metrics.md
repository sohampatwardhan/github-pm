## Outcome

An operator can see retry attempts, successes, and exhausted budgets for checkout.

## Context

Parent: the checkout-retry epic. Blocked by the retry client, which is what produces the events.

## Done when

- [ ] A counter of retry attempts, tagged by error code
- [ ] A counter of exhausted budgets
- [ ] A dashboard with those two series and a link from the epic

## Out of scope

Alerting. File that separately if on-call should page.
