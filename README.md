# Azure infrastructure with Terraform

This public monorepo manages infrastructure for a personal Azure account.  
Each deployable directory has its own variables, README, Terraform state, and deployment lifecycle.  
Always run Terraform from the directory for the stack you want to change.

## Repository layout

```text
subscription-baseline/   Subscription-wide configuration, starting with a budget
shared/<stack>/          Future infrastructure shared by several projects
projects/<project>/      Future project-specific infrastructure
```

Current independently deployable stacks:

- `subscription-baseline/` manages subscription-wide safeguards.
- `projects/rpi-yolo-hue-api/` manages image storage for the Raspberry Pi
  YOLO/Hue API project.

New shared and project stacks should be added only when they are needed, and
each must include its own README.

## Required resource tag

Every Azure resource type that supports tags must include:

```hcl
managed_by = "terraform"
```

Each stack should define this in a shared `local.common_tags` map and apply that
map to every taggable resource. This tag is an ownership warning: resources
carrying it must be changed through Terraform rather than edited manually in the
Azure portal. Some Azure resource types, including subscription budgets, blob
containers, and storage lifecycle policies, do not support Azure resource tags.

## Install the tools on macOS

Install [Homebrew](https://brew.sh/) first if it is not already installed. Then
install Terraform from HashiCorp's official tap and install the Azure CLI:

```shell
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
brew install azure-cli
```

Verify both tools:

```shell
terraform version
az version
```

See the official [Terraform installation instructions](https://developer.hashicorp.com/terraform/install)
and [Azure CLI installation instructions](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-macos)
if Homebrew reports a problem.

## Sign in to Azure

For local use, Terraform authenticates through the Azure CLI. No Azure password,
client secret, or access token belongs in this repository.

```shell
az login
az account list --output table
az account set --subscription "<your-subscription-id-or-name>"
az account show --output table
```

Check the last command carefully before running Terraform. The
`subscription_id` Terraform variable provides a second, explicit guard against
deploying to the wrong subscription.

## Run a stack

The exact inputs and expected resources are documented in each stack's README.
The normal workflow is:

```shell
cd subscription-baseline
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and replace every placeholder.

terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Review every plan before applying it. The saved `tfplan` file is ignored because
plan files can contain private values.

To remove resources managed by the current stack, first review a destruction
plan and then confirm the destruction explicitly:

```shell
terraform plan -destroy
terraform destroy
```

Do not run `destroy` unless removing the stack is intentional.

## Public repository and state safety

Real `terraform.tfvars`, backend settings, plan files, `.terraform/`, and state
files are ignored. Only sanitized example variable files should be committed.
Before committing, check that no subscription IDs, tenant IDs, personal email
addresses, credentials, private URLs, or other personal values are staged.

Terraform's `sensitive = true` setting hides values from normal CLI output; it
does **not** encrypt those values in state. State must therefore remain private.

This first stack intentionally uses local state. Keep its `terraform.tfstate`
file: Terraform needs it to update or remove the budget. Local state is not a
good long-term backup or collaboration solution. The next infrastructure step
should create private Azure Storage for remote state and migrate this stack,
with a different state key for every independently deployed stack.

The dependency lock file, `.terraform.lock.hcl`, is safe and should be committed
so that provider selections remain repeatable.


