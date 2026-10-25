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

