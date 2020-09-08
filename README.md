# Moodle Installation using Amazon Spot Instance

## Requirements

- AWS Account
- Route53 Domain Name and Domain Zone
- Terraform 13.0+

## Pre-Install

Adjust configurations:

- [`vars/variables.tfvars`](vars/variables.tfvars)

### Provisionin

Initiate a new Terraform project 

```sh
terraform init
```

Plan and apply your changes, provisionning the resources:

```sh
terraform apply -var-file=../vars/variables.tfvars
```

## Post-Install

It will take about 5 to 10 minutes to complete the installation of Moodle Server. Once the Moodle Server is installaed, you can access it via the URL that you have provided in the variables.tfvars file (i.e. moodle.example.com in this case).

## Remove

In case you need to destroy the resources, the process is like this :

```sh
terraform destroy --auto-approve -var-file=../vars/variables.tfvars
```
