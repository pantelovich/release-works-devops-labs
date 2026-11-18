# 01 · Fix a broken pipeline

**Scenario.** A fictional developer reports that the main release process is blocked by a dependency install error. The application works on their machine. Your partner is the reviewer and owns acceptance.

**Time.** 45–75 minutes after setup. **Spend.** £0 with the local route and GitHub standard hosted runners for this public repo. [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)

## Before you change anything

Use a branch or your own fork. The person who owns this repository can push a practice branch here. A friend can fork it into their own account, open a PR against main in that fork and share the link for review. Enable Actions in your own fork if GitHub prompts you. Keep practice PRs out of the shared main branch.

From the repo root:

```bash
git switch -c codex/ci-repair-practice
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install --require-hashes -r requirements.txt
python -m unittest discover -s tests -v
```

Record the baseline commit and test outcome. On the practice branch, create the fictional incident in `.github/workflows/checks.yml`. Change the requirements filename in the Python dependency install command from `requirements.txt` to `requirements-missing.txt`. Do not change application code. Commit the lab fault and open a draft PR to trigger checks. If you are keeping it local, run the same failing install command in your virtual environment instead.

```bash
git add .github/workflows/checks.yml
git commit -m "Practice: reproduce missing dependency lock path"
git push -u origin HEAD
```

## Diagnose and fix

1. Read the first failed step and record the command, error and repository path.
2. Test your hypothesis locally. Does the file exist? Is the command using the repository root?
3. Repair the filename, review the diff and push the fix to the same practice branch.
4. Compare the red and green run for the same workflow. Check whether lint, format and unit tests really ran. A successful deploy begins with verified checks.
5. On your practice branch, change the expected status in one healthy test from 200 to 201. Verify the unit test step fails and later steps in that job are skipped. Restore the test before asking for approval.
6. Ask your reviewer to explain the cause and reproduce the passing check. Close the practice PR without merging.

<details>
<summary>Hints after your first attempt</summary>

The install failure occurs before Flask runs. Compare the missing file reported in the workflow with `git ls-files requirements.txt`. The minimal fix is the lockfile path, while keeping the hash requirement. For the second failure, inspect the assertion and see what the application actually returned. Skipping a failed test would break the release gate.

</details>

**Accept when** the original failed run is explained, the corrected run goes green, a real failing assertion is correctly blocked, and the reviewer can rerun the test. For public run links use fictional material only. Follow with the [local release rehearsal](02-local-release.md).
