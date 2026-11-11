# Infrastructure code exceptions

A finding of the automated checks is accepted only through a row in this table and a `checkov:skip` comment inside the resource, added in a reviewed pull request. Each row states why the finding is acceptable and the condition that ends the exception.

| Rule | Path | Resource | Reason | Expires when |
|---|---|---|---|---|
| CKV_TF_1, module source by commit hash | `envs/*/main.tf` | Every module call | Modules are consumed by exact `vX.Y.Z` tag, and the `release-tags` ruleset of each module repository forbids moving or deleting a tag, so a tag points to one commit forever | A module repository loses that ruleset |
| CKV2_AWS_62, S3 event notifications | `bootstrap/main.tf` | State buckets | Only Terraform reads and writes the state, and no process reacts to a new state object | A process needs to react to state changes |
| CKV_AWS_18, S3 access logging | `bootstrap/main.tf` | State buckets | The bucket policy admits only the pipeline roles of its environment and the account operators, and versioning keeps every state version. Server access logs would add a log bucket per environment and arrive on a best-effort basis | An audit requirement covers reads of the state |
| CKV_AWS_144, cross-Region replication | `bootstrap/main.tf` | State buckets | Versioning keeps 90 days of state history in one Region, and the environments can be rebuilt from the code | A recovery objective requires the state in a second Region |
