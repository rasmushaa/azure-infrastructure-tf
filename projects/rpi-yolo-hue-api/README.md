# Raspberry Pi YOLO/Hue API infrastructure

This independently deployed Terraform stack creates private Azure Blob Storage
for images produced or consumed by the `rpi-yolo-hue-api` project and an Azure
Machine Learning workspace for developing and managing its models in Azure
Machine Learning Studio.

## What it creates

- One resource group named `rg-rpi-yolo-hue-api-dev-neu`
- One Standard LRS StorageV2 account in the Hot tier
- One private blob container named `images`
- One container-scoped `Storage Blob Data Owner` assignment for your user
- One lifecycle policy for cleaning up previous blob versions
- One Standard Key Vault for Azure Machine Learning secrets
- One Log Analytics workspace for project telemetry
- One Application Insights component for workspace diagnostics
- One Basic Azure Machine Learning workspace with a system-assigned identity
- One resource-group-scoped `Owner` assignment for your user
- One resource-group-scoped `Support Request Contributor` assignment for your user

The resource group, storage account, Key Vault, Log Analytics workspace,
Application Insights component, and Machine Learning workspace carry the
required `managed_by = "terraform"` tag. The blob container and lifecycle
policy do not support Azure resource tags. Azure role assignments do not
support tags either.

Terraform builds the storage account name from the resource abbreviation `st`,
normalized project name, environment `dev`, region code `neu`, and instance
`01`. It removes characters such as hyphens from the project name and truncates
only that component when necessary to stay within Azure's 24-character limit.
The resulting name for this project is `strpiyolohueapidevneu01`.

The Key Vault follows the same deterministic naming approach and is named
`kvrpiyolohueapidevneu01`. Key Vault names are also globally unique.

Storage account names are globally unique across Azure. Deployment will fail if
another Azure customer already owns this deterministic name; increment the
instance component in `main.tf` if that happens.

Treat `project_name` as immutable after deployment. Changing it changes the
storage account and Key Vault names and can force replacement of those
resources and their data.

## Azure Machine Learning Studio

The workspace is named `mlw-rpi-yolo-hue-api-dev-neu-01` and uses the existing
project storage account as its default storage. Its system-assigned managed
identity is used for service-to-service authentication to associated Azure
resources.

Application Insights writes telemetry to the Terraform-managed Log Analytics
workspace `log-rpi-yolo-hue-api-dev-neu-01` in the project resource group.
Linking this workspace explicitly prevents Application Insights from creating
a separate `ai_*_managed` resource group for its default managed workspace.

For an existing deployment that already has an `ai_*_managed` resource group,
apply this configuration first. Azure updates Application Insights to use the
new project-owned workspace without replacing the Application Insights
resource. Historical telemetry remains in the old managed workspace and is not
migrated automatically. After confirming the new workspace link and deciding
that the old telemetry is no longer needed, delete the old managed resource
group from Azure. It is an Azure-created migration artifact and is not part of
Terraform state.

The user identified by `owner_principal_id` receives the `Owner` role on the
project resource group. This grants full management access to every resource in
the group, including role-assignment management, without granting access at
subscription scope. The user also receives `Support Request Contributor` on the
same resource group for creating and managing Azure support requests associated
with that scope.

This stack intentionally does not create a compute instance, compute cluster,
or Azure Container Registry. Create compute in Studio only when it is needed,
choose an appropriately small size, and stop or delete it when idle. Azure
Machine Learning can create a registry when a workflow first requires custom
container images.

Open [Azure Machine Learning Studio](https://ml.azure.com), sign in with the
user represented by `owner_principal_id`, and select the workspace and its
resource group. Azure role assignments can take several minutes to propagate.

## Hobby-grade security settings

- Anonymous public blob and container access is disabled.
- HTTPS is required and the minimum TLS version is 1.2.
- Infrastructure encryption is enabled in addition to normal service encryption.
- Cross-tenant replication, SFTP, NFSv3, and storage local users are disabled.
- OAuth is preferred in Azure tooling.
- The public network endpoint remains enabled so a Raspberry Pi outside Azure
  can connect. The private container still requires authorization.
- Shared Key authorization remains enabled for practical Terraform provisioning
  and SAS creation and for Azure Machine Learning workspace integration, but
  account keys and connection strings are never output.
- Your private Microsoft Entra user object ID receives `Storage Blob Data Owner`
  only on the `images` container. This provides full blob data access without
  granting data access to unrelated storage accounts or containers. This
  separate data-plane role remains necessary because the resource-group Owner
  role does not grant access to blob contents.
- The Machine Learning workspace, Key Vault, and storage public endpoints stay
  enabled so Studio and the Raspberry Pi can use them without a private network.
  Authorization is still required.
- Key Vault uses Azure RBAC, seven-day soft delete, and the Standard SKU. Purge
  protection is disabled so this hobby stack remains straightforward to tear
  down; a soft-deleted vault name can still remain unavailable temporarily.
- Log Analytics retains project telemetry for 30 days and charges according to
  the selected `PerGB2018` consumption SKU and ingested data.

For application access, use a narrowly scoped, HTTPS-only container SAS with
only the permissions and lifetime the application needs. Do not copy a storage
account key or full connection string onto the Raspberry Pi. Microsoft
recommends Microsoft Entra authorization and user-delegation SAS where the
client's identity model supports them.

## Retention behavior

- Deleted current blobs can be restored for 7 days by default.
- Deleted containers can be restored for 7 days by default.
- Versioning preserves an older version when an image is overwritten.
- Previous versions are permanently cleaned up after 30 days by default.
- Current images are **not** automatically deleted or moved to another tier.

Soft-deleted data and previous versions consume storage until they expire. The
defaults balance accidental-deletion recovery with low hobby-project cost.

## Inputs

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `subscription_id` | Yes | — | Azure subscription GUID without `/subscriptions/` |
| `owner_principal_id` | Yes | — | Private Entra object ID for the project resource-group owner |
| `location` | No | `northeurope` | Azure region for all project resources |
| `soft_delete_retention_days` | No | `7` | Recovery window for deleted blobs and containers |
| `old_version_retention_days` | No | `30` | Lifetime of previous blob versions |

Only `subscription_id` and `owner_principal_id` belong in the ignored
`terraform.tfvars`. The location and retention values are nonprivate project
defaults declared publicly in `variables.tf`; change them there when the
project-wide defaults should change.

## Deploy

Sign in, select the intended subscription, and create the private variables
file:

```shell
az login
az account set --subscription "<your-subscription-id-or-name>"
az account show --output table

cd projects/rpi-yolo-hue-api
cp terraform.tfvars.example terraform.tfvars
az ad signed-in-user show --query id --output tsv
# Edit terraform.tfvars and replace both private ID placeholders.
```

Initialize, validate, and apply a reviewed plan:

```shell
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

AzureRM v5 does not register Azure resource providers by default. This stack
therefore registers only the providers needed by its storage and Machine
Learning workflows before planning or applying. The signed-in identity must be
allowed to register resource providers at subscription scope. If registration
is centrally managed, an administrator can register the providers listed in
`providers.tf` instead; subsequent Terraform runs detect that they are already
registered.

The first plan should add eleven Terraform-managed resources: the resource group,
storage account, private container, data-owner role assignment, lifecycle
management policy, Key Vault, Log Analytics workspace, Application Insights
component, Machine Learning workspace, resource-group owner role assignment,
and support-request contributor role assignment. Azure Machine Learning can
also create service-managed role assignments for its system-assigned identity.

Azure role assignments can take several minutes to propagate after apply. If
the portal initially denies access, wait briefly, refresh the page, and confirm
that it is using your Microsoft Entra account rather than an access key.

Read the generated application settings after apply:

```shell
terraform output -raw storage_account_name
terraform output -raw images_container_name
terraform output -raw primary_blob_endpoint
terraform output -raw machine_learning_workspace_name
terraform output -raw machine_learning_studio_url
terraform output -raw log_analytics_workspace_name
```

The storage account name and endpoint outputs are marked sensitive so normal
Terraform output does not print them accidentally. Neither value is a
credential.

## Access guidance

Prefer a user-delegation SAS created with Microsoft Entra credentials. The
identity creating it needs an appropriate Storage Blob Data role. If the
Raspberry Pi only uploads new images, grant create/write permissions and omit
delete permission. Always require HTTPS and choose a short expiry.

Treat every SAS as a secret: keep it out of Git, logs, screenshots, and
Terraform variables. Store it in a root-readable environment file or secret
store on the Raspberry Pi, and rotate it before expiry.

See Microsoft's guidance for
[Blob Storage security](https://learn.microsoft.com/en-us/azure/storage/blobs/security-recommendations),
[shared access signatures](https://learn.microsoft.com/en-us/azure/storage/common/storage-sas-overview),
and [blob data protection](https://learn.microsoft.com/en-us/azure/storage/blobs/data-protection-overview).

## Destroy carefully

Destroying this stack removes the Machine Learning workspace, its associated
Key Vault, Application Insights component and telemetry workspace, and the
storage account with all images and workspace artifacts in it. Storage soft
delete does not protect against storage account deletion. Download any images,
models, telemetry, and artifacts that must be kept before running:

```shell
terraform plan -destroy
terraform destroy
```

This stack initially uses local state. Keep its state private and separate from
the subscription baseline until both are migrated to distinct remote-state keys.
