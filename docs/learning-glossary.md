# Learning glossary

These short definitions use the examples from the Flask, Docker and AWS staging labs. They describe the practice project only; completing a command or reading a result is not evidence that a learner has completed the wider delivery work.

## Git branch

A Git branch is a separate line of work that lets you change files without changing the shared `main` branch. In [Lab 01](labs/01-ci-repair.md), create a practice branch for the deliberately broken workflow, then repair it and ask for review.

## Pull request

A pull request (PR) proposes a branch change for review before it is merged into another branch. The CI checks in [Lab 01](labs/01-ci-repair.md) should run against the practice PR so a reviewer can inspect both the change and its evidence.

## CI job

A continuous integration (CI) job is an automated group of checks run by a service such as GitHub Actions. In this project the job installs the locked Python dependencies, runs lint and tests, audits dependencies, and builds the Docker image; a failed step prevents the later release checks from being treated as successful.

## Exit code

An exit code is the number a command returns to the shell when it finishes, where `0` conventionally means success and a non-zero value means failure. The unhealthy Docker Compose command in [Lab 02](labs/02-local-release.md) is expected to return non-zero, while the service can still be running and answering HTTP requests.

## Dependency lockfile

A dependency lockfile records the exact packages and hashes that an application is allowed to install, rather than only broad version ranges. This project uses the hash-checked `requirements.txt` in CI and the labs, so a dependency install must match the reviewed contents before tests or an image build proceed.

## Docker image

A Docker image is a packaged filesystem and configuration used to start a container, including the Flask service and its runtime dependencies. The local release rehearsal builds separate v1 and v2 images so the operator can identify which release is serving and restore the known-good image.

## Image tag

An image tag is a human-readable label such as `v1` or `lab` that points to an image in a Docker registry or local image store. A tag can be moved or reused, so [Lab 03](labs/03-aws-staging.md) uses an immutable ECR repository and still records the image digest for stronger release identification.

## Image digest

An image digest is a content-derived identifier, commonly shown as `sha256:...`, for one exact image manifest. Unlike a mutable tag, the digest continues to identify the same image bytes, which is why the AWS lab records the ECR digest and passes it to Terraform.

## Container health check

A container health check tests whether a running container is ready to serve traffic, rather than merely whether its process exists. In the local lab, a healthy Flask response from `/healthz` is HTTP 200, while the deliberate v2 application condition returns HTTP 503 and should fail the readiness wait.

## HTTP 503

HTTP 503 Service Unavailable means the server is currently unable to serve the request, often because the application is not ready or is deliberately unhealthy. In [Lab 02](labs/02-local-release.md), v2 is still reachable and returns 503 from `/healthz`; that is different from a failed connection, where no HTTP response arrives because the port, container or network path is unavailable.

## Rollback

A rollback restores a previously verified release after a candidate fails an agreed check. The local rehearsal returns from v2 to v1, while [Lab 03](labs/03-aws-staging.md) observes ECS restoring a completed baseline deployment and then reconciles Terraform state.

## IAM role

An AWS Identity and Access Management (IAM) role is an identity with permissions that an AWS service or trusted principal can assume temporarily. In the AWS lab, ECS tasks use an execution role to pull the image and write logs, so its permissions should be limited to what this lab needs rather than using a person's long-lived credentials.

## Security group

An AWS security group is a stateful set of virtual firewall rules attached to resources such as network interfaces. The AWS staging design has no inbound rule for the service and permits the outbound access needed by its tasks, so a connection failure must not be confused with the Flask application returning HTTP 503.

## Terraform plan

A Terraform plan previews the infrastructure changes Terraform would make from configuration and current state without applying them. Review the baseline and candidate plans in [Lab 03](labs/03-aws-staging.md), checking the account, resource names and task definition change before approval.

## Dependency vulnerability

A dependency vulnerability is a known security weakness in a library or tool version that an application uses. [Lab 06](labs/06-dependency-security.md) checks the real lock and proves that the temporary Jinja2 3.1.5 inventory is rejected for its advisory while 3.1.6 passes that particular check; a clean scan does not prove that the application has no unknown or unrelated risks.

## Official references

- [GitHub: About branches](https://docs.github.com/en/pull-requests/reference/branches)
- [GitHub: About pull requests](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests)
- [Docker: Image digests](https://docs.docker.com/dhi/explore/security-concepts/digests/)
- [Docker: Healthcheck instruction](https://docs.docker.com/reference/dockerfile/#healthcheck)
- [AWS: IAM roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html)
- [AWS: Security groups for your VPC](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html)
- [Terraform: `plan` command](https://developer.hashicorp.com/terraform/cli/commands/plan)
- [pip-audit documentation](https://github.com/pypa/pip-audit/blob/v2.10.1/README.md)
