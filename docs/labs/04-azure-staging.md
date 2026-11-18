# 04 · Azure staging and revision traffic

Use your own Azure sandbox to deploy a Bicep-defined Container App. Keep traffic on v1 while v2 fails readiness, promote a healthy revision, then move traffic back. [The local rehearsal](02-local-release.md) covers the same release decision without an Azure account.

## 1. Get the lab image and choose the subscription

Use Azure CLI, its Container Apps extension if required, Bicep, Docker and Bash. The command below uses the public Linux AMD64 image built from the v0.1.0 lab source. If you change the app, use **Actions → Publish lab image → Run workflow** on your fork's main branch. Copy the new digest from the run summary. If your package is private, anonymous pulls require making that synthetic package public under **Package settings → Change visibility**. GitHub makes that package visibility change permanent.

The Bicep template creates only the environment and app. The app has a public HTTPS endpoint for synthetic version and health data. The environment does not create a Log Analytics workspace. Revisions scaled to one replica can consume credits or generate charges. Check your exact subscription offer, regional availability and the Container Apps meter before provisioning. Finish and delete the resource group in one session.

[GitHub Packages access](https://docs.github.com/en/packages/learn-github-packages/configuring-a-packages-access-control-and-visibility) · [Azure free account services](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/create-free-services) · [Container Apps billing](https://learn.microsoft.com/en-us/azure/container-apps/billing)

Run from the repository root in Bash. Replace the subscription and lab names with yours.

```bash
set -euo pipefail
IMAGE_REF='ghcr.io/pantelovich/release-works-devops-labs@sha256:a1a88ced833c89505dad4b7be13920b1c93f84bf6ef3feac0673d5b107adcbec'
AZ_SUBSCRIPTION='your-sandbox-subscription-id'
LAB_REGION=uksouth
LAB_RG=rg-rw-lab-yourname-01
LAB_APP=rw-lab-yourname-01

DOCKER_CONFIG_TMP=$(mktemp -d)
docker --config "$DOCKER_CONFIG_TMP" pull --platform linux/amd64 "$IMAGE_REF"
rmdir "$DOCKER_CONFIG_TMP"
az login
az account set --subscription "$AZ_SUBSCRIPTION"
az account show --query '{subscription:name,id:id,tenant:tenantId}'
az provider show --namespace Microsoft.App --query registrationState --output tsv
az group exists --name "$LAB_RG"
```

Confirm the digest supports Linux AMD64, the Azure account is your sandbox and the last command returned `false`. If Microsoft.App is unregistered and your subscription permits it, run `az provider register --namespace Microsoft.App --wait`. If the CLI cannot find the Container Apps command group, run `az extension add --name containerapp --upgrade` and try again. Do not reuse another project's resource group.

## 2. Deploy and pin v1

```bash
az group create --name "$LAB_RG" --location "$LAB_REGION"
az deployment group what-if --resource-group "$LAB_RG" --name baseline \
  --template-file infra/azure/main.bicep --parameters appName="$LAB_APP" imageRef="$IMAGE_REF"
```

Review the what-if. Then deploy.

```bash
az deployment group create --resource-group "$LAB_RG" --name baseline \
  --template-file infra/azure/main.bicep --parameters appName="$LAB_APP" imageRef="$IMAGE_REF"
FQDN=$(az containerapp show --name "$LAB_APP" --resource-group "$LAB_RG" \
  --query properties.configuration.ingress.fqdn --output tsv)
BASELINE=$(az containerapp show --name "$LAB_APP" --resource-group "$LAB_RG" \
  --query properties.latestRevisionName --output tsv)
curl --fail --show-error --silent --retry 6 --retry-delay 5 --max-time 15 "https://$FQDN/healthz"
curl --fail --show-error --silent "https://$FQDN/version"
az containerapp ingress traffic set --name "$LAB_APP" --resource-group "$LAB_RG" \
  --revision-weight "$BASELINE=100"
```

Record HTTP success and v1. Pinning the named revision keeps later candidates from taking the traffic allocation for the latest revision.

## 3. Observe the failed candidate and move traffic

```bash
BAD="$LAB_APP--bad"
if ! az containerapp update --name "$LAB_APP" --resource-group "$LAB_RG" \
  --revision-suffix bad --min-replicas 1 \
  --set-env-vars RELEASE_VERSION=v2 RELEASE_HEALTH=unhealthy; then
  printf 'Inspect the candidate provisioning result before proceeding.\n'
fi
```

The failed readiness check can cause the update command to report a provisioning error. If it does, check whether Azure created the named revision. Inspect it every few seconds until you have its health or provisioning result. If there is no revision, capture the deployment error before trying again.

```bash
az containerapp revision show --name "$LAB_APP" --resource-group "$LAB_RG" \
  --revision "$BAD" \
  --query 'properties.{health:healthState,provisioning:provisioningState,running:runningState,traffic:trafficWeight}'
az containerapp ingress traffic show --name "$LAB_APP" --resource-group "$LAB_RG"
curl --fail --show-error --silent "https://$FQDN/version"
```

Confirm the unhealthy revision has no traffic and the public endpoint still serves v1. If an active failed revision exists, deactivate it with `az containerapp revision deactivate --name "$LAB_APP" --resource-group "$LAB_RG" --revision "$BAD"` before continuing.

```bash
APPROVED="$LAB_APP--approved"
az containerapp update --name "$LAB_APP" --resource-group "$LAB_RG" \
  --revision-suffix approved --min-replicas 1 \
  --set-env-vars RELEASE_VERSION=v2 RELEASE_HEALTH=healthy
az containerapp revision show --name "$LAB_APP" --resource-group "$LAB_RG" \
  --revision "$APPROVED" --query 'properties.{health:healthState,running:runningState,traffic:trafficWeight}'
```

Wait for the approved revision to be healthy and running. Review live traffic before and after the change. Allow for routing propagation and repeat each HTTP check if needed.

```bash
az containerapp ingress traffic set --name "$LAB_APP" --resource-group "$LAB_RG" \
  --revision-weight "$APPROVED=100"
curl --fail --show-error --silent "https://$FQDN/healthz"
curl --fail --show-error --silent "https://$FQDN/version"

az containerapp ingress traffic set --name "$LAB_APP" --resource-group "$LAB_RG" \
  --revision-weight "$BASELINE=100"
curl --fail --show-error --silent --retry 6 --retry-delay 5 --max-time 15 "https://$FQDN/healthz"
curl --fail --show-error --silent "https://$FQDN/version"
az containerapp ingress traffic show --name "$LAB_APP" --resource-group "$LAB_RG"
az containerapp revision deactivate --name "$LAB_APP" --resource-group "$LAB_RG" --revision "$APPROVED"
```

Record the observed v1 → v2 → v1 proof and the revision weights. The CLI steps deliberately change the live app after Bicep deployment. Reapplying the template is a deliberate baseline reset, so review what-if before doing it.

[Container Apps revisions](https://learn.microsoft.com/azure/container-apps/revisions) · [Traffic commands](https://learn.microsoft.com/en-us/cli/azure/containerapp/ingress/traffic?view=azure-cli-latest)

## 4. Clean up

```bash
az resource list --resource-group "$LAB_RG" --output table
az group delete --name "$LAB_RG" --yes
az group exists --name "$LAB_RG"
```

Review the resource list and confirm this is your lab group before you run delete. A completed cleanup returns `false`. Check the subscription's Cost Analysis once usage catches up. Keep the digest, revision state, traffic weights, observed HTTP results and teardown confirmation. Redact subscription IDs and the public hostname before sharing.
