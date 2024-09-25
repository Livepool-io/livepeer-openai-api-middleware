# Define a provider for each region
provider "aws" {
  for_each = toset(var.regions)
  alias    = replace(each.key, "-", "_")
  region   = each.key
}


# This providers.tf file does the following:
# It specifies the required providers (in this case, AWS) and the version we want to use.
# It defines an AWS provider for each of our four regions.
# Each provider has an alias that we'll use to reference it when creating region-specific resources.