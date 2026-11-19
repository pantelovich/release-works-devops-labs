# 07 · Diagnose a failed health check

**Scenario.** A fictional app owner reports that a staging health probe failed. Find whether the probe has the wrong address, the connection is refused or the application is unhealthy. Leave a reliable check and instructions another operator can use.

Use the same Flask app and Compose project definition as [Lab 02](02-local-release.md). Open a practice issue and record your baseline commit. One person drives and the other reviews. Swap roles and repeat in separate practice branches.

## 1. Establish the baseline

Run from the repository root in a fresh Bash shell. Choose a free loopback port. Each operator needs a different port when sharing a Docker daemon. Run expected failures on their own, with Bash's `errexit` option off.

```bash
export COMPOSE_PROJECT_NAME="rw-ops-$(date +%s)-$$"
export LAB_IMAGE="$COMPOSE_PROJECT_NAME:v1"
export LAB_PORT="${LAB_PORT:-18082}"
docker build --build-arg RELEASE_VERSION=v1 --tag "$LAB_IMAGE" .
RELEASE_HEALTH=healthy docker compose up --wait --wait-timeout 35
docker compose ps
docker compose port api 8080
curl --noproxy '*' -fsS --max-time 5 "http://127.0.0.1:$LAB_PORT/version"
```

The app listens on port 8080 inside the container. The host uses the loopback binding shown by `docker compose port`. A disposable container on the same Compose network can reach the app by its service name `api`, using internal port 8080. Run this diagnostic from the Bash session above.

```bash
probe() {
  docker compose run --rm --no-deps --interactive=false -T api timeout 8s python -c '
import sys
from http.client import HTTPConnection

host, port, path = sys.argv[1:]
connection = HTTPConnection(host, int(port), timeout=2)
connection.request("GET", path)
response = connection.getresponse()
print(response.status, response.read().decode().strip())
connection.close()
' "$1" "$2" "${3:-/healthz}"
}

probe api 8080
docker compose logs --tail 15 api
```

Record HTTP 200, version `v1` and the relevant baseline logs. The diagnostic prints any HTTP response it receives. Your own script will need to report unhealthy HTTP responses as failures.

## 2. Separate the three failures

Before each check, write what you expect to see and what would disprove your hypothesis. Record the exception or HTTP status rather than relying on the alert text.

| Check | Expected evidence | Correction |
| --- | --- | --- |
| `probe api-missing.invalid 8080` | A name resolution error (`socket.gaierror`). No HTTP response. | Use the Compose service name `api`. |
| `probe api 8081` | `ConnectionRefusedError`. No HTTP response. | Use the internal port 8080. |
| `probe api 8080` after setting `RELEASE_HEALTH=unhealthy` | HTTP 503. The app is reachable and reports itself unhealthy. | Restore the healthy setting and verify health and version. |

Run `probe api 8080` after each addressing correction. For the application failure, use the running service and its recent logs to explain the result.

```bash
RELEASE_HEALTH=unhealthy docker compose up --wait --wait-timeout 35
```

Expect that command to fail its readiness wait. Check what actually happened before attributing the failure to the app.

```bash
docker compose ps
probe api 8080
probe api 8080 /version
docker compose logs --tail 15 api
```

Record the status, recent log lines and serving version before restoring. Compare startup messages with the healthy baseline and use the `/healthz` access entries to establish what changed. The same `v1` image can return 503 because its health configuration changed. Restore and verify the baseline.

```bash
RELEASE_HEALTH=healthy docker compose up --wait --wait-timeout 35
probe api 8080
probe api 8080 /version
docker compose logs --tail 15 api
```

Recovery evidence is HTTP 200, version `v1` and a recent successful health request in the logs. If the baseline differs, investigate before closing the incident.

## 3. Write and hand over your check

Each operator writes their own Bash or Python probe on a practice branch. Use only this lab's endpoints. Keep the check read-only and make the target and port clear. For a Compose-based probe, the disposable container above has Python and Linux `timeout` available. A socket timeout alone may leave DNS resolution waiting longer.

Accept the script when it:

- Bounds the request, including name resolution. An unreachable endpoint must return control within the stated deadline.
- Exits with status `0` for HTTP 200 and a nonzero status for name resolution failure, refused connection, timeout or unhealthy HTTP response.
- Prints the target and a clear problem, such as a DNS error, refused connection or HTTP 503.
- Passes again after recovery, with `v1` confirmed separately or by the script.

Record the failing and passing checks, the cause and correction, relevant logs and your contribution in the issue or PR. Give your partner the branch and a short runbook. Have them reproduce the results, identify a fault and recover without your help. Record their observations and swap roles. A copied runbook or an agent-run check cannot substitute for either person's own results.

Clean up your own project and image when the review is complete.

```bash
docker compose down --remove-orphans
docker image rm "$LAB_IMAGE"
unset COMPOSE_PROJECT_NAME LAB_IMAGE LAB_PORT
```

This evidence covers Docker's local service discovery, TCP connectivity and plain HTTP. [Lab 03](03-aws-staging.md) and [Lab 04](04-azure-staging.md) provide starting points for cloud rehearsals. Record actual sandbox results for any claims about cloud routes, firewall rules, IAM or RBAC and HTTPS/TLS. [Lab 05](05-monitoring-handover.md) explains what is needed to verify alert delivery to a real receiver.
