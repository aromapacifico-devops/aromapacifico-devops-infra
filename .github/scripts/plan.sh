#!/usr/bin/env bash
# Plans one environment and writes summary.md. The binary plan never leaves the private state bucket.
# usage: plan.sh pr|deploy|destroy|drift
# Needs ENVIRONMENT, NAME_PREFIX and AWS credentials. PR_NUMBER for pr, RUN_KEY for deploy and destroy.
# Writes planned=true|false and changes=true|false to GITHUB_OUTPUT when it exists.
set -euo pipefail

mode=$1
root=$(pwd)
summary=$root/summary.md
bucket=$NAME_PREFIX-$ENVIRONMENT-s3-tfstate
output=${GITHUB_OUTPUT:-/dev/null}
cd "envs/$ENVIRONMENT"

{
  echo "<!-- plan:$ENVIRONMENT -->"
  case "$mode" in
    pr) echo "### Plan of $ENVIRONMENT for this pull request" ;;
    deploy) echo "### Deploy plan of $ENVIRONMENT" ;;
    destroy) echo "### Destroy plan of $ENVIRONMENT" ;;
    drift) echo "### Drift check of $ENVIRONMENT" ;;
  esac
  echo
} > "$summary"

finish() {
  echo "planned=$1" >> "$output"
  echo "changes=$2" >> "$output"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then cat "$summary" >> "$GITHUB_STEP_SUMMARY"; fi
}

terraform init -input=false -no-color > /dev/null

if [ "$mode" = drift ] && [ -z "$(terraform state list -no-color)" ]; then
  echo "The environment is down, so there is nothing to compare." >> "$summary"
  finish false false
  exit 0
fi

# An environment that links its collection centers needs their addresses, which only the providers give.
if grep -Eq '^enable_center_link[[:space:]]*=[[:space:]]*true' terraform.tfvars && [ -z "${CENTER_LINK_IPS:-}" ]; then
  echo "Blocked until the static addresses of the collection centers exist in the variable \`CENTER_LINK_IPS\` of this environment. No address is invented." >> "$summary"
  finish false false
  if [ "$mode" = pr ] || [ "$mode" = drift ]; then exit 0; fi
  echo "::error::$ENVIRONMENT needs CENTER_LINK_IPS before it can be planned"
  exit 1
fi
if [ -n "${CENTER_LINK_IPS:-}" ]; then export TF_VAR_center_link_ips=$CENTER_LINK_IPS; fi

if [ "$mode" = pr ]; then terraform fmt -check -recursive -no-color "$root/envs"; fi
terraform validate -no-color

args=(-input=false -no-color -out=tfplan -detailed-exitcode)
case "$mode" in
  pr | drift) args+=(-lock=false) ;;
  destroy) args+=(-destroy) ;;
esac

set +e
terraform plan "${args[@]}" > plan.log
status=$?
set -e
if [ "$status" -eq 1 ]; then
  cat plan.log
  echo "The plan failed. The log of this job holds the error." >> "$summary"
  finish false false
  exit 1
fi

terraform show -json tfplan > tfplan.json
jq -r '
  [.resource_changes[] | select(.change.actions != ["no-op"] and .change.actions != ["read"])] as $c
  | ($c | map(select(.change.actions == ["create"])) | length) as $add
  | ($c | map(select(.change.actions == ["update"])) | length) as $change
  | ($c | map(select(.change.actions | index("delete"))) | length) as $destroy
  | "`Plan: \($add) to add, \($change) to change, \($destroy) to destroy.`",
    "",
    (if ($c | length) > 0 then
      "<details><summary>Resources</summary>", "", "| Action | Resource |", "|---|---|",
      ($c[] | "| \(.change.actions | join(" then ")) | `\(.address)` |"),
      "", "</details>"
    else empty end)
' tfplan.json >> "$summary"
rm -f tfplan.json

case "$mode" in
  pr)
    key=plans/pr-$PR_NUMBER/$(git rev-parse --short HEAD).tfplan
    aws s3 cp tfplan "s3://$bucket/$key" --only-show-errors
    ;;
  deploy | destroy)
    # The packages built during the plan travel with it, since the apply job does not rebuild them.
    key=plans/$mode/$RUN_KEY.tgz
    files=(tfplan)
    if [ -d .build ]; then files+=(.build); fi
    tar -czf plan.tgz "${files[@]}"
    aws s3 cp plan.tgz "s3://$bucket/$key" --only-show-errors
    ;;
  drift)
    key=""
    ;;
esac
if [ -n "$key" ]; then
  printf '\nThe binary plan stays in the private state bucket of %s as %s.\n' "$ENVIRONMENT" "\`$key\`" >> "$summary"
fi

changes=false
if [ "$status" -eq 2 ]; then changes=true; fi
finish true "$changes"
if [ "$mode" = drift ] && [ "$changes" = true ]; then
  echo "::error::$ENVIRONMENT differs from the code"
  exit 1
fi
