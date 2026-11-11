# Verification of the infrastructure code

This document records the evidence that the infrastructure code of the platform works as designed. It covers a full plan and apply of one environment, the smoke test that sends a reading through the deployed ingestion path, the check of each box of the implementation scope against the code that builds it, the search for secrets, and the parts that remain unproven. The hours spent on the code are in section 10 of the [README](../README.md).

## Contents

1. Terms
2. Summary
3. Plan and apply of the test environment
4. Smoke test
5. A second plan on a running environment
6. Each box and the code that builds it
7. Secrets
8. Cross review
9. What remains unproven

## 1. Terms

| Term | Meaning |
|---|---|
| Box | One of the ten parts, C01 to C10, that page 02 of the architecture diagram marks as built by the infrastructure code |
| Plan | The list of changes Terraform would make to bring an environment to the code |
| Smoke test | A short check after a deployment that one simulated reading travels from IoT Core to the readings table |
| Drift | A difference between a running environment and the code |
| State | Terraform's record of what it created in an environment, kept in the private state bucket of that environment |

## 2. Summary

| Check | Result |
|---|---|
| Plan of one environment | Test planned and applied from `main` through the deploy workflow, 127 resources added |
| Smoke test in test | A simulated reading of `node-test-00001` reached `fnc-aroma-test-ddb-readings` after about 10 seconds |
| Plan of a running environment | 0 to add, 0 to change, 0 to destroy in test, and the drift workflow passed in dev, test and prod |
| Each box has its code | C01 to C10 each map to a root, bootstrap, a module or a workflow. C04 is planned with a demonstration address and stays off in test |
| Format and validation | `terraform fmt -check` and `terraform validate` pass in the three roots on every pull request |
| Secrets | No secret resource and no private key in the state of test, and the secret scan of the repository history passes |
| Cross review | One of 35 merged pull requests in this repository and the five module repositories carries a recorded approval |
| Teardown | Test destroyed through the destroy workflow, 127 resources removed, and its state is empty |

## 3. Plan and apply of the test environment

The deploy workflow planned test from `main` with the plan role of test and stored the binary plan in the state bucket of test. A second job then applied that exact plan with the apply role of test. The plan held only creations, since test was down before the run.

```text
Apply complete! Resources: 127 added, 0 changed, 0 destroyed.
```

| Module | Resources in test | Version |
|---|---|---|
| Telemetry ingestion | 46 | `v1.0.1` |
| Security | 37 | `v0.6.0` |
| Network | 20 | `v1.1.0` |
| Inference function | 19 | `v1.0.0` |
| Farm | 5 | `v1.0.0` |
| Total | 127 | |

Development and production are planned on every pull request. Development plans in full. Production stops at the check that asks for the static public addresses of the three collection center links, since no address is invented in the code, and the plan job reports that block and passes.

## 4. Smoke test

After the apply, the deploy workflow ran `.github/scripts/smoke-test.sh`. It publishes one reading of the sample node to `aroma/test/farm/node-test-00001/crop` through the IoT data endpoint over HTTPS, then reads the readings table every 5 seconds for up to 2 minutes.

```text
Published reading 1092725645 of node-test-00001 at <measured time>.
Reading found in fnc-aroma-test-ddb-readings after about 10 seconds.
```

The reading went through the IoT rule of test, the ingestion queue and the ingestion function before it reached the table. The publish uses the apply role, so the test proves the path from the broker onward and leaves the device certificate out.

## 5. A second plan on a running environment

With test still running, a pull request planned test again. A plan that finds changes right after an apply means some resource never settles, and every later run would try to change it.

```text
Plan: 0 to add, 0 to change, 0 to destroy.
```

The drift workflow ran on the three environments at the same moment and passed in each. Test was the only one running, so dev and prod reported that they were down.

## 6. Each box and the code that builds it

| Box | Name | Built by | What test holds |
|---|---|---|---|
| C01 | Repository, root and environments | `envs/dev`, `envs/test`, `envs/prod` | One root per environment with its own state |
| C02 | Remote state | `bootstrap/` | State bucket and Platform key of each environment, used by every run above |
| C03 | VPC, subnets and routes | `terraform-aws-network` | 1 VPC, 7 subnets, 2 route tables, 7 associations, 2 gateway endpoints |
| C04 | Link to one collection center | `terraform-aws-network` | Off in test. With the link on and one demonstration address, the plan of test adds 7 resources, a virtual private gateway, a customer gateway, a VPN connection, 2 static routes of the connection and 2 routes toward the center |
| C05 | Platform identities and encryption | `terraform-aws-security`, and `bootstrap/` for the pipeline roles | 9 roles with their policies, 2 KMS keys with their aliases |
| C06 | Permanent cloud firewall rules | `terraform-aws-security`, and the default security group in `terraform-aws-network` | 2 network ACLs with 4 rules, and the default security group of the VPC closed |
| C07 | Telemetry ingestion pattern | `terraform-aws-telemetry-ingestion` | 46 resources, from the IoT rule to the readings table, archive and alert delivery |
| C08 | Inference function pattern | `terraform-aws-inference-function` | 19 resources, the platform bus, rule, work queue, dead letter queue, function, bucket, case table and two alarms |
| C09 | Pipeline, approval and evidence | `.github/workflows/` and the shared workflows of the organization | The deploy, destroy, drift and pull request plan runs that produced this evidence |
| C10 | Reusable module of one farm | `terraform-aws-farm` | 5 resources, the sample node with its certificate, its attachments and its department group membership |

Each module README names its box and lists its inputs and outputs.

The security groups of the interface endpoints and the VPN link belong to C06 too, and they appear only when `enable_private_endpoints` or `enable_center_link` is on. Both stay off in test to avoid their hourly charge.

## 7. Secrets

| Where | How it was checked | Result |
|---|---|---|
| Repository history | The secret scan of the shared checks on each pull request, and push protection on the repository | Passes |
| State of test | Every attribute whose name holds a key, password, token or preshared value, every private key block and every secret resource type | None found |
| Pipeline | Roles assumed through OIDC, with account identifiers kept as variables of each GitHub environment | No stored AWS key |
| Plans | Binary plans stay in the private state bucket, and pull request comments list resource addresses with no attribute values | No value published |

The certificate request of the sample node is committed, and its private key stays on the machine that plays the node. With the center link on, AWS keeps the tunnel keys in Secrets Manager and the state holds only the reference.

## 8. Cross review

The working rule asks for a cross review on each pull request. The ruleset `main` of each repository requires a pull request and no approval, so nothing enforces the rule. Of 35 merged pull requests in this repository and the five module repositories, one carries a recorded approval.

To close this gap, the ruleset `main` of each repository would require one approval from a person other than the author. The team of five can meet that rule, and every change would then wait for a second person.

## 9. What remains unproven

| Item | Why | What proves it |
|---|---|---|
| Production apply | The static addresses of the three center links are unknown | A plan and apply once the providers give the addresses |
| The center link applied | It costs per hour and needs a real address at the center | An apply in test with the address of one center and a tunnel that comes up |
| A device publishing with its certificate | The node keys of earlier live tests were local and are gone | A new `sample-node.csr`, its certificate on a device and one reading through MQTT |
| Application functions | Range evaluation, alert delivery and focus confirmation run placeholder code | The application repositories and their pipelines |
| The push platform application | AWS checks its credential at creation, so the operator creates it after the first deployment | Creation with the CLI once a Firebase project exists |

The test run lasted about ten minutes from apply to destroy, at the hourly cost of test, USD 0.084, which comes to about USD 0.01.
