# Hollowverse Infrastructure

[Terraform](https://terraform.io/) configuration files for Hollowverse infrastructure.

For an overview of the infrastructure, please refer to the [Infrastructure Overview](https://github.com/hollowverse/hollowverse/wiki/Infrastructure-Overview) page on the wiki.

## Making Changes to the Infrastructure

Before making any changes to the infrastructure of Hollowverse, we strongly recommend that you take a look at the code in [`hollowverse/infrastructure`](https://github.com/hollowverse/infrastructure) and read it carefully to have a basic idea on what resources are used and how they are connected to each other. The syntax of Terraform configuration files is pretty simple and readable.

You should also refer to [the Terraform configuration documentation](https://www.terraform.io/docs/configuration/index.html) for a more comprehensive understanding of how to write these files.

### Manual Update Workflow

To update the Hollowverse infrastructure, you need to have administrator privileges on the Hollowverse AWS account. You will also need to install Terraform. We currently use the [version 0.11.7](https://releases.hashicorp.com/terraform/0.11.7/) and we recommend that you use the same version.

Additionally, you need to have access to any sensitive resources that are required to initialize Terraform on your computer. These include the Terraform state that is used in production, which is stored in a private S3 bucket, as well as any other passwords or SSH keys used in the Terraform code.

Once you have Terraform installed, perform [`terraform init`](https://www.terraform.io/docs/commands/init.html) in the repository directory to initialize Terraform locally. This requires that you are signed in to your AWS account via the AWS CLI tool.

Terraform will try to access the remote state stored in S3, and will ask you for the bucket name that stores this state. Use `hollowverse-terraform-state-development` for the development stage, or `hollowverse-terraform-state-production` for the production stage.

Now that Terraform is initialized, try running `terraform plan`. Terraform will ask you for any required variables, including things like the password for the database and the SSH key for the [bastion host instance](https://en.wikipedia.org/wiki/Bastion_host).

Terraform will compare the code in your local version of the repository against the remote state and check what needs to be changed to update the infrastructure. If you did not make any changes, Terraform will simply exit and show that no changes are required.

After you make any changes, [`terraform plan`](https://www.terraform.io/docs/commands/plan.html) will show a list of the resources that need to be updated in place, destroyed, or created from scratch. `plan` won't make any changes to the infrastructure. It will just show what will happen if these changes are applied. [`terraform apply`](https://www.terraform.io/docs/commands/apply.html) will actually execute the plan and update the infrastructure.

It's very important the plan is reviewed carefully before being applied, and preferably reviewed by someone else on the Hollowverse team to make sure no destructive changes are performed inadvertently.

We highly recommend that you read [this article](https://blog.gruntwork.io/how-to-use-terraform-as-a-team-251bc1104973) about the guidelines and best practices to follow when using Terraform. The article is somewhat outdated but the following points are still applicable:

- Do not make out-of-band changes to the infrastructure. All updates should be performed via Terraform code. You should not use AWS web console to make any changes to the resources managed under Terraform. This will cause the Terraform state to be out-of-sync with the actual infrastructure and will confuse Terraform, potentially leading to destructive, hard to fix changes. It will also invalidate the code in the repository as the reproducible true source for the infrastructure.
- Apply changes to a staging environment first. Use a development stage to review and execute the plan before executing it on the production stage.
- Ask for code review before apply the plan to production.

Additionally,

- If you are using [VS Code](http://code.visualstudio.com/), use [the extension recommended](./.vscode/extensions.json) in this repository. It will help you navigate the code, jump to definitions of resources, provide autocompletion and documentation for most of the resources. It will also format the code in a consistent style when you save the files.
- If you are not using VS Code, use `terraform fmt` to format the configuration files for style consistency.
