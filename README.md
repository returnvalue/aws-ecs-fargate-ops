# AWS ECS Fargate Operations & Autoscaling Lab

This lab demonstrates a modern container orchestration pattern for the **AWS SysOps Administrator Associate**: managing a serverless container fleet with automated scaling.

## Architecture Overview

The system implements a production-ready containerized service:

1.  **Serverless Compute:** AWS Fargate runs containers without the need to provision or manage EC2 instances.
2.  **Cluster Management:** An ECS Cluster provides the logical boundary for the Fargate service and task execution.
3.  **Task Definition:** A versioned blueprint defines the container image (Nginx), resource limits (CPU/Memory), and IAM permissions.
4.  **Automated Scaling:** Application Auto Scaling monitors the average CPU utilization of the fleet and automatically adjusts the container count (between 1 and 4) to maintain a target of 70% utilization.
5.  **Deep Observability:** Container Insights is enabled on the cluster to provide granular metrics and logs for container performance.

## Key Components

-   **ECS Fargate Service:** Manages the desired state and connectivity of the containers.
-   **Task Execution Role:** Grants ECS the necessary permissions to pull images and manage logs.
-   **Target Tracking Scaling:** The automated mechanism for dynamic fleet adjustment.
-   **Multi-AZ Network:** Tasks are distributed across multiple availability zones for high availability.

## Prerequisites

-   [Terraform](https://www.terraform.io/downloads.html)
-   [LocalStack Pro](https://localstack.cloud/)
-   [AWS CLI / awslocal](https://github.com/localstack/awscli-local)

## Deployment

1.  **Initialize and Apply:**
    ```bash
    terraform init
    terraform apply -auto-approve
    
```

## Verification & Testing

To observe the container operations:

1.  **Verify Cluster & Service:**
    ```bash
    awslocal ecs describe-clusters --clusters sysops-fargate-cluster
    aws ecs describe-clusters --clusters sysops-fargate-cluster
    awslocal ecs describe-services --cluster sysops-fargate-cluster --services sysops-web-service
    aws ecs describe-services --cluster sysops-fargate-cluster --services sysops-web-service
    
```

2.  **Check Running Tasks:**
    ```bash
    awslocal ecs list-tasks --cluster sysops-fargate-cluster
    aws ecs list-tasks --cluster sysops-fargate-cluster
    
```

3.  **Inspect Scaling Policies:**
    ```bash
    awslocal application-autoscaling describe-scaling-policies --service-namespace ecs
    aws application-autoscaling describe-scaling-policies --service-namespace ecs
    
```

4.  **Confirm Container Insights:**
    In a real environment, you would navigate to the CloudWatch Console to view the "Container Insights" dashboard for automated performance metrics.

## Cleanup

To tear down the infrastructure:
```bash
terraform destroy -auto-approve
```

---

💡 **Pro Tip: Using `aws` instead of `awslocal`**

If you prefer using the standard `aws` CLI without the `awslocal` wrapper or repeating the `--endpoint-url` flag, you can configure a dedicated profile in your AWS config files.

### 1. Configure your Profile
Add the following to your `~/.aws/config` file:
```ini
[profile localstack]
region = us-east-1
output = json
# This line redirects all commands for this profile to LocalStack
endpoint_url = http://localhost:4566
```

Add matching dummy credentials to your `~/.aws/credentials` file:
```ini
[localstack]
aws_access_key_id = test
aws_secret_access_key = test
```

### 2. Use it in your Terminal
You can now run commands in two ways:

**Option A: Pass the profile flag**
```bash
aws iam create-user --user-name DevUser --profile localstack
```

**Option B: Set an environment variable (Recommended)**
Set your profile once in your session, and all subsequent `aws` commands will automatically target LocalStack:
```bash
export AWS_PROFILE=localstack
aws iam create-user --user-name DevUser
```

### Why this works
- **Precedence**: The AWS CLI (v2) supports a global `endpoint_url` setting within a profile. When this is set, the CLI automatically redirects all API calls for that profile to your local container instead of the real AWS cloud.
- **Convenience**: This allows you to use the standard documentation commands exactly as written, which is helpful if you are copy-pasting examples from AWS labs or tutorials.
