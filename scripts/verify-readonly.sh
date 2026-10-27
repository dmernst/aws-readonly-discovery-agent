#!/usr/bin/env bash
# Prove the agent stayed read-only: list every CloudTrail management event made
# by the discovery role session in the last N hours and flag any write.
#
# Usage: scripts/verify-readonly.sh [hours] [session-name] [regions...]
# The line that matters is writes_succeeded=0. A denied write attempt still
# counts as a write in CloudTrail, so it is listed separately.
# Set ADMIN_USER=<iam-user> to also list calls made directly by that user in the
# same window (to prove the agent never used the shell with admin credentials).
# Needs: AWS CLI v2 and jq, run with a profile that can call cloudtrail:LookupEvents.
# Note: LookupEvents is per Region, and events can take up to ~15 minutes to appear.
set -euo pipefail

HOURS="${1:-6}"
SESSION="${2:-kiro-discovery}"
if [ "$#" -gt 2 ]; then
  REGIONS=("${@:3}")
else
  REGIONS=("us-east-1")
fi

START="$(date -u -v-"${HOURS}"H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "-${HOURS} hours" +%Y-%m-%dT%H:%M:%SZ)"

for region in "${REGIONS[@]}"; do
  echo "== ${region} (since ${START}, session ${SESSION})"
  aws cloudtrail lookup-events \
    --region "${region}" \
    --start-time "${START}" \
    --lookup-attributes AttributeKey=Username,AttributeValue="${SESSION}" \
    --query 'Events[].CloudTrailEvent' --output json \
  | jq -r '.[] | fromjson
      | [.eventTime, .eventSource, .eventName, (.readOnly|tostring), (.errorCode // "-"), (.sourceIPAddress // "-")]
      | @tsv' \
  | sort \
  | tee "/tmp/verify-${region}.tsv" \
  | awk -F'\t' '
      { total++ }
      # The AWS MCP Server logs each tool invocation as its own non-read-only
      # event (CallReadWriteTool for aws___run_script). Those are not changes to
      # the account; the API calls the tool made are logged separately.
      $2 == "aws-mcp.amazonaws.com" { mcp++; next }
      $4 == "false" && $5 == "-" { writes_ok++; print "WRITE SUCCEEDED: " $0; next }
      $4 == "false"              { writes_denied++; print "write denied:    " $0; next }
      $5 != "-"                  { reads_denied++ }
      END { printf "events=%d mcp_tool_events=%d writes_succeeded=%d writes_denied=%d reads_denied=%d\n",
                   total, mcp, writes_ok, writes_denied, reads_denied }'
done

if [ -n "${ADMIN_USER:-}" ]; then
  echo "== calls by IAM user ${ADMIN_USER} (us-east-1, same window): check none came from the agent's shell"
  aws cloudtrail lookup-events \
    --region us-east-1 \
    --start-time "${START}" \
    --lookup-attributes AttributeKey=Username,AttributeValue="${ADMIN_USER}" \
    --query 'Events[].[EventTime,EventSource,EventName]' --output text | sort
fi
