---
inclusion: always
---

# Discovery and savings rules

You are doing read-only discovery and cost analysis on a live AWS account.

- **Read only.** Never attempt a create, update, delete, start, stop, tag, or put call, even if a tool offers one. If a finding needs a change, write it as a recommendation for a human.
- **Evidence for every finding.** Each savings item must cite where it came from: the tool and API (for example, Compute Optimizer `GetEC2InstanceRecommendations` or Cost Explorer `GetCostAndUsage`), the resource ARN or ID, the time window, and the numbers.
- **Separate what you observed from what you inferred.** Label each finding as either a measured recommendation (from Compute Optimizer, Cost Optimization Hub, or Cost Explorer) or an inference (your own reasoning from metadata or metrics).
- **AWS access only through the MCP servers.** Never run the `aws` CLI, SDK scripts, or any other AWS tooling in the terminal, and never pass `--profile` or read `~/.aws`. The MCP servers use the read-only role; the shell does not.
- **No secrets or data.** Do not try to read object contents, secrets, parameters, or logs. If a call is denied, record the denial and move on; do not look for a workaround.
- **Cost Explorer calls cost money** (about $0.01 per request). Use monthly granularity unless daily is needed, and don't repeat the same query.
- **Output** goes in `reports/` as Markdown:
  - `reports/inventory.md`: accounts, Regions in use, resources by service, and a Mermaid architecture diagram.
  - `reports/savings.md`: a ranked table (finding, resource, estimated monthly savings, source, confidence, effort, risk, and what a human must check before acting).
