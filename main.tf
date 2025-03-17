terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Provisioner = "Terraform"
    }
  }
}

locals {
  uuid = uuid()
}

data "aws_iam_policy" "control_tower_service_role_policy" {
  name = "AWSControlTowerServiceRolePolicy"
}

data "aws_iam_policy" "aws_config_role_for_organizations" {
  name = "AWSConfigRoleForOrganizations"
}

resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "controltower.amazonaws.com",
    "member.org.stacksets.cloudformation.amazonaws.com",
    "sso.amazonaws.com",
  ]

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
  ]
}

resource "aws_organizations_account" "logging" {
  name  = "Logging"
  email = "${var.email_account}+logging-${local.uuid}@${var.email_domain}"
}

resource "aws_organizations_account" "security" {
  name  = "Security"
  email = "${var.email_account}+security-${local.uuid}@${var.email_domain}"
}

module "aws_control_tower_admin_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role = true

  role_name         = "AWSControlTowerAdmin"
  role_path         = "/service-role/"
  role_requires_mfa = false

  trusted_role_services = ["controltower.amazonaws.com"]

  custom_role_policy_arns = [
    data.aws_iam_policy.control_tower_service_role_policy.arn
  ]

  inline_policy_statements = [
    {
      actions   = ["ec2:DescribeAvailabilityZones"]
      resources = ["*"]
    }
  ]
}

module "aws_control_tower_stack_set_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role = true

  role_name         = "AWSControlTowerStackSetRole"
  role_path         = "/service-role/"
  role_requires_mfa = false

  trusted_role_services = ["cloudformation.amazonaws.com"]

  inline_policy_statements = [
    {
      actions   = ["sts:AssumeRole"]
      resources = ["arn:aws:iam::*:role/AWSControlTowerExecution"]
    }
  ]
}

module "aws_control_tower_cloud_trail_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role = true

  role_name         = "AWSControlTowerCloudTrailRole"
  role_path         = "/service-role/"
  role_requires_mfa = false

  trusted_role_services = ["cloudtrail.amazonaws.com"]

  inline_policy_statements = [
    {
      actions   = ["logs:CreateLogStream"]
      resources = ["arn:aws:logs:*:*:log-group:aws-controltower/CloudTrailLogs:*"]
    },
    {
      actions   = ["logs:PutLogEvents"]
      resources = ["arn:aws:logs:*:*:log-group:aws-controltower/CloudTrailLogs:*"]
    }
  ]
}

module "aws_control_tower_config_aggregator_role_for_organizations_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role = true

  role_name         = "AWSControlTowerConfigAggregatorRoleForOrganizations"
  role_path         = "/service-role/"
  role_requires_mfa = false

  trusted_role_services = ["config.amazonaws.com"]

  custom_role_policy_arns = [
    data.aws_iam_policy.aws_config_role_for_organizations.arn
  ]
}

resource "aws_controltower_landing_zone" "this" {
  manifest_json = jsonencode(yamldecode(templatefile("${path.module}/files/manifest.yaml", {
    logging_account_id  = aws_organizations_account.logging.id,
    security_account_id = aws_organizations_account.security.id,
  })))
  version = "3.3"
}
