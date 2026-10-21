# cloudformation-static-website-3tier
AWS CloudFormation project to build a three-tier architecture with a static website hosted on Amazon S3.


## Development progress

### Day — Static website content

**Branch:** `L00205569-static-website-content-patch-1`  
**Commit:** `Add static website content`

**Work planned:**
- Create the website page in `website/index.html`.
- Add styling in `website/css/style.css`.
- Add the page-load message in `website/js/script.js`.
- Create the custom error page in `website/error.html`.
- Added my name and L-number in the index.html file.

### Progress — Three-tier CloudFormation parameters

I added CloudFormation parameters for the project name, VPC and subnet CIDR ranges, EC2 instance type, database username, database instance class, database password version, and allocated database storage.

The EC2 instance type, database username, and database instance class now use Systems Manager Parameter Store paths:

| Setting | Parameter Store path | Parameter type |
|---|---|---|
| EC2 instance type | `/myapp/ec2/instance-type` | `String` |
| Database username | `/cloudformation-lab/3-tier-app/database/username` | `String` |
| Database instance class | `/cloudformation-lab/3-tier-app/database/instance-class` | `String` |

These three paths are already created in Parameter Store in my AWS account(112334179285) and Region(eu-west-1) same as my stack. CloudFormation retrieves their latest values when the stack is created or updated. [AWS documentation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cloudformation-supplied-parameter-types.html)

The VPC and subnet CIDRs, and database storage allocation, remain direct CloudFormation parameters because they configure resources in this stack. `DBPasswordParameterVersion` selects the version for the database password reference.


**Notes or follow-up changes:** Nothing yet. Still working on this.
