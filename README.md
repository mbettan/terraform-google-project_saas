# Project Factory - Gcloud

## 0. Prerequisite

* A [GCP Project](https://cloud.google.com/resource-manager/docs/creating-managing-projects#creating_a_project) linked with a valid billing account
* [Project IAM Admin](https://cloud.google.com/iam/docs/understanding-roles#resource-manager-roles) (**roles/resourcemanager.projectIamAdmin**) for your GCP account

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
git clone https://github.com/mbettan/gcloud-google-cloud-factory.git
```

## 2. Prepare your GCP Project

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

Following the [least privilege principle](https://cloud.google.com/blog/products/identity-security/dont-get-pwned-practicing-the-principle-of-least-privilege), create a separate Service Account to run Terraform with. This is an optionnal step, feel free to skip this section, if you would like to use the logged-in account privledge to execute gcloud actions.

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

## 3 Executing the Gcloud actions

### 3.1 Assigning User permissions at the folder level

```
chmod +x iam-data-engineers.sh
./iam-data-engineers.sh
```

### 3.2 Assigning Groups permissions at the project level

```
chmod +x iam-group-data-engineers.sh
./iam-group-data-engineers.sh
```

### 3.3 Creating a project

```
chmod +x create-project.sh
./create-project.sh
```
