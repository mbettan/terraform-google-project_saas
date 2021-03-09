# SaaS Project Factory for Google Cloud

This Terraform project  illustrates how to automate a SaaS Project factory on Google Cloud.

This example illustrates how to:
* Create a [Shared VPC](https://cloud.google.com/vpc/docs/shared-vpc) host project.
* Create the host project and using the [network module](https://github.com/terraform-google-modules/terraform-google-network) to create network.
* Attach the new service projects to the host project.
* Configure Firewall rules
* Reserve an External Static IP
* Create a Bastion Host and assign the external IP


## 0. Prerequisite

* A [GCP Seed Project](https://cloud.google.com/resource-manager/docs/creating-managing-projects#creating_a_project) linked with a valid biiling account
* [Project IAM Admin](https://cloud.google.com/iam/docs/understanding-roles#resource-manager-roles) (**roles/resourcemanager.projectIamAdmin**) for your GCP account
* Terraform 0.12.6


* [Shared VPC Admin](https://cloud.google.com/vpc/docs/shared-vpc#iam_roles_required_for_shared_vpc) (**compute.xpnAdmin** and
**resourcemanager.projectIamAdmin**) for your service account to setup the Shared VPC
* [Service Project Admin](https://cloud.google.com/vpc/docs/shared-vpc#iam_roles_required_for_shared_vpc) (**compute.networkUser**) for your service account to setup the Shared VPC

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
export SERVICE_ACCOUNT_SHORT=svc-terraform-sandbox
export SERVICE_ACCOUNT=${SERVICE_ACCOUNT_SHORT}@${PROJECT_ID}.iam.gserviceaccount.com
```

**02 - Verify the environment variables are set**
```
echo "Project: ${PROJECT_ID}"
echo "GCP Account: ${GCP_ACCOUNT_EMAIL}"
echo "Service Account: ${SERVICE_ACCOUNT}"
echo "Service Account (Shortname): ${SERVICE_ACCOUNT_SHORT}"
echo "Organization: ${ORG_ID}"
```

**03 - Clone git repository**
```
git clone https://github.com/mbettan/terraform-google-project_saas.git
```

## 2. Prepare you  GCP Project

### 2.0 Configure Google Cloud SDK

* Configuration needed for the project and username
```
gcloud config set project ${PROJECT_ID}
gcloud config set account ${GCP_ACCOUNT_EMAIL}
gcloud config list
cloud config configurations list
```
* Authentificate with your account
```
gcloud auth login
```

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
gcloud iam service-accounts create ${SERVICE_ACCOUNT_SHORT} --description="Terraform Service Account" --display-name="Terraform Service Account"
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

## 4. Initialize Terraform project

```
cd examples/shared_vpc
terraform init
```

## 5. Deploy sandbox project

## Inputs

[Input variables](https://learn.hashicorp.com/terraform/getting-started/variables) serve as parameters for a Terraform module, allowing aspects of the module to be customized without altering the module's own source code, and allowing modules to be shared between different configurations. There are several ways to parametrize inputs: interactive, command-line flags and from a file.

### Inputs definition

| Name | Description | Type | Default | Required | Example |
|------|-------------|:----:|:-----:|:-----:|-------------|
| billing\_account | The ID of the billing account to associate this project with | string | n/a | yes | 11X1XX-1X1111-1X1XXX |
| folder\_id | The folder to create projects in | string | n/a | yes | XXXXXXXXXXXX |
| host\_project\_name | Name for Shared VPC host project | string | `"shared-vpc-host"` | no | host_project |
| network\_name | Name for Shared VPC network | string | `"shared-network"` | no | shared-network | 
| organization\_id | The organization id for the associated services | string | n/a | yes | XXXXXXXXXXXXX
| service\_project\_name | Name for Shared VPC service project | string | `"shared-vpc-service"` | no | sandbox_client

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

## Plan sandbox project
```
terraform plan -out=plan.out
```

## Apply sandbox project
```
terraform apply "plan.out"
```

## Ouputs

| Name | Description |
|------|-------------|
| host\_project | The full host project info |
| host\_project\_id | The ID of the created project |
| network\_name | The name of the VPC being created |
| network\_self\_link | The URI of the VPC being created |
| service\_project | The service project info |
| service\_project\_b | The second service project |
| subnets | The shared VPC subets |
| vpc | The network info |

## 7. Delete sandbox project

```
terraform destroy
```
