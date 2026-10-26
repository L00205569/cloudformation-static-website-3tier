# CloudFormation Lab: Static Website and Three-Tier Architecture

**Student Name:** Patrick Affadu 
**Student ID:** L00205569  
**Module:** CloudFormation Lab  
**AWS Region:** `eu-west-1`

## 1. Project Overview

This project demonstrates Infrastructure as Code (IaC) using AWS CloudFormation to deploy a static website and a three-tier web application.

The solution uses Amazon S3 to store static website files, Amazon CloudFront to provide public-facing website delivery, Amazon EC2 to host a Python Flask API, and Amazon RDS for MySQL to persist application data.

The infrastructure is defined using modular YAML templates and deployed using a Bash script that automates template validation, infrastructure deployment, website publication and post-deployment testing.

### Project Objectives

- Create and deploy a static website using AWS CloudFormation.
- Store static website files in Amazon S3.
- Use Amazon CloudFront as the public-facing web delivery service.
- Implement a three-tier architecture comprising web, application and database tiers.
- Automate infrastructure deployment using CloudFormation and the AWS CLI.
- Apply security, scalability, performance and maintainability best practices.
- Test the deployed website, API and database integration.
- Document the development process, design decisions and use of AI assistance.

## 2. Assignment Requirements and Learning Outcomes

| Requirement | Implementation |
|---|---|
| Create a CloudFormation script for a website | `infra/s3-website.yaml` |
| Display the student's name and L-number | Website header |
| Store static website content in S3 | Amazon S3 website bucket |
| Provide public-facing website access | Amazon CloudFront |
| Implement a three-tier architecture | Networking, compute, security and database templates |
| Use Infrastructure as Code | YAML CloudFormation templates |
| Improve beyond a basic tutorial | Nested stacks, automated deployment, API integration and testing |
| Apply coding best practices | Modular templates, parameters, outputs, validation and documentation |
| Design, implement and test a delivery pipeline | `deploy.sh` |
| Support teamwork and professional communication | Git history, pull requests, documentation and review evidence |


## 3. Infrastructure as Code

AWS describes CloudFormation as its foundational Infrastructure as Code service. It allows AWS resources to be modelled and provisioned using YAML or JSON templates.

Reference: [AWS Lambda Documentation - Infrastructure as Code](https://docs.aws.amazon.com/lambda/latest/dg/foundation-iac.html)

CloudFormation was selected because it enables repeatable deployments, reduces manual configuration, supports infrastructure version control and provides a structured way to create, update and delete AWS resources.

The infrastructure is defined declaratively. Instead of manually creating every resource through the AWS Management Console, the templates describe the required resources and their configuration.


### Benefits of CloudFormation

- Repeatable and consistent infrastructure deployments.
- Version-controlled infrastructure definitions.
- Reusable templates with parameters and outputs.
- Dependency management between related resources.
- Easier infrastructure review and troubleshooting.
- Automated creation, updating and deletion of resources.

## 4. System Architecture

The solution combines static website delivery with a database-backed three-tier application.

### 4.1 Web Tier

The website is stored in Amazon S3 and delivered publicly through Amazon CloudFront.

The frontend consists of:

- `website/index.html` - website structure and user interface.
- `website/app.js` - client-side application logic and API integration.
- `website/config.js` - API configuration used by the browser.

CloudFront provides the public-facing endpoint for accessing the website and supports content caching.

### 4.2 Application Tier

An Amazon EC2 instance hosts a Python Flask application.

The API handles application requests, processes submitted messages and communicates with the database. AWS Systems Manager is used to manage the EC2 instance and execute operational commands without requiring direct SSH access.

The application exposes the following endpoints:

| Endpoint | Method | Purpose |
|---|---|---|
| `/health` | GET | Checks application health |
| `/api/messages` | GET | Retrieves stored messages |
| `/api/messages` | POST | Submits and stores a message |

### 4.3 Database Tier

Amazon RDS for MySQL stores application data.

The Flask API communicates with the database to save submitted messages and retrieve previously stored messages. This allows the application to retain data beyond an individual browser session.

The database should only accept connections from authorised application resources.


### 4.4 Request Flow and Networking

1. Users access the website through CloudFront, which delivers static files from S3.
2. The website sends requests to the Flask API.
3. The API reads and writes messages in the RDS MySQL database.
4. The API returns the response to the website.

The VPC, subnets, routes and security groups are defined in the networking and security templates. These control connectivity between the application and database tiers.

## 5. Repository Structure

```text
.
├── CODE_OF_CONDUCT.md
├── deploy.sh
├── infra/
│   ├── compute.yaml
│   ├── database.yaml
│   ├── network.yaml
│   ├── s3-website.yaml
│   └── security.yaml
├── main.yaml
├── README.md
└── website/
    ├── app.js
    ├── config.js
    └── index.html
```

- `main.yaml` coordinates the nested CloudFormation stacks.
- `infra/` contains the networking, security, compute, database and website templates.
- `website/` contains the frontend files.
- `deploy.sh` automates deployment and verification.


## 6. CloudFormation Design

The root template, `main.yaml`, deploys separate nested stacks for the main infrastructure components. This keeps the templates organised and makes the solution easier to maintain and review.

## 7. Deployment Automation

The `deploy.sh` script automates the deployment process:

1. Checks prerequisites and validates the CloudFormation templates.
2. Uploads nested templates to S3.
3. Deploys or updates the CloudFormation stack.
4. Publishes the website files and configuration.
5. Checks EC2 availability through Systems Manager.
6. Verifies the website and API responses.

This reduces manual steps and makes deployments more consistent.

## 8. Prerequisites

Before deployment, you need:

- An AWS account with the required permissions.
- AWS CLI configured with valid credentials.
- Bash and `curl`.
- The S3 bucket used to store nested templates.
- The project files and required deployment parameters.

Do not commit AWS credentials or passwords to the repository.

## 9. Deployment

Clone the repository:

```bash
git clone https://github.com/L00205569/cloudformation-static-website-3tier.git
cd cloudformation-static-website-3tier
```

Validate the root template:

```bash
aws cloudformation validate-template \
  --template-body file://main.yaml \
  --region eu-west-1
```

Run the deployment script:

```bash
chmod +x deploy.sh
./deploy.sh
```

When deployment completes, open the CloudFront URL reported by the script. Submit a message through the website and refresh the page to check that it is retrieved from the database.

## 10. Testing

The deployment script checks the templates, CloudFormation deployment, EC2 readiness, website availability, published configuration and API response.

Manual testing should also confirm that submitting a message stores it in the database and that it remains available after refreshing the page.

Record the actual results and include screenshots or command output where useful.

| Test | Result |
|---|---|
| Template validation | [Pass/Fail] |
| CloudFormation deployment | [Pass/Fail] |
| Website availability | [Pass/Fail] |
| API and database integration | [Pass/Fail] |

## 11. ### Deployment Issues and Fixes

During development, I encountered several issues while testing and improving `deploy.sh`.

1. **CloudFormation stack name conflict:** The script initially used a different stack name, which caused deployment conflicts with the existing `student-three-tier` stack. I updated the script to use the correct stack name and reuse the existing deployment.

2. **Existing S3 bucket conflict:** CloudFormation attempted to create a website bucket that already belonged to the existing stack. I adjusted the deployment approach to avoid creating a duplicate bucket.

3. **Nested template uploads:** I improved how nested CloudFormation templates are uploaded to S3 by using unique, timestamped prefixes. This helps prevent conflicts with previously uploaded templates.

4. **CloudFormation parameters:** I reviewed and corrected the configuration passed between the root and nested templates, including the parameters used to configure AWS Systems Manager Parameter Store.

5. **API returning HTTP 500 errors:** The API initially failed because a required Python dependency, `cryptography`, was missing. I added the dependency to the EC2 instance setup so it would also be installed during future deployments.

6. **Deployment validation and testing:** I improved the deployment checks to validate the CloudFormation templates, check the required configuration, verify the EC2 instance is available through Systems Manager, and test the website and API after deployment.

7. **CloudFront cache updates:** I included CloudFront cache invalidation in the deployment process so that updated website files can be served without relying on cached versions.

After these changes, the deployment completed successfully, and the website, configuration and API/database checks passed.

## 12. Limitations and Future Improvements

The application is currently deployed in my AWS Free Tier account as part of this assignment. 

There is still room to improve it in the future, such as adding a load balancer and Auto Scaling, expanding automated testing, setting up monitoring and alerts, and improving recovery procedures. 

These are areas I would like to explore further as I continue developing the project.

## 13. Development and Version Control

My repository [https://github.com/L00205569/cloudformation-static-website-3tier.git] shows individual development through meaningful commits, feature branches and regular pull requests. Each Pull requests explains the changes.

Ensure the commit history reflects your own work, as required by the assignment.

## 14. Research and AI Assistance

### AWS Documentation

AWS describes CloudFormation as its foundational Infrastructure as Code service.

Reference: [AWS - Infrastructure as Code for Lambda](https://docs.aws.amazon.com/lambda/latest/dg/foundation-iac.html)

Add any other tutorials or documentation you actually used, with their URLs and a short explanation of how they informed your work.

### LLM Assistance

I used An LLM to help explain CloudFormation concepts, troubleshoot deployment issues, review the deployment workflow and improve project documentation.

Examples of prompts used during development included requests to:

- Structure a CloudFormation solution using nested templates.
- Review deployment validation and error handling.
- Troubleshoot CloudFormation deployment and deletion errors.
- Improve the website and explain the application architecture.

## 15. Conclusion

This project uses AWS CloudFormation to deploy a static website and a three-tier application. Amazon S3 and CloudFront deliver the website, EC2 hosts the Flask API, and RDS for MySQL stores application data.

The modular templates and deployment script demonstrate Infrastructure as Code, automation and testing, while the project documentation explains the architecture and key best practices.

