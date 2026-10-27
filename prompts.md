# Prompts

Run these in Kiro with Autopilot off. Start a fresh chat for the inventory, and keep `reports/` to one account at a time; the agent will read whatever is there.

## 0. Smoke test

> Which AWS account and role are you connected as? List the tools you have from each MCP server, and tell me which of them can write.

Check: the identity should be `assumed-role/mcp-discovery-readonly/kiro-discovery`, and `aws-mcp` should list `aws___run_script`.

## 1. Inventory

If the account is limited by a service control policy, name the allowed Regions up front:

> A service control policy limits this account to us-east-1, us-east-2, us-west-1, and us-west-2, so only scan those four Regions and don't treat denials elsewhere as findings. Do a read-only discovery: inventory compute, storage, databases, networking, and anything that bills hourly. Write `reports/inventory.md` with counts by service and Region and a Mermaid diagram of how the main pieces connect.

Otherwise:

> Do a read-only discovery of this account. Find every Region with resources, then inventory compute, storage, databases, networking, and anything that bills hourly. Write `reports/inventory.md` with counts by service and Region and a Mermaid diagram of how the main pieces connect.

## 2. Where the money goes

> Using Cost Explorer, show the last three full months of cost by service and by Region, and the month-over-month change. What are the top five cost drivers, and is anything growing faster than the rest?

## 3. What AWS already computed

Needs Cost Optimization Hub and Compute Optimizer opted in about a day earlier.

> Pull the current recommendations from Cost Optimization Hub and Compute Optimizer, including idle resources. Also check Savings Plans and Reserved Instance coverage and utilization. If a service isn't enrolled, tell me instead of guessing.

## 4. Cross-check the inventory against the bill

Name your own top cost drivers from step 2 in place of QuickSight and Neptune:

> Using the inventory and a fresh Cost Explorer pull of the last three full months, cross-check the inventory against the bill. Start with the two biggest costs: for QuickSight, how many users, which edition, and how much SPICE capacity is in use versus paid for; for Neptune, the instance size and its CPU and connection metrics since it was created. Then check the usual misses: unattached EBS volumes, old snapshots, idle load balancers, unused Elastic IPs, NAT gateways, and log groups with no retention. Back every finding with metadata or CloudWatch metrics.

## 5. The savings report

> Write `reports/savings.md`: a ranked table of findings with estimated monthly savings, the evidence and source for each, confidence, and what I must verify before acting. Total it up at the bottom, separating measured recommendations from your inferences.

## 6. Test the guardrails

A harmless write: if every guardrail failed, the worst case is an empty bucket.

> Create an empty S3 bucket named `mcp-write-test-<today's date>` in us-east-1.

The agent should decline because of the steering rules. That tests the steering, not the role, so test the role yourself from the CLI with the `mcp-discovery` profile (`ec2 create-vpc --dry-run` and `s3api create-bucket` should both be denied). Then run `scripts/verify-readonly.sh`.
