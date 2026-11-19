# Context

The first lab follows a realistic DevOps handover. A local path supports practice without credentials. AWS and Azure sandbox paths are optional.

Dependency security now has a known-vulnerability CI gate and a temporary-inventory exercise. Manual Docker image names are isolated per operator. Codex and Copilot use the canonical private-operations handoff file. Copilot's glossary is complete; its current scope is the read-only lab external-link audit COPILOT-002. Check the canonical file before assigning or editing.

[Lab 07](docs/labs/07-operations-troubleshooting.md) reuses the existing app image as a disposable probe on the Compose network. This keeps the local networking exercise independent of cloud accounts or another service. Learners script their own checks, document the incident and verify each other's work before applying the method to a cloud sandbox.
