# 06 · Understand and verify a dependency security gate

**Scenario.** A small team wants known dependency vulnerabilities caught before a release. Read one real advisory, identify the affected version and check the fixed version.

Use the Python 3.12 virtual environment after labs 01 and 02. No cloud account or paid service is needed. The scanner queries public advisory services with package names and versions. Use only this fictional lab inventory.

## Check the real runtime lock

```bash
source .venv/bin/activate
python -m pip install pip-audit==2.10.1
python -m pip_audit --disable-pip --require-hashes --strict --progress-spinner off -r requirements.txt
```

The same command runs before tests and Docker in the checks workflow. Any nonzero exit stops that job. Inspect findings instead of ignoring them to get a green run. Normal hash-checked dependency installation remains required. The inventory-only scanner does not download and verify package artifacts.

## Prove detection with a temporary inventory

Run the whole block in Bash from the repo root. It writes temporary inventories and JSON reports. It never installs the affected version or edits the real lockfile.

```bash
(
set -euo pipefail
audit_dir="$(mktemp -d)"
trap 'rm -rf "$audit_dir"' EXIT
printf 'Jinja2==3.1.5\n' > "$audit_dir/requirements.txt"
if python -m pip_audit --disable-pip --no-deps --strict --progress-spinner off --format json --output "$audit_dir/affected.json" -r "$audit_dir/requirements.txt"; then
  echo "Expected the affected inventory to fail." >&2
  exit 1
fi
python - "$audit_dir/affected.json" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1], encoding="utf-8"))
identifiers = {"GHSA-cpwx-vrp4-4pq7", "CVE-2025-27516"}
detected = any(
    package["name"].lower() == "jinja2"
    and package["version"] == "3.1.5"
    and any(
        identifiers.intersection({finding["id"], *finding.get("aliases", [])})
        for finding in package["vulns"]
    )
    for package in report["dependencies"]
)
if not detected:
    raise SystemExit("Expected advisory missing. Investigate the report.")
print("Confirmed the expected advisory, not just a failed command.")
PY
printf 'Jinja2==3.1.6\n' > "$audit_dir/requirements.txt"
python -m pip_audit --disable-pip --no-deps --strict --progress-spinner off --format json --output "$audit_dir/fixed.json" -r "$audit_dir/requirements.txt"
echo "Affected version blocked. Fixed inventory passed today's advisory check."
)
```

An audit-service failure can also return a nonzero status. The JSON assertion checks the advisory ID or alias, so a network failure is not mistaken for detection. If a newer advisory affects the fixed example later, investigate it and update the example after review.

## Explain the result

Read the [Pallets advisory](https://github.com/pallets/jinja/security/advisories/GHSA-cpwx-vrp4-4pq7). It concerns a sandbox escape with untrusted templates. Version 3.1.6 fixes that advisory. This Flask lab does not render templates, so the exercise does not demonstrate an exploitable path in this app.

The temporary inventories are deliberately incomplete. `--no-deps` is used only for this single-package demonstration. The real gate scans the complete pinned runtime lock with `--require-hashes`.

Each person records the package/version, advisory, relevant conditions, proposed fix and before/after result. Swap driver and reviewer. Explain why a clean report does not establish that an application is secure. A real update also needs a regenerated lock, passing app tests and a reviewed release.

**Accept when** both people can explain the finding, prove the affected version fails, verify the fixed inventory and distinguish findings from scanner errors. This is internal training until personally completed. No scanner guarantees the absence of unknown vulnerabilities.

[Versioned pip-audit documentation](https://github.com/pypa/pip-audit/blob/v2.10.1/README.md)
