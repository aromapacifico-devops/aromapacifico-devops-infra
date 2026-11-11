#!/usr/bin/env bash
# Prices the saved plan of one environment with Infracost and comments the result on the pull request.
# It fails when the key is missing or when Infracost returns no monthly figure.
# Needs ENVIRONMENT, PR_NUMBER, GITHUB_REPOSITORY, GH_TOKEN and INFRACOST_API_KEY, after plan.sh pr.
set -euo pipefail

if [ -z "${INFRACOST_API_KEY:-}" ]; then
  echo "::error::the repository secret INFRACOST_API_KEY is missing, so the plan has no cost"
  exit 1
fi

cd "envs/$ENVIRONMENT"
terraform show -json tfplan > tfplan.json
infracost breakdown --path tfplan.json --format json --out-file infracost.json --project-name "$ENVIRONMENT" --no-color
rm -f tfplan.json

total=$(jq -r '.totalMonthlyCost // empty' infracost.json)
if [ -z "$total" ]; then
  echo "::error::Infracost returned no monthly cost for $ENVIRONMENT"
  exit 1
fi

infracost comment github --path infracost.json --repo "$GITHUB_REPOSITORY" --pull-request "$PR_NUMBER" \
  --github-token "$GH_TOKEN" --behavior update --tag "infracost-$ENVIRONMENT"
echo "Monthly cost of $ENVIRONMENT after this change, USD $total."
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "Infracost monthly cost of $ENVIRONMENT, USD $total, for the resources it can price." >> "$GITHUB_STEP_SUMMARY"
fi
