# Crossplane Migration Design: Terraform to Crossplane

**Date:** 2026-02-06
**Branch:** hive
**Scope:** f5xc-tops-infra (AWS resources), f5xc-tops-mgmt-cluster (provider config only)
**Out of scope:** Terrakube Terraform in f5xc-tops-mgmt-cluster/terraform/terrakube/ (stays as-is)

## Goal

Finish converting all remaining AWS infrastructure from Terraform to Crossplane manifests. This is a code-only migration -- existing Terraform-managed resources are not removed. Crossplane manifests create parallel `v2` resources.

## Current State

### Already in Crossplane (v2)

| Domain | Resources |
|--------|-----------|
| UDF Dispatch | Lambda function, IAM role/policy, SQS queue + DLQ + policy, SQS event source |
| UDF Worker | Lambda function, IAM role/policy, DynamoDB tables (deployment-state, job-state), DynamoDB stream trigger |
| Utility Lambdas | 4 Lambda functions (user-create, user-remove, ns-create, ns-remove) |
| Shared | Base Lambda execution role + policy, S3 lambda-bucket |
| Deployment State | S3 bucket + lifecycle + encryption + policy + public access block |
| Observability | S3 global-logs bucket, Vector IAM user + access key + policy |
| Loadgen | ECS Fargate cluster + task def + IAM + network + log group + scheduled rules, ECR repos, S3 loadgen buckets |

### Gaps (Terraform-only, no Crossplane equivalent)

| Domain | Missing Resources | Count |
|--------|-------------------|-------|
| ACME Client | 3 Lambda functions (MCN/App/Sec), IAM role/policy, EventBridge rule + 3 targets, 3 Lambda permissions | ~12 |
| Cert Management | 3 Lambda functions (MCN/App/Sec), IAM role/policy, S3 cert bucket + policy, S3 notification, 3 Lambda permissions | ~12 |
| Token Refresh | 3 Lambda functions (MCN/App/Sec), IAM role/policy, 3 EventBridge schedules + targets, 3 Lambda permissions | ~12 |
| Provisioning Workflow | 6 Lambda functions, SFN state machine, 3 IAM roles/policies, CloudWatch log group | ~14 |
| UDF Helpers | 5 Lambda functions (example/apilab/botlab/caaslab/waaplab), IAM role/policy | ~8 |
| UDF Cleaner | 1 Lambda function, IAM role/policy, EventBridge schedule + target, Lambda permission | ~5 |
| UDF Lab Config | DynamoDB table items (9), S3 lab registry bucket + policy, S3 lab info objects (9) | ~20 |
| SSM Parameters | Parameter Store entries (3 module instances: mcn_lab, app_lab, sec_lab) | ~3+ |
| **Total** | | **~90** |

## Directory Structure (Reorganized by Functional Domain)

The existing by-service layout (`s3/`, `lambda/`, `iam/`, etc.) is replaced with a by-domain layout. All existing manifests are moved.

```
crossplane/aws/
├── shared/                         # Cross-cutting resources
│   ├── iam.yaml                    # Base lambda execution role + policy + attachment
│   ├── s3-lambda-bucket.yaml       # Lambda code S3 bucket
│   └── ssm-parameters.yaml         # SSM Parameter Store entries (NEW)
│
├── udf-dispatch/                   # SQS -> dispatch pipeline
│   ├── lambda.yaml                 # dispatch function
│   ├── iam.yaml                    # dispatch role/policy/attachment
│   ├── sqs.yaml                    # queue + DLQ + policy
│   └── event-sources.yaml          # SQS trigger
│
├── udf-worker/                     # DynamoDB stream -> worker pipeline
│   ├── lambda.yaml                 # worker function
│   ├── iam.yaml                    # worker role/policy/attachment
│   ├── dynamodb.yaml               # deployment-state + job-state tables
│   └── event-sources.yaml          # DynamoDB stream trigger
│
├── udf-lab-config/                 # Lab configuration data (NEW)
│   ├── dynamodb.yaml               # lab_configuration table
│   ├── s3-registry.yaml            # lab registry bucket + policy
│   └── data.yaml                   # DynamoDB items + S3 lab info objects
│
├── udf-cleaner/                    # Scheduled cleanup (NEW)
│   ├── lambda.yaml                 # cleaner function
│   ├── iam.yaml                    # cleaner role/policy/attachment
│   └── eventbridge.yaml            # schedule rule + target + permission
│
├── udf-helpers/                    # Lab pre-provisioning hooks (NEW)
│   ├── lambda.yaml                 # 5 helper functions
│   └── iam.yaml                    # helpers role/policy/attachment
│
├── utility-lambdas/                # User/namespace CRUD
│   ├── lambda.yaml                 # user-create, user-remove, ns-create, ns-remove
│   └── iam.yaml                    # (NEW) dedicated utility role/policy
│
├── acme-client/                    # ACME certificate generation (NEW)
│   ├── lambda.yaml                 # 3 functions (mcn/app/sec)
│   ├── iam.yaml                    # acme role/policy/attachment
│   └── eventbridge.yaml            # daily trigger + 3 targets + 3 permissions
│
├── cert-mgmt/                      # Certificate management (NEW)
│   ├── lambda.yaml                 # 3 functions (mcn/app/sec)
│   ├── iam.yaml                    # cert-mgmt role/policy/attachment
│   ├── s3.yaml                     # cert bucket + policy + public access + encryption
│   └── s3-notifications.yaml       # S3 -> Lambda triggers + 3 permissions
│
├── token-refresh/                  # Token refresh schedules (NEW)
│   ├── lambda.yaml                 # 3 functions (mcn/app/sec)
│   ├── iam.yaml                    # token-refresh role/policy/attachment
│   └── eventbridge.yaml            # 3 schedules + 3 targets + 3 permissions
│
├── provisioning-workflow/          # Step Functions pipeline (NEW)
│   ├── lambda.yaml                 # 6 functions
│   ├── iam.yaml                    # lambda role, SFN role, stream-to-SFN role
│   ├── step-function.yaml          # state machine (raw Object)
│   └── cloudwatch.yaml             # SFN log group
│
├── deployment-state/               # Deployment state storage
│   └── s3.yaml                     # bucket + lifecycle + encryption + policy + public access
│
├── observability/                  # Log aggregation
│   ├── iam-vector.yaml             # Vector IAM user + key + policy
│   └── s3-global-logs.yaml         # Global logs bucket + configs
│
└── loadgen/                        # Load testing infrastructure
    ├── cluster.yaml                # ECS Fargate cluster + capacity providers
    ├── task-definition.yaml        # Fargate task def (tor + k6 containers)
    ├── iam.yaml                    # execution role, task role, events role
    ├── network.yaml                # security group
    ├── log-group.yaml              # CloudWatch log group
    ├── scheduled-rules.yaml        # EventBridge hourly + peak rules
    ├── ecr.yaml                    # tops-tor + tops-k6 repositories
    ├── s3.yaml                     # loadgen-scripts + loadgen-results buckets
    └── kustomization.yaml          # Kustomize resource list
```

## Naming Conventions

### Resource names
- Pattern: `tops-{domain}-{resource}-v2`
- Examples: `tops-acme-client-mcn-v2`, `tops-cert-mgmt-role-v2`, `tops-provisioning-workflow-v2`

### MCN/App/Sec variant pattern
- `tops-{domain}-mcn-v2`, `tops-{domain}-app-v2`, `tops-{domain}-sec-v2`

### EventBridge
- Rules: `tops-{domain}-schedule-v2` or `tops-{domain}-daily-v2`
- Targets: `tops-{domain}-{function}-target-v2`

### Lambda permissions
- `tops-{domain}-{function}-permission-v2`

### Labels (every resource)
```yaml
labels:
  app.kubernetes.io/name: tops-core-v2
  app.kubernetes.io/component: {service-type}-{descriptor}
```

### Tags (every AWS resource)
```yaml
tags:
  Name: {resource-name}
  Environment: production
  ManagedBy: crossplane
  Application: tops-core
```

### Standard Lambda config
```yaml
region: us-east-1
runtime: python3.11
handler: function.handler
timeout: 60
memorySize: 128
s3Bucket: tops-lambda-bucket-v2
```

### Standard IAM trust policy (Lambda)
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "lambda.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```

## Step Function Approach

The `upbound-provider-aws-sfn` is not currently installed. We will:

1. Add `upbound-provider-aws-sfn` (v1.14.0) to `f5xc-tops-mgmt-cluster/crossplane/providers/aws-providers.yml`
2. Define the state machine as a raw `Object` resource using the SFN provider's `StateMachine` kind (`sfn.aws.upbound.io/v1beta2`)
3. The state machine definition JSON is translated directly from the existing `aws_sfn_state_machine.provisioning_workflow` in `provisioning-workflow.tf`

## ArgoCD Changes

File: `f5xc-tops-mgmt-cluster/argocd/tops-infra-crossplane-app.yml`

Current config excludes `fargate/` subdirectory:
```yaml
directory:
  recurse: true
  exclude: '{fargate/*,fargate/**}'
```

After reorg, `fargate/` no longer exists (becomes `loadgen/`). The Fargate exclusion served a purpose (kustomize conflict with recursive apply). The `loadgen/` directory retains a `kustomization.yaml`, so we need to either:
- Keep an exclusion for `loadgen/` and add a separate ArgoCD app for it, OR
- Remove the `kustomization.yaml` from loadgen and let ArgoCD apply all YAMLs directly via recursive sync

Recommended: Remove `kustomization.yaml` from `loadgen/` and drop the exclusion entirely. ArgoCD recursive sync handles all files.

Updated config:
```yaml
directory:
  recurse: true
```

## Terraform Files

All `.tf` files in `f5xc-tops-infra/` remain untouched. Crossplane manifests create new `v2` resources alongside the existing Terraform-managed resources. Terraform file cleanup is a separate future effort after cutover.

The Terrakube `.tf` files in `f5xc-tops-mgmt-cluster/terraform/terrakube/` are not part of this migration.

## CI/CD

No changes needed. The GitHub Actions workflows in `f5xc-tops-job-workers` upload Lambda ZIPs to `tops-lambda-bucket` (Terraform). The `deploy-green-lambdas.sh` script in `f5xc-tops-infra/scripts/` handles uploading to `tops-lambda-bucket-v2` (Crossplane). Both paths continue to work.

## Implementation Phases

All work on `hive` branch. Commits go to the specific sub-repo where files are modified.

### Phase 1: Reorganize existing manifests

**Repo:** f5xc-tops-infra

Move existing Crossplane files into domain-based structure. No new resources created.

| Source | Destination |
|--------|-------------|
| `s3/buckets.yaml` (deployment-state section) | `deployment-state/s3.yaml` |
| `s3/buckets.yaml` (lambda-bucket section) | `shared/s3-lambda-bucket.yaml` |
| `s3/loadgen-buckets.yaml` | `loadgen/s3.yaml` |
| `dynamodb/tables.yaml` (job-state + deployment-state) | `udf-worker/dynamodb.yaml` |
| `dynamodb/tables.yaml` (lab-config) | `udf-lab-config/dynamodb.yaml` |
| `sqs/queues.yaml` | `udf-dispatch/sqs.yaml` |
| `lambda/functions.yaml` (dispatch) | `udf-dispatch/lambda.yaml` |
| `lambda/functions.yaml` (worker) | `udf-worker/lambda.yaml` |
| `lambda/functions.yaml` (ns-create, ns-remove, user-create, user-remove) | `utility-lambdas/lambda.yaml` |
| `lambda/event-sources.yaml` (SQS trigger) | `udf-dispatch/event-sources.yaml` |
| `lambda/event-sources.yaml` (DynamoDB trigger) | `udf-worker/event-sources.yaml` |
| `iam/lambda-roles.yaml` (base execution role) | `shared/iam.yaml` |
| `iam/lambda-roles.yaml` (worker role) | `udf-worker/iam.yaml` |
| `iam/lambda-roles.yaml` (dispatch role) | `udf-dispatch/iam.yaml` |
| `fargate/cluster.yaml` | `loadgen/cluster.yaml` |
| `fargate/task-definition.yaml` | `loadgen/task-definition.yaml` |
| `fargate/iam.yaml` | `loadgen/iam.yaml` |
| `fargate/network.yaml` | `loadgen/network.yaml` |
| `fargate/log-group.yaml` | `loadgen/log-group.yaml` |
| `fargate/scheduled-rules.yaml` | `loadgen/scheduled-rules.yaml` |
| `fargate/kustomization.yaml` | REMOVED (ArgoCD recursive sync replaces it) |
| `ecr/repositories.yaml` | `loadgen/ecr.yaml` |
| `observability/iam-vector.yaml` | `observability/iam-vector.yaml` (no change) |
| `observability/s3-global-logs.yaml` | `observability/s3-global-logs.yaml` (no change) |

Old directories (`s3/`, `dynamodb/`, `sqs/`, `lambda/`, `iam/`, `fargate/`, `ecr/`) are deleted after move.

**Repo:** f5xc-tops-mgmt-cluster

Update ArgoCD app to remove Fargate exclusion:
- Edit `argocd/tops-infra-crossplane-app.yml`: remove `exclude: '{fargate/*,fargate/**}'`

### Phase 2: Shared + simple domains

**Repo:** f5xc-tops-infra

New files:
- `shared/ssm-parameters.yaml` - SSM Parameter Store entries for mcn_lab, app_lab, sec_lab
- `udf-lab-config/s3-registry.yaml` - lab registry S3 bucket + policy
- `udf-lab-config/data.yaml` - DynamoDB table items + S3 lab info objects
- `udf-cleaner/lambda.yaml` - cleaner Lambda function
- `udf-cleaner/iam.yaml` - cleaner IAM role/policy/attachment
- `udf-cleaner/eventbridge.yaml` - schedule rule + target + Lambda permission
- `udf-helpers/lambda.yaml` - 5 helper Lambda functions
- `udf-helpers/iam.yaml` - helpers IAM role/policy/attachment
- `utility-lambdas/iam.yaml` - dedicated utility Lambda IAM (replaces shared base role usage)

### Phase 3: Tenant-variant domains (MCN/App/Sec)

**Repo:** f5xc-tops-infra

New files:
- `acme-client/lambda.yaml` - 3 ACME Lambda functions
- `acme-client/iam.yaml` - ACME IAM role/policy/attachment
- `acme-client/eventbridge.yaml` - daily trigger rule + 3 targets + 3 permissions
- `cert-mgmt/lambda.yaml` - 3 cert management Lambda functions
- `cert-mgmt/iam.yaml` - cert-mgmt IAM role/policy/attachment
- `cert-mgmt/s3.yaml` - cert S3 bucket + policy + encryption + public access block
- `cert-mgmt/s3-notifications.yaml` - S3 event notification + 3 Lambda permissions
- `token-refresh/lambda.yaml` - 3 token refresh Lambda functions
- `token-refresh/iam.yaml` - token-refresh IAM role/policy/attachment
- `token-refresh/eventbridge.yaml` - 3 schedule rules + 3 targets + 3 permissions

### Phase 4: Provisioning workflow

**Repo:** f5xc-tops-mgmt-cluster

- Add `upbound-provider-aws-sfn` to `crossplane/providers/aws-providers.yml`

**Repo:** f5xc-tops-infra

New files:
- `provisioning-workflow/lambda.yaml` - 6 Lambda functions (fetch_job_config, resource_orchestrator, origin_pool_create, http_lb_create, waf_policy_create, stream_to_stepfunction)
- `provisioning-workflow/iam.yaml` - 3 IAM roles/policies (provisioning Lambda, SFN execution, stream-to-SFN)
- `provisioning-workflow/step-function.yaml` - raw Object StateMachine definition
- `provisioning-workflow/cloudwatch.yaml` - SFN CloudWatch log group
