# 03 · AWS staging and ECS rollback

Use a personal AWS sandbox. The goal is to see ECS restore a previously completed deployment after a candidate fails its container health checks. Use [the local rehearsal](02-local-release.md) for the same release decision without an AWS account.

## Before you build

- Finish labs 01 and 02. Install Terraform 1.11.2 or later, AWS CLI v2, Docker with Buildx, Python 3 and Bash.
- Check your account plan, credits, Fargate availability and region before you create resources. Use short sessions. Fargate, ECR storage, S3 state, logs and public IPv4 can incur charges. A budget alert can be delayed.
- Use an isolated account and short-lived credentials, such as an AWS IAM Identity Center profile. The sandbox operator needs permission to create and remove the lab's S3, ECR, ECS, networking, CloudWatch and IAM resources, including `iam:PassRole` for the lab execution role. In a managed account ask the administrator to scope these permissions.
- Keep `lab.tfvars`, `lab.s3.tfbackend` and saved plans off Git. Terraform stores state in a private, versioned S3 bucket with an S3 lockfile. Keep that bucket until infrastructure teardown is verified. If you already applied the earlier v0.1.0 local-state lab, destroy with that version before starting this one.

[AWS account plans](https://docs.aws.amazon.com/us_en/awsaccountbilling/latest/aboutv2/free-tier.html) · [Fargate pricing](https://aws.amazon.com/fargate/pricing/) · [ECR pricing](https://aws.amazon.com/ecr/pricing/) · [Public IPv4 pricing](https://aws.amazon.com/vpc/pricing/) · [Budget alerts](https://docs.aws.amazon.com/cost-management/latest/userguide/bcm-lite-use-budget.html) · [S3 pricing](https://aws.amazon.com/s3/pricing/)

## 1. Prepare state and build an immutable image

Run from the repository root in Bash. Replace the profile and pick a unique name starting with `rw-lab-`. Check the printed identity before running any of the create commands.

```bash
set -euo pipefail
export AWS_PROFILE=your-sandbox-profile AWS_REGION=eu-west-2 AWS_PAGER=
LAB_NAME=rw-lab-yourname-01
aws sts get-caller-identity
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
IMAGE="$REGISTRY/$LAB_NAME:lab"
```

Run `aws sso login --profile "$AWS_PROFILE"` first if your profile uses IAM Identity Center. After confirming the identity, create a fresh state bucket in the selected London region. If a create command reports that a name already exists, choose a new name. Store the backend location locally. Keep AWS credentials in your profile.

```bash
STATE_BUCKET="$LAB_NAME-state-$(python3 -c 'import secrets; print(secrets.token_hex(4))')"
aws s3api create-bucket --bucket "$STATE_BUCKET" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION"
aws s3api put-public-access-block --bucket "$STATE_BUCKET" --expected-bucket-owner "$ACCOUNT_ID" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --expected-bucket-owner "$ACCOUNT_ID" \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-tagging --bucket "$STATE_BUCKET" --expected-bucket-owner "$ACCOUNT_ID" \
  --tagging 'TagSet=[{Key=Project,Value=release-works-devops-labs},{Key=Environment,Value=training}]'

cat > infra/aws/lab.s3.tfbackend <<BACKEND
bucket              = "$STATE_BUCKET"
key                 = "staging/terraform.tfstate"
region              = "$AWS_REGION"
allowed_account_ids = ["$ACCOUNT_ID"]
BACKEND
```

Use Terraform's default workspace. AWS recommends waiting 15 minutes after first enabling S3 versioning before you write to the bucket. Build the ECR image and review the architecture in that time. The backend's state and lockfile permissions are scoped to the bucket and its state path.

[S3 versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/manage-versioning-examples.html) · [Terraform S3 backend and IAM permissions](https://developer.hashicorp.com/terraform/language/backend/s3)

```bash
aws ecr create-repository --repository-name "$LAB_NAME" --image-tag-mutability IMMUTABLE \
  --tags Key=Project,Value=release-works-devops-labs Key=Environment,Value=training
aws ecr get-login-password |
  docker login --username AWS --password-stdin "$REGISTRY"
docker buildx build --platform linux/amd64 --load --tag "$IMAGE" .
docker push "$IMAGE"
DIGEST=$(aws ecr describe-images --repository-name "$LAB_NAME" \
  --image-ids imageTag=lab --query 'imageDetails[0].imageDigest' --output text)

cat > infra/aws/lab.tfvars <<VARS
account_id   = "$ACCOUNT_ID"
region       = "$AWS_REGION"
name         = "$LAB_NAME"
image_digest = "$DIGEST"
VARS
```

## 2. Deploy v1 and record the baseline

The plan creates a single-zone VPC and calls the ECS release module for one Fargate service with no inbound rules, an execution role scoped to the image and lab logs, and two task definitions. Tasks need outbound HTTPS and a public IPv4 address to pull the image and send logs. The sample uses neither NAT nor a load balancer.

```bash
terraform -chdir=infra/aws init -lockfile=readonly -backend-config=lab.s3.tfbackend
terraform -chdir=infra/aws plan -var-file=lab.tfvars -out=baseline.tfplan
terraform -chdir=infra/aws show -no-color baseline.tfplan
```

Review the account, change list and resource names. Then apply the saved plan.

```bash
terraform -chdir=infra/aws apply baseline.tfplan
aws ecs wait services-stable --cluster "$LAB_NAME" --services "$LAB_NAME"
BASELINE=$(terraform -chdir=infra/aws output -raw baseline_task_definition)
CANDIDATE=$(terraform -chdir=infra/aws output -raw candidate_task_definition)

aws ecs describe-services --cluster "$LAB_NAME" --services "$LAB_NAME" \
  --query 'services[0].{task:taskDefinition,rollout:deployments[0].rolloutState,running:runningCount,events:events[0:5].message}'
```

Record the full baseline ARN privately. Proceed when it matches the service, the rollout says `COMPLETED` and one task is running. If the first deployment never completes, diagnose the latest ECS events and task logs before deliberately introducing another failure. ECS needs a completed deployment to roll back.

## 3. Attempt v2, verify rollback and reconcile

```bash
terraform -chdir=infra/aws plan -var-file=lab.tfvars -var=release=v2 -out=candidate.tfplan
terraform -chdir=infra/aws show -no-color candidate.tfplan
```

Confirm the plan switches only the service task definition. Apply it and inspect repeatedly until you see the failed rollout, or until 15 minutes pass and you switch to recovery.

```bash
terraform -chdir=infra/aws apply candidate.tfplan
printf 'Baseline: %s\nCandidate: %s\n' "$BASELINE" "$CANDIDATE"
aws ecs describe-services --cluster "$LAB_NAME" --services "$LAB_NAME" \
  --query 'services[0].{task:taskDefinition,deployments:deployments[].{task:taskDefinition,state:rolloutState,reason:rolloutStateReason},events:events[0:10].message}'
aws logs tail "/ecs/$LAB_NAME" --since 15m --format short
```

Look for the v2 health-check HTTP 503 and the circuit-breaker event. Once ECS reports the baseline again, verify its running task and a completed rollout.

```bash
if ! aws ecs wait services-stable --cluster "$LAB_NAME" --services "$LAB_NAME"; then
  printf 'The brief stability check timed out. Inspect the rollout before proceeding.\n'
fi
TASK=$(aws ecs list-tasks --cluster "$LAB_NAME" --service-name "$LAB_NAME" \
  --desired-status RUNNING --query 'taskArns[0]' --output text)
aws ecs describe-tasks --cluster "$LAB_NAME" --tasks "$TASK" \
  --query 'tasks[0].{task:taskDefinitionArn,status:lastStatus,health:healthStatus}'
aws ecs describe-services --cluster "$LAB_NAME" --services "$LAB_NAME" \
  --query 'services[0].deployments[].{task:taskDefinition,state:rolloutState}'
terraform -chdir=infra/aws plan -var-file=lab.tfvars -var=release=v1 -out=recover.tfplan
```

Compare the healthy running task ARN with `$BASELINE`. Keep desired state on v1. If the reviewed recovery plan proposes restoring the v1 task definition, apply it and verify again. If automatic rollback timed out, record that outcome and use this same reviewed v1 plan for manual recovery.

[ECS deployment circuit breaker](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-circuit-breaker.html) · [ECS task IAM roles](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-iam-role-overview.html)

## 4. Clean up and hand over

```bash
terraform -chdir=infra/aws plan -destroy -var-file=lab.tfvars -out=cleanup.tfplan
terraform -chdir=infra/aws show -no-color cleanup.tfplan
```

Review the deletion list. Apply only to this lab. Delete the ECR repository separately, including its single lab image.

```bash
terraform -chdir=infra/aws apply cleanup.tfplan
terraform -chdir=infra/aws state list
aws ecr delete-repository --repository-name "$LAB_NAME" --force
docker logout "$REGISTRY"
```

Expect empty Terraform state. Run `aws ecr describe-repositories --repository-names "$LAB_NAME"` separately to confirm `RepositoryNotFoundException`. Check the exact repository and reason if you get another error.

Once the state is empty and the lab is closed, find the exact bucket from `lab.s3.tfbackend` in the S3 console under your sandbox account. Select **Empty** and follow the confirmation to remove every version and delete marker. Then select **Delete** for the same bucket. Confirm the bucket is absent. AWS recommends the console for emptying versioned buckets. Use a fresh clone or directory for a later run so the old backend configuration cannot be reused accidentally.

Check AWS Billing later for final usage. Keep a private record of the reviewed plan, health evidence, rollback result, elapsed time and cleanup. For a portfolio example, redact account IDs, bucket names and infrastructure identifiers. [Empty a versioned S3 bucket](https://docs.aws.amazon.com/AmazonS3/latest/userguide/empty-bucket.html)
