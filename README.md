# SaaS Project Factory for Google Cloud

## 0. Prerequisite

* A [GCP Project](https://cloud.google.com/resource-manager/docs/creating-managing-projects#creating_a_project) linked with a valid biiling account
* [Project IAM Admin](https://cloud.google.com/iam/docs/understanding-roles#resource-manager-roles) (**roles/resourcemanager.projectIamAdmin**) for your GCP account


* [Shared VPC Admin](https://cloud.google.com/vpc/docs/shared-vpc#iam_roles_required_for_shared_vpc) (**compute.xpnAdmin** and
**resourcemanager.projectIamAdmin**) for your service account to create the Shared VPC

## 1. Google Cloud SDK

### 1.1 Setup your environment

**01 - Environment Variables**
* Replace **YOUR_PROJECT_ID** with the [GCP Project ID](https://cloud.google.com/resource-manager/docs/creating-managing-projects#before_you_begin)
* Replace **YOUR_GCP_ACCOUNT_EMAIL** with your GCP account
* **SERVICE_ACCOUNT** is the [GCP Service Account](https://cloud.google.com/iam/docs/understanding-service-accounts) to run Terraform with
```
export ORG_ID=YOUR_ORG_ID
export PROJECT_ID=YOUR_PROJECT_ID
export GCP_ACCOUNT_EMAIL=<YOUR_GCP_ACCOUNT_EMAIL>
export SERVICE_ACCOUNT=svc-terraform-sandbox@${PROJECT_ID}.iam.gserviceaccount.com
```

**02 - Verify the environment variables are set**
```
echo "Project: ${PROJECT_ID}"
echo "GCP Account: ${GCP_ACCOUNT_EMAIL}"
echo "Service Account: ${SERVICE_ACCOUNT}"
echo "Organization: ${ORG_ID}"
```

**03 - Clone git repository**
```
git clone https://github.com/mbettan/terraform-google-project_saas.git
```

## 2. Prepare you  GCP Project

### 2.1 Google Cloud APIs

```
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable iam.googleapis.com
```

### 2.2 IAM roles

You will need add the following IAM policy bindings to your project. This will provide the permissions required to your GCP account.

* **Service Usage Admin** roles/serviceusage.serviceUsageAdmin
* **Service Account Admin** roles/iam.serviceAccountAdmin
* **Service Account Key Admin** roles/iam.serviceAccountKeyAdmin
* **Storage Admin** roles/storage.admin
* **Logging Admin** logging.admin
```
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="user:${GCP_ACCOUNT_EMAIL}" --role="roles/serviceusage.serviceUsageAdmin"
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="user:${GCP_ACCOUNT_EMAIL}" --role="roles/iam.serviceAccountAdmin"
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="user:${GCP_ACCOUNT_EMAIL}" --role="roles/iam.serviceAccountKeyAdmin"
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="user:${GCP_ACCOUNT_EMAIL}" --role="roles/storage.admin"
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="user:${GCP_ACCOUNT_EMAIL}" --role="roles/logging.admin"
```

### 2.3 Service Account

Following the [least privilege principle](https://cloud.google.com/blog/products/identity-security/dont-get-pwned-practicing-the-principle-of-least-privilege), create a separate Service Account to run Terraform with. This is an optionnal step, feel free to skip this section, if you would like to use the logged-in account privledge to execute terraform actions.

#### Create Service Account
```
gcloud iam service-accounts create svc-terraform-sandbox --description="Terraform Service Account" --display-name="Terraform Service Account"
```

#### Verify Service Account
```
gcloud iam service-accounts list --filter="EMAIL=${SERVICE_ACCOUNT}"
```

#### Grant IAM Role

Grant IAM roles to the Service Account
* Project IAM Admin
* Storage Admin
```
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${SERVICE_ACCOUNT}" --role="roles/resourcemanager.projectIamAdmin"
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${SERVICE_ACCOUNT}" --role="roles/storage.admin"
```

You will need add the following IAM policy binding to your organization
* **Project Creator** roles/resourcemanager.projectCreator
* **Billing User** roles/billing.user

```
gcloud organizations add-iam-policy-binding ${ORG_ID} --member="serviceAccount:${SERVICE_ACCOUNT}" --role="roles/resourcemanager.projectCreator"
gcloud organizations add-iam-policy-binding ${ORG_ID} --member="serviceAccount:${SERVICE_ACCOUNT}" --role="roles/billing.user"
```

#### Service Account key creation

Create and download a service account key for Terraform
```
gcloud iam service-accounts keys create terraform-sandbox.json --iam-account=${SERVICE_ACCOUNT}
```

#### Service Account usage

Supply the key to Terraform using the environment variable GOOGLE_CLOUD_KEYFILE_JSON, setting the value to the location of the file
```
export GOOGLE_CLOUD_KEYFILE_JSON="$(pwd)/terraform-sandbox.json"
```

Ensure the key is setup correctly by prompting the key file on the shell
```
cat `echo ${GOOGLE_CLOUD_KEYFILE_JSON}`
```

## 4. Plan sandbox project

```
cd examples/shared_vpc
terraform init
terraform plan -out=plan.out
```

## 5. Deploy sandbox project

## Inputs

[Input variables](https://learn.hashicorp.com/terraform/getting-started/variables) serve as parameters for a Terraform module, allowing aspects of the module to be customized without altering the module's own source code, and allowing modules to be shared between different configurations. There are several ways to parametrize inputs: interactive, command-line flags and from a file.

### Inputs definition

| Name | Description | Type | Default | Required | Example |
|------|-------------|:----:|:-----:|:-----:|-------------|
| billing\_account | Billing account Identifier to be used. | string | n/a | yes | 11X1XX-1X1111-1X1XXX |
| folder_id | Folder Identifier from the Google Cloud Console | string | n/a | yes | XXXXXXXXXXXX |
| host_project_name | Host Project Name to be used | list(string) | string | yes | host_project |
| network_name | Choose a Virtual Private Cloud (VPC) name to be used  | string | n/a | yes | shared-network | 
| organization_id | Organization Identifier from the Google Cloud Console | string | n/a | yes | XXXXXXXXXXXXX
| service_project_name | Service Project Name to be used | string | n/a | yes | sandbox_client

### Parametrize from a variable file

Populate following mandatory variable values in a new terraform.tfvars in fabric_project

```
billing_account = "11X1XX-1X1111-1X1XXX"
folder_id = "XXXXXXXXXXXX"
host_project_name = "host_project"
network_name = "shared-network"
organization_id = "XXXXXXXXXXXXX"
service_project_name = "sandbox"
```

## Apply sandbox project
```
terraform apply "plan.out"
```

## 7. Delete sandbox project

```
terraform destroy
```
