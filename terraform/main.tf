# Read-only role for an AI agent doing discovery and cost analysis.
#
# Three layers:
#   1. ViewOnlyAccess (AWS managed): list/describe metadata across services,
#      without the data reads that ReadOnlyAccess includes (s3:GetObject, etc.).
#   2. A scoped cost policy: only the Get/List/Describe calls the Billing and
#      Cost Management MCP server needs. No ce:* wildcards, no Start* calls,
#      and none of the Storage Lens writes the server's README lists.
#   3. An explicit deny on data-plane reads, so a future managed-policy update
#      or a stray attachment can't quietly hand the agent secrets or objects.
#
# Writes are never allowed, so they are implicitly denied everywhere.

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AllowNamedPrincipals"
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:SetSourceIdentity"]

    principals {
      type        = "AWS"
      identifiers = var.trusted_principal_arns
    }

    dynamic "condition" {
      for_each = var.external_id == "" ? [] : [var.external_id]
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [condition.value]
      }
    }
  }
}

resource "aws_iam_role" "discovery" {
  name                 = var.role_name
  description          = "Read-only discovery and cost analysis for AI agents via MCP"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = var.max_session_hours * 3600
}

resource "aws_iam_role_policy_attachment" "view_only" {
  role       = aws_iam_role.discovery.name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

data "aws_iam_policy_document" "cost_read" {
  statement {
    sid    = "CostExplorerRead"
    effect = "Allow"
    actions = [
      "ce:GetCostAndUsage",
      "ce:GetCostAndUsageWithResources",
      "ce:GetCostAndUsageComparisons",
      "ce:GetCostComparisonDrivers",
      "ce:GetCostForecast",
      "ce:GetUsageForecast",
      "ce:GetDimensionValues",
      "ce:GetTags",
      "ce:GetCostCategories",
      "ce:GetAnomalies",
      "ce:GetReservationCoverage",
      "ce:GetReservationUtilization",
      "ce:GetReservationPurchaseRecommendation",
      "ce:GetSavingsPlansCoverage",
      "ce:GetSavingsPlansUtilization",
      "ce:GetSavingsPlansUtilizationDetails",
      "ce:GetSavingsPlansPurchaseRecommendation",
      "ce:GetSavingsPlanPurchaseRecommendationDetails",
      "ce:ListCostAllocationTags",
      "ce:ListCostCategoryDefinitions",
      "ce:DescribeCostCategoryDefinition",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "OptimizationRecommendationsRead"
    effect = "Allow"
    actions = [
      "cost-optimization-hub:GetRecommendation",
      "cost-optimization-hub:ListRecommendations",
      "cost-optimization-hub:ListRecommendationSummaries",
      "cost-optimization-hub:ListEnrollmentStatuses",
      "cost-optimization-hub:GetPreferences",
      "compute-optimizer:GetEnrollmentStatus",
      "compute-optimizer:GetEC2InstanceRecommendations",
      "compute-optimizer:GetEBSVolumeRecommendations",
      "compute-optimizer:GetAutoScalingGroupRecommendations",
      "compute-optimizer:GetECSServiceRecommendations",
      "compute-optimizer:GetRDSDatabaseRecommendations",
      "compute-optimizer:GetLambdaFunctionRecommendations",
      "compute-optimizer:GetIdleRecommendations",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CommitmentsBudgetsPricingRead"
    effect = "Allow"
    actions = [
      "savingsplans:DescribeSavingsPlans",
      "savingsplans:DescribeSavingsPlanRates",
      "savingsplans:DescribeSavingsPlansOfferings",
      "savingsplans:DescribeSavingsPlansOfferingRates",
      "budgets:ViewBudget",
      "budgets:DescribeBudgetActionsForBudget",
      "budgets:DescribeBudgetActionsForAccount",
      "pricing:DescribeServices",
      "pricing:GetAttributeValues",
      "pricing:GetProducts",
      "freetier:GetFreeTierUsage",
    ]
    resources = ["*"]
  }

  # Utilization evidence for "is this actually idle?" questions.
  statement {
    sid    = "UtilizationMetricsRead"
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "tag:GetResources",
    ]
    resources = ["*"]
  }

  # Metadata that ViewOnlyAccess doesn't cover, found missing on the first
  # discovery run. Names and settings only: the deny below still blocks
  # secretsmanager:GetSecretValue and s3:GetObject.
  statement {
    sid    = "DiscoveryMetadataRead"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "secretsmanager:ListSecrets",
      "cloudwatch:DescribeAlarms",
      "amplify:ListApps",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "cost_read" {
  name   = "cost-read"
  role   = aws_iam_role.discovery.id
  policy = data.aws_iam_policy_document.cost_read.json
}

data "aws_iam_policy_document" "deny_data_plane" {
  statement {
    sid    = "DenyDataPlaneReads"
    effect = "Deny"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "secretsmanager:GetSecretValue",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "kms:Decrypt",
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
      "logs:StartQuery",
      "lambda:GetFunction",
      "ec2:GetPasswordData",
      "ec2:GetConsoleOutput",
      "rds-data:*",
      "sqs:ReceiveMessage",
      "kinesis:GetRecords",
      "athena:GetQueryResults",
      "glue:GetConnection",
      "glue:GetConnections",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "deny_data_plane" {
  name   = "deny-data-plane"
  role   = aws_iam_role.discovery.id
  policy = data.aws_iam_policy_document.deny_data_plane.json
}
