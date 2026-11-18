# ADR 0001 · One stateless service for three environments

## Context

Two learners need to distinguish CI failures, an unhealthy rollout and a verified recovery. They also need a route that works without a cloud account and supports clean external handover evidence.

## Decision

Use one stateless Flask service packaged with Gunicorn. Keep the version and readiness endpoints stable. Use local Compose for the shared rehearsal, Terraform for one optional AWS ECS lab and Bicep for one optional Azure Container Apps lab. Model failure through an explicit configuration value. The AWS ECS release is a child module with its network supplied by the root. Live runs use a dedicated versioned S3 state bucket with native locking. Cloud CI validates templates without cloud credentials.

## Consequences

The same application behaviour can be compared across platforms. Local Compose replaces one service, whereas cloud deployment controllers can retain or isolate a healthy revision. The lab exercises recovery for a stateless service. Schema migrations, persistent volumes, database recovery and production traffic require their own rehearsals.

## Follow-up

Add workload identity for cloud deployments only after both learners can explain and manually verify the existing release paths. Record any live tests separately from local checks.
