#!/usr/bin/env bash
# Publishes one simulated reading of the sample node and waits for it in the readings table.
# usage: smoke-test.sh. Needs ENVIRONMENT, NAME_PREFIX and AWS credentials, after an apply.
set -euo pipefail

cd "envs/$ENVIRONMENT"
node=$(terraform output -raw sample_thing_name)
endpoint=$(terraform output -raw iot_data_endpoint)
table=$NAME_PREFIX-$ENVIRONMENT-ddb-readings
measured_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
seq=${GITHUB_RUN_ID:-$(date +%s)}
seq=$((seq % 2000000000))

payload=$(jq -cn --arg node "$node" --arg at "$measured_at" --argjson seq "$seq" '{
  schema: 1, node_id: $node, seq: $seq, measured_at: $at, stream: "crop", buffered: false, dropped_total: 0,
  values: {ph: 5.3, soil_humidity_pct: 61.0, air_temp_c: 21.2}
}')
aws iot-data publish --endpoint-url "https://$endpoint" --topic "aroma/$ENVIRONMENT/farm/$node/crop" \
  --cli-binary-format raw-in-base64-out --payload "$payload"
echo "Published reading $seq of $node at $measured_at."

key=$(jq -cn --arg node "$node" --arg sk "$measured_at#$seq" '{node_id: {S: $node}, sk: {S: $sk}}')
for attempt in $(seq 1 24); do
  found=$(aws dynamodb get-item --table-name "$table" --key "$key" --query 'Item.sk.S' --output text)
  if [ "$found" = "$measured_at#$seq" ]; then
    echo "Reading found in $table after about $((attempt * 5)) seconds."
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
      echo "Smoke test passed. Reading \`$measured_at#$seq\` of \`$node\` reached \`$table\`." >> "$GITHUB_STEP_SUMMARY"
    fi
    exit 0
  fi
  sleep 5
done
echo "::error::the simulated reading did not reach $table in 2 minutes"
exit 1
