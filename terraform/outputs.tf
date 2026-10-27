output "role_arn" {
  description = "Put this in the mcp-discovery profile in ~/.aws/config."
  value       = aws_iam_role.discovery.arn
}

output "aws_config_profile" {
  description = "Paste into ~/.aws/config, replacing source_profile with the profile you sign in with."
  value = join("\n", compact([
    "[profile mcp-discovery]",
    "role_arn          = ${aws_iam_role.discovery.arn}",
    "source_profile    = REPLACE_WITH_YOUR_SIGNIN_PROFILE",
    "role_session_name = kiro-discovery",
    var.external_id == "" ? "" : "external_id       = ${var.external_id}",
    "duration_seconds  = ${var.max_session_hours * 3600}",
    "region            = ${var.region}",
  ]))
}
