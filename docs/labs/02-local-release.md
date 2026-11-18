# 02 · Release and recover locally

**Scenario.** A fictional client wants a repeatable staging rollout. Show what happens when a candidate starts but returns an unhealthy status. Retain the healthy version, demonstrate recovery and let the client role run the next release.

**Time.** 45–75 minutes. **Spend.** No cloud resources. This path uses Docker on your own machine.

## 1. Run the reference rehearsal

From the repository root:

```bash
bash scripts/rehearse-local.sh
```

Read the output in order. It builds v1 and v2, verifies v1, expects v2’s Docker readiness wait to fail, checks that v2 is actually serving a 503, then restores and verifies v1. It cleans up only the project and images it created. The application-level failure is expected. A missing container or a wrong version is a failed rehearsal.

## 2. Repeat it yourself

Use the Bash shell from the repo root. Use a different project name and port if you are both on the same machine.

```bash
export COMPOSE_PROJECT_NAME=release-works-manual
export LAB_PORT=18080
docker build --build-arg RELEASE_VERSION=v1 -t release-works-demo:v1 .
docker build --build-arg RELEASE_VERSION=v2 -t release-works-demo:v2 .
LAB_IMAGE=release-works-demo:v1 RELEASE_HEALTH=healthy docker compose up --wait --wait-timeout 35
curl -fsS "http://127.0.0.1:$LAB_PORT/version"
curl -fsS "http://127.0.0.1:$LAB_PORT/healthz"
```

Expected evidence is version `v1` and HTTP 200. Record the time and the image ID with `docker image inspect release-works-demo:v1 --format '{{.Id}}'`.

```bash
LAB_IMAGE=release-works-demo:v2 RELEASE_HEALTH=unhealthy docker compose up --wait --wait-timeout 35
```

The command should return a nonzero status. Run it as a standalone command, then verify what actually happened:

```bash
docker compose ps
docker compose logs --tail 15 api
curl -fsS "http://127.0.0.1:$LAB_PORT/version"
curl -sS -i "http://127.0.0.1:$LAB_PORT/healthz"
```

You should see v2 and HTTP 503. A connection error is a different problem. Check the port, Compose status and logs before attributing it to the candidate. This local environment has one serving container, so v2 replaces v1 during the rehearsal. The cloud labs teach a different rollout with an isolated or retained baseline.

```bash
LAB_IMAGE=release-works-demo:v1 RELEASE_HEALTH=healthy docker compose up --wait --wait-timeout 35
curl -fsS "http://127.0.0.1:$LAB_PORT/version"
curl -fsS "http://127.0.0.1:$LAB_PORT/healthz"
docker compose down
docker image rm release-works-demo:v1 release-works-demo:v2
unset COMPOSE_PROJECT_NAME LAB_PORT
```

**Accept when** a second operator reproduces v1 → v2/503 → v1/200 using the handover. Include measured recovery time only if you recorded start and finish. Capture why the service reported unhealthy, how you found the running version and what you would improve for a client. Continue only once you can do this without the reference script.

[Docker Compose wait behaviour](https://docs.docker.com/reference/cli/docker/compose/up/) · [AWS staging](03-aws-staging.md) · [Azure staging](04-azure-staging.md)
