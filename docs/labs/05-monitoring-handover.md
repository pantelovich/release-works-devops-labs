# 05 · Verify a health signal and hand it over

**Scenario.** A fictional app owner previously found out about a failure from a customer. They want one reliable signal with a named receiver and a clear first action.

## Practice without an external notification service

1. Agree the monitored URL, healthy response, delivery channel and owner. In this exercise, use `/healthz` and have your partner observe the terminal signal over a screen share.
2. Run the [manual local release exercise](02-local-release.md) through healthy v1. Record which version you see and why HTTP 200 makes sense.
3. Switch to the intentional 503 configuration. Compare the health status to the logs. Check the error is a server response and can be distinguished from a lost connection.
4. Hand your partner a short notification, for example **Staging health failed. Check the active image, inspect the latest deployment, and use the approved recovery step if confirmed.** Ask them to explain what happens next.
5. Restore v1 and confirm the signal clears. Log the time, who reviewed the signal and which corrective step they chose.

**Accept when** the observed signal changes from healthy to failed and back, and your partner can follow the response note. Label this a local signal rehearsal. A customer notification service would also need proof that a real test message reached the authorised receiver.

If a later scope includes CloudWatch or Azure Monitor, confirm the route, one useful threshold and a test receiver before enabling it. Review prices and remove test alerts and destinations at handover. [AWS actionable alerts](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops06-bp01.html) · [Azure Monitor alerts](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-overview)
