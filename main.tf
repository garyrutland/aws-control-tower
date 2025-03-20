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

data "aws_iam_policy_document" "aws_service_role_for_organizations_trust_policy" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["organizations.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy" "aws_organizations_service_trust_policy" {
  name = "AWSOrganizationsServiceTrustPolicy"
}

module "aws_service_role_for_organizations" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role = true

  role_name         = "AWSServiceRoleForOrganizations"
  role_path         = "/aws-service-role/organizations.amazonaws.com/"
  role_requires_mfa = false

  create_custom_role_trust_policy = true
  custom_role_trust_policy        = data.aws_iam_policy_document.aws_service_role_for_organizations_trust_policy.json

  custom_role_policy_arns = [
    data.aws_iam_policy.aws_organizations_service_trust_policy.arn
  ]
}

resource "aws_organizations_organization" "this" {
  depends_on = [module.aws_service_role_for_organizations]

  feature_set = "ALL"
}
