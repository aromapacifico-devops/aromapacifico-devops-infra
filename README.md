# aromapacifico-devops-infra

Infrastructure repository of the Aroma Pacifico platform. It holds the root configuration of each environment and the pipelines that deploy them. Reusable code lives in versioned module repositories, so this repository only decides which module versions and which values each environment uses.

This repository holds the project definition, and its code arrives with the first implementation work. The module repositories below declare the interfaces each root connects.

## Contents

1. Terms
2. Repositories
3. Layout
4. What each box of the architecture becomes
5. Environments and state
6. From a change to production
7. Bringing an environment up and down
8. Checks on each pull request
9. Conventions

## 1. Terms

| Term | Meaning |
|---|---|
| Module | Reusable Terraform code with inputs and outputs. It has no state and knows no account |
| Root | The directory where `terraform plan` and `terraform apply` run. It sets the provider and the backend and calls the modules |
| State | Terraform's record of what it created. It lives in S3, encrypted and locked, with one state per environment |
| Bootstrap | The small set of resources created once, which everything else depends on |
| Promotion | Moving the same module version to the next environment |

## 2. Repositories

Modules are products and this repository is their consumer, so the two stay apart. Each module has its own repository, owner, tests and version.

| Repository | Holds | Maintainer |
|---|---|---|
| [`terraform-aws-network`](https://github.com/aromapacifico-devops/terraform-aws-network) | VPC, subnets, routes, endpoints and the link to one center | Isabella Hernández |
| [`terraform-aws-security`](https://github.com/aromapacifico-devops/terraform-aws-security) | Platform identities, encryption keys and permanent cloud firewall rules | Santiago Valencia |
| [`terraform-aws-telemetry-ingestion`](https://github.com/aromapacifico-devops/terraform-aws-telemetry-ingestion) | Ingestion path from IoT Core to storage and alerts | Juan Camilo Melo |
| [`terraform-aws-farm`](https://github.com/aromapacifico-devops/terraform-aws-farm) | Reusable identity of one farm | Juan Camilo Melo |
| [`terraform-aws-inference-function`](https://github.com/aromapacifico-devops/terraform-aws-inference-function) | Event-driven inference function pattern | Juan Pablo |
| [`terraform-aws-module-template`](https://github.com/aromapacifico-devops/terraform-aws-module-template) | Skeleton that starts a new module | Daniel Mejía |
| `aromapacifico-devops-infra` | Roots, bootstrap and deployment pipelines | Daniel Mejía |
| [`.github`](https://github.com/aromapacifico-devops/.github) | Organization profile and shared workflows | Juan Pablo |
| [`aromapacifico-devops-docs`](https://github.com/aromapacifico-devops/aromapacifico-devops-docs) | Architecture and design documents | Team |

## 3. Layout

```text
aromapacifico-devops-infra/
├── bootstrap/                State buckets, Platform keys, OIDC provider, pipeline roles, budget
├── envs/
│   ├── dev/                  Root of development
│   ├── test/                 Root of test
│   └── prod/                 Root of production
├── docs/iac-exceptions.md    Findings the team accepts, with reason and end condition
└── .github/workflows/        Plan, deploy, destroy, drift and bootstrap workflows
```

Each directory under `envs/` holds `main.tf`, `variables.tf`, `locals.tf`, `outputs.tf`, `providers.tf`, `versions.tf`, `backend.tf`, `terraform.tfvars` and `.terraform.lock.hcl`. A separate directory per environment lets test and production pin different module versions, which is what makes promotion possible.

Nothing in this repository stores a secret. Account identifiers and role ARNs reach the pipeline as variables of each GitHub environment.

## 4. What each box of the architecture becomes

| Box | Name | Where it lives |
|---|---|---|
| C01 | Repository, root and environments | `envs/` |
| C02 | Remote state | `bootstrap/` |
| C03 | VPC, subnets and routes | `terraform-aws-network` |
| C04 | Link to one collection center | `terraform-aws-network` |
| C05 | Platform identities and encryption | `terraform-aws-security`, and `bootstrap/` for the pipeline roles and the Platform key |
| C06 | Permanent cloud firewall rules | `terraform-aws-security` |
| C07 | Telemetry ingestion pattern | `terraform-aws-telemetry-ingestion` |
| C08 | Inference function pattern | `terraform-aws-inference-function` |
| C09 | Pipeline, approval and evidence | `.github/workflows/` and shared workflows in `.github` |
| C10 | Reusable module of one farm | `terraform-aws-farm` |

## 5. Environments and state

The target design gives each environment its own account inside a seven-account organization. The demonstration runs on one AWS account with environments separated by name, address range, state and pipeline role.

| | Development | Test | Production |
|---|---|---|---|
| Range | 10.50.0.0/16 | 10.60.0.0/16 | 10.70.0.0/16 |
| Availability zones | One | One | Two |
| State bucket | Own bucket | Own bucket | Own bucket |
| State key | `dev/us-east-1/platform/terraform.tfstate` | `test/us-east-1/platform/terraform.tfstate` | `prod/us-east-1/platform/terraform.tfstate` |
| Pipeline role | Trusts the `dev` GitHub environment | Trusts the `test` GitHub environment | Trusts the protected `prod` GitHub environment |
| Deployment | Pipeline | Pipeline | Pipeline, after a person approves |

Each environment has one root and one state. The modules of an environment reference each other, since endpoints need security groups and security groups need the VPC. Terraform resolves those references per resource inside one root, and the plan of a whole environment works from nothing, even after a destroy. Locking uses the native S3 lock file.

## 6. From a change to production

1. A pull request in a module repository passes its checks and a cross review.
2. The merge publishes a new `vX.Y.Z` tag.
3. A pull request here updates the `ref` of that module in `envs/test`, and the plan appears in the pull request.
4. After the merge, the pipeline applies test and runs the smoke test, which publishes a simulated reading and checks that it reaches DynamoDB.
5. A pull request updates the `ref` in `envs/prod`.
6. The pipeline produces the production plan, a named person reads and approves it, and the pipeline applies exactly that plan.

Going back means pointing the environment to the previous tag and running the same pipeline. Data does not roll back with the code, so a change that alters a table needs its own plan.

Modules are always consumed through an exact tag.

```hcl
module "network" {
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-network.git?ref=v1.0.0"
  # ...
}
```

The repository is public, and a saved plan file can hold sensitive values. The binary plan therefore stays in the private state bucket, and only a readable summary reaches the pull request.

## 7. Bringing an environment up and down

Serverless resources cost almost nothing while idle, so the money goes to the VPN and the interface endpoints. Environments exist while someone works on them.

| Workflow | Starts | What it does |
|---|---|---|
| Bootstrap | Once, by hand | Creates what the rest depends on, and is never destroyed |
| Plan | Each pull request | Shows the changes |
| Deploy | Manually, choosing the environment | Applies, and production needs approval |
| Destroy | Manually, and each night for every environment | Removes the environment and keeps bootstrap |
| Drift | On a schedule | Runs a plan and reports differences against the code |

| Use | Cost, USD |
|---|---|
| Test up, per hour | 0.084 |
| Production up, per hour | 0.114 |
| Both up for a work session of 8 hours | 1.58 |
| Both up for 10 sessions of 8 hours | 15.84 |

`enable_center_link` and `enable_private_endpoints` turn off the two billed items for sessions that do not need them. Bootstrap also creates a budget with alerts at USD 20 and USD 50.

## 8. Checks on each pull request

| Check | What it protects |
|---|---|
| `terraform fmt` and `terraform validate` | Format and syntax |
| `terraform test` | Behaviour of each module, with a mocked provider and no cost |
| TFLint | Provider errors and code conventions |
| Project rule check | File layout, governance inputs and the `vX.Y.Z` format of each `source` |
| Checkov | Insecure configuration, and it fails on critical findings |
| gitleaks and GitHub push protection | Secrets in commits |
| zizmor and actionlint | Security and correctness of the workflows |
| Pull request title check | Conventional Commits, which release versions depend on |
| Infracost | Cost difference of the change, for the resources it can price |
| Dependabot | Weekly update proposals for providers, modules and actions |

Third-party actions are pinned to a full commit SHA, and tools install by exact version with a verified checksum.

## 9. Conventions

| Subject | Convention |
|---|---|
| Resource names | `{client}-{project}-{environment}-{type}-{key}`, for example `fnc-aroma-test-vpc-main` |
| Tags | `Client`, `Project`, `Environment`, `Owner`, `CostCenter` and `ManagedBy`, applied by the provider |
| Branches | Short lived, from `main` |
| Commits | Conventional Commits |
| Reviews | Each pull request needs a cross review |

The [architecture documents](https://github.com/aromapacifico-devops/aromapacifico-devops-docs/tree/main/docs/architecture) explain the implementation scope, the environments and the design behind each module.
