# aromapacifico-devops-infra

Infrastructure repository of the Aroma Pacifico platform. It holds the root configuration of each environment and the pipelines that deploy them. Reusable code lives in versioned module repositories, so this repository only decides which module versions and which values each environment uses.

Each root calls the five modules by exact tag. The modules expose their interface, and resources appear in each environment as the module code is written. The module repositories below declare the interfaces each root connects.

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

Modules are products and this repository is their consumer, so the two stay apart. Each module has its own repository, tests and version.

| Repository | Holds |
|---|---|
| [`terraform-aws-network`](https://github.com/aromapacifico-devops/terraform-aws-network) | VPC, subnets, routes, endpoints and the link to one center |
| [`terraform-aws-security`](https://github.com/aromapacifico-devops/terraform-aws-security) | Platform identities, encryption keys and permanent cloud firewall rules |
| [`terraform-aws-telemetry-ingestion`](https://github.com/aromapacifico-devops/terraform-aws-telemetry-ingestion) | Ingestion path from IoT Core to storage and alerts |
| [`terraform-aws-farm`](https://github.com/aromapacifico-devops/terraform-aws-farm) | Reusable identity of one farm |
| [`terraform-aws-inference-function`](https://github.com/aromapacifico-devops/terraform-aws-inference-function) | Event-driven inference function pattern |
| [`terraform-aws-module-template`](https://github.com/aromapacifico-devops/terraform-aws-module-template) | Skeleton that starts a new module |
| `aromapacifico-devops-infra` | Roots, bootstrap and deployment pipelines |
| [`.github`](https://github.com/aromapacifico-devops/.github) | Organization profile and shared workflows |
| [`aromapacifico-devops-docs`](https://github.com/aromapacifico-devops/aromapacifico-devops-docs) | Architecture and design documents |

## 3. Layout

```text
aromapacifico-devops-infra/
├── bootstrap/                State buckets, Platform keys, OIDC provider, pipeline roles, budget
├── envs/
│   ├── dev/                  Root of development
│   ├── test/                 Root of test
│   └── prod/                 Root of production
├── functions/                Code packaged for the platform functions
├── docs/iac-exceptions.md    Accepted findings, with reason and end condition
└── .github/workflows/        Plan, deploy, destroy, drift and bootstrap workflows
```

Each directory under `envs/` holds `main.tf`, `variables.tf`, `locals.tf`, `outputs.tf`, `providers.tf`, `versions.tf`, `backend.tf`, `terraform.tfvars`, `.terraform.lock.hcl` and `sample-node.csr`. A separate directory per environment lets test and production pin different module versions, which is what makes promotion possible. `backend.tf` points each root to its own state bucket.

Terraform is pinned to the exact version in `.terraform-version`, and every root requires at least that version. The AWS provider stays within one minor release, and the lock files hold its checksums for Linux, macOS and Windows, so a plan resolves the same build on any machine.

A root runs locally with these commands. `terraform init` reads the state bucket, so it needs AWS credentials for the demonstration account, such as a profile created with `aws login`. `terraform init -backend=false` is enough to validate without credentials.

```bash
cd envs/dev
terraform init
terraform validate
terraform plan
```

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
| VPN links and interface endpoints | Off, turned on for a session | Off, turned on for a session | On |
| Linked centers | None, so the ingress subnets admit nothing | Cauca (41) | Cauca (41), Huila (42) and Tolima (43) |
| Destroy removes data | Yes | Yes | Yes in the demonstration, no in the pilot |
| State bucket | `fnc-aroma-dev-s3-tfstate` | `fnc-aroma-test-s3-tfstate` | `fnc-aroma-prod-s3-tfstate` |
| Platform key | `alias/fnc-aroma-dev-kms-platform` | `alias/fnc-aroma-test-kms-platform` | `alias/fnc-aroma-prod-kms-platform` |
| State key | `dev/us-east-1/platform/terraform.tfstate` | `test/us-east-1/platform/terraform.tfstate` | `prod/us-east-1/platform/terraform.tfstate` |
| Pipeline role | Trusts the `dev` GitHub environment | Trusts the `test` GitHub environment | Trusts the protected `prod` GitHub environment |
| Deployment | Pipeline | Pipeline | Pipeline, after a person approves |

Only `terraform.tfvars` changes between environments, and no value in it is a secret or an account identifier. The roots reject a wrong value before any plan.

| Variable | Rejected when |
|---|---|
| `departments` | It is empty, or a code uses characters other than lowercase letters, digits and hyphens |
| `sample_farm` | Its department is outside `departments`, or its node name does not start with `node-<env>-` |
| `vpc_cidr` | It is not a /16 written from its network address, or it falls outside 10.0.0.0/8 or inside 10.41.0.0/16 to 10.49.0.0/16, the ranges of the collection centers |
| `availability_zones` | It lists fewer than one or more than three zones, repeats a zone, or names a zone of another Region |
| `common_tags` | A mandatory tag is missing, `Client`, `Project` or `Environment` differ from the governance variables, `CostCenter` is outside the documented cost centers, or `ManagedBy` is not `Terraform` |
| `client`, `project`, `environment` | They break the code patterns the modules expect |
| `linked_centers` | It holds a value other than 41, 42 or 43, or repeats one |
| `center_link_ips` | It holds an address for a center that is not in `linked_centers`, or `enable_center_link` is true and a center of `linked_centers` has no address. The network module also rejects an address that is not a valid public IPv4 address and a repeated address |

`linked_centers` decides which collection centers the cloud firewall admits, through the logistics range `10.X.3.0/24` and the local server range `10.X.10.0/24` of each one. It defaults to no center. `enable_center_link` and `enable_private_endpoints` default to `false`, and `force_destroy_data` defaults to `false` so that a root without values never deletes data. The environment files set them as the table above shows.

### Link to the collection centers

`enable_center_link` creates the VPN link of the network module, version 1.1.0, for the centers in `linked_centers`. With it `false`, the default, no VPN resource is planned and the network is the one of version 1.0.0. With it `true`, every center in `linked_centers` needs its static public address in `center_link_ips`, keyed by the department code as a string, and the plan fails when one is missing. A center is never skipped, and an address for a center that is not requested is rejected. The addresses come from the provider of each center and no value is invented in this repository.

Production has `enable_center_link = true` with the centers 41, 42 and 43. Its plan therefore stops at the validation of `center_link_ips` until the three addresses are known. That block is expected, and it is not hidden by turning the link off. A demonstration address of the range 203.0.113.0/24 may be passed with `-var` to see the shape of a plan, and it must be named as a demonstration wherever the plan is shown and never applied. The link outputs list the connection, the tunnel addresses, the secret that holds the keys and the routed ranges. No key is an output, and the keys stay in Secrets Manager.

The link carries traffic only. The names that a center uses for IoT Core, S3 and the private API, the port of the IoT Core endpoint and the host that the upload function signs for S3 are open in the design and are outside this root.

### Telemetry ingestion and the sample farm

Each root deploys the telemetry ingestion path with a thing group for each department of the pilot, Cauca, Huila and Tolima, and writes the initial alert ranges once as version 1. Environments share the IoT broker and the thing registry of the account, so each rule listens only to `aroma/<env>/farm/+/+`, and each root holds its own sample farm, whose node is named `node-<env>-00001`. The certificate request of that node is `sample-node.csr`, made with `openssl` on the machine that plays the node, which keeps the private key. The certificate leaves through the `sample_certificate_pem` output and the MQTT endpoint through `iot_data_endpoint`.

`functions/ingestion` stores each reading once and reports the failed messages of a batch. Range evaluation and alerts belong to the platform application, so the delivery status and delivery check functions run `functions/placeholder`, which only logs. The focus confirmation function runs the same placeholder, since the person filter, the model call and the result also belong to the platform application. Each plan zips both folders into `.build/` of the root.

The push platform application holds a credential that SNS checks at creation, so the platform operator creates it with the AWS CLI after the first deployment of an environment, under the name and with the roles that the telemetry ingestion module documents.

Each environment has one root and one state. The modules of an environment reference each other, since endpoints need security groups and security groups need the VPC. Terraform resolves those references per resource inside one root, and the plan of a whole environment works from nothing, even after a destroy.

The state buckets live in bootstrap, so destroying an environment keeps its state history. Each bucket has these protections.

| Protection | How |
|---|---|
| Encryption | The backend writes every object with the platform key of the environment, and the bucket uses the same key by default |
| Locking | A lock file next to the state, `use_lockfile`, so a second run fails while the first holds the lock |
| History | Versioning on, and replaced versions expire after 90 days |
| Access | The bucket policy refuses requests without TLS and any principal other than the pipeline roles of its environment and the account operators. A role of another environment receives an explicit deny |
| Public access | Blocked, with ACLs disabled |

Pipeline roles must be named `fnc-aroma-<env>-role-pipeline-<purpose>`, since the bucket policy recognizes them by that pattern. Bootstrap keeps its own state in `fnc-aroma-shared-s3-tfstate` under `shared/us-east-1/bootstrap/terraform.tfstate`, with a fourth platform key. Every bucket policy also admits the bootstrap role, since bootstrap manages every bucket.

### Pipeline identities

Workflows reach AWS through the one GitHub OIDC provider of the account, with no stored keys. Each role trusts a single GitHub environment of this repository, so a workflow gets a role only when its job runs in that environment.

| Role | Trusted GitHub environment | Permissions | Used by |
|---|---|---|---|
| `fnc-aroma-<env>-role-pipeline-plan` | `plan-<env>`, no reviewers | Read the account, state and saved plans of its environment, decrypt table items through DynamoDB | Plans of pull requests and drift |
| `fnc-aroma-<env>-role-pipeline-apply` | `<env>`. `prod` needs one of the team as reviewer and accepts only `main` | Create and remove the resources of its environment | Deploy, destroy and smoke test |
| `fnc-aroma-shared-role-pipeline-bootstrap` | `shared`, same reviewers and branch rule as `prod` | Create and update the shared resources | Bootstrap workflow |

The trust checks the audience `sts.amazonaws.com` and the full subject of the token. The repository uses the immutable subject format, which carries the owner and repository IDs, so a renamed or recreated repository with the same name cannot assume a role.

```text
repo:aromapacifico-devops@352295207/aromapacifico-devops-infra@1446256508:environment:<name>
```

Plans run in separate `plan-<env>` environments because a job that names `prod` waits for its reviewers, and a plan on every pull request would then wait too.

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
| Deploy | Manually from GitHub, choosing the environment, when work on it starts | Applies, and production needs approval |
| Destroy | Manually from GitHub, choosing the environment, when work on it stops | Removes the environment and keeps bootstrap |
| Drift | On a schedule | Runs a plan and reports differences against the code |

| Use | Cost, USD |
|---|---|
| Test up, per hour | 0.084 |
| Production up, per hour | 0.114 |
| Both up for a work session of 8 hours | 1.58 |
| Both up for 10 sessions of 8 hours | 15.84 |

No destroy runs on a schedule. The person who brought an environment up takes it down when work stops, and the budget that bootstrap creates, with alerts at USD 20 and USD 50, catches an environment left up by mistake. `enable_center_link` and `enable_private_endpoints` turn off the two billed items for sessions that do not need them.

### First bootstrap run

Bootstrap costs about USD 4 a month while it exists, at USD 1 for each of the four platform keys, and the state objects weigh a few kilobytes. IAM roles, the OIDC provider and the budget have no charge. It creates the bucket that holds its own state, so the first run on an empty account starts with local state and then moves it. The budget sends its alerts to an address that never enters a committed file. Pass it through the environment, and the bootstrap workflow reads it from the `BUDGET_ALERT_EMAIL` secret of the `shared` environment.

```bash
export TF_VAR_budget_alert_email=<address>
```

```bash
cd bootstrap
mv backend.tf backend.tf.off
terraform init
terraform apply
mv backend.tf.off backend.tf
terraform init -migrate-state
```

After the move, the local `terraform.tfstate` files can be deleted. Later runs use `terraform init` and `terraform apply` directly.

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
