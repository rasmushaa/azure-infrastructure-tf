# Subscription baseline

This independently deployed Terraform stack manages subscription-wide settings.
It currently creates one monthly cost budget and no resource group, Action
Group, or workload resources.

## What it creates

- One subscription budget named `monthly-subscription-budget`
- Actual-spend email notifications at 50%, 80%, and 100%
- A forecasted-spend email notification at 100%

The default monthly amount is 20 in the subscription's billing currency.

> A budget is an alert, not a spending cap. It does not stop, pause, or delete
> Azure resources when a threshold is reached.

## Inputs

| Variable | Required | Description |
| --- | --- | --- |
| `subscription_id` | Yes | Azure subscription GUID, without `/subscriptions/` |
| `notification_emails` | Yes | One or more private alert recipients |
| `budget_amount` | No | Positive monthly amount; defaults to `20` |
| `budget_start_date` | Yes | First day of the current month in UTC |

The subscription ID and email list are marked sensitive to reduce accidental
display in Terraform output. They are still stored in Terraform state, so both
the real variable file and state must remain private.

## Deploy

Sign in and select the intended subscription:

```shell
az login
az account set --subscription "<your-subscription-id-or-name>"
az account show --output table
```

Create your private variables file:

```shell
cd subscription-baseline
cp terraform.tfvars.example terraform.tfvars
date -u +%Y-%m-01T00:00:00Z
```

Edit `terraform.tfvars`. Replace the subscription ID, email address, and date
placeholder. Change `budget_amount` if 20 is not the desired monthly budget.

Initialize and check the configuration:

```shell
terraform init
terraform fmt -check
terraform validate
```

Preview the change and apply the exact reviewed plan:

```shell
terraform plan -out=tfplan
terraform apply tfplan
```

For the first deployment, the plan should contain exactly one resource to add:
`azurerm_consumption_budget_subscription.monthly`. It should contain four
notification blocks and no resources to change or destroy.

## Verify in Azure

In the Azure portal, open **Cost Management + Billing**, select the subscription,
and open **Budgets**. Confirm that `monthly-subscription-budget` has the expected
amount and all four notification thresholds.

According to Microsoft's
[budget documentation](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets),
Cost Management features can take up to 48 hours to become available for a new
subscription. If the first apply returns a Cost Management availability or 404
error, wait and retry later without changing the Terraform configuration.

Budget emails come from Azure. Add `azure-noreply@microsoft.com` to the email
account's approved senders if notifications are routed to junk mail.

## Local state

This stack initially uses local state. Do not delete `terraform.tfstate`, and do
not commit or share it. Run Terraform for this stack from one trusted Mac until
the state is migrated to the planned private Azure Storage backend.

To remove only this budget, run `terraform plan -destroy`, review the result,
and then run `terraform destroy`.
