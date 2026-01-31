# Node.js Service Deployment

Project URL : https://roadmap.sh/projects/nodejs-service-deployment

This project provides an automated infrastructure-as-code solution to deploy a Node.js Express application on AWS EC2 using Terraform and Ansible. It follows Infrastructure as Code (IaC) best practices to create, configure, and manage cloud resources programmatically.

## Project Overview

The project is designed to:
- Provision AWS infrastructure (VPC, subnets, security groups, EC2 instance) using **Terraform**
- Configure the EC2 instance and deploy a Node.js application using **Ansible**
- Manage SSH keys for secure authentication
- Run the Node.js application as a systemd service for automatic management and restart

## Project Structure

```
Node.js-Service-Deployment/
├── .github/
│   └── workflows/
│       └── github_actions.yml          # CI/CD pipeline configuration
├── terraform/                          # Infrastructure as Code (AWS)
│   ├── main.tf                         # Main Terraform configuration
│   ├── providers.tf                    # Provider configuration
│   ├── variables.tf                    # Variable declarations
│   ├── variables.auto.tfvars           # Variable values (auto-loaded)
│   ├── output.tf                       # Output values
│   ├── network/                        # VPC and networking modules
│   │   ├── main.tf
│   │   └── output.tf
│   └── security/                       # Security groups module
│       ├── main.tf
│       ├── output.tf
│       └── variables.tf
├── ansible/                            # Configuration Management
│   ├── ansible.cfg                     # Ansible configuration
│   ├── inventory                       # Inventory file (target servers)
│   └── node_service.yml                # Playbook (automation tasks)
├── app/                                # Node.js Application
│   ├── index.js                        # Express server
│   ├── package.json                    # Node.js dependencies
│   └── .gitignore                      # Git ignore rules
├── keys/                               # SSH Keys (for authentication)
│   ├── key                             # Private key
│   ├── key.pub                         # Public key
│   └── .gitignore                      # Ensures keys aren't committed
├── systemd/                            # Service Management
│   └── app.service                     # Systemd service file
└── README.md                           # This file
```

## Prerequisites

Before you begin, ensure you have the following installed:

- **Terraform** (>= 1.0) - [Install](https://www.terraform.io/downloads)
- **Ansible** (>= 2.9) - [Install](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
- **AWS CLI** - [Install](https://aws.amazon.com/cli/)
- **SSH** client (pre-installed on Linux/Mac, use WSL or PuTTY on Windows)
- An **AWS account** with appropriate permissions

## Configuration Guide

### 1. AWS Credentials Setup

Configure your AWS credentials before running Terraform:

```bash
aws configure
```

You'll be prompted for:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., `eu-west-1`)
- Default output format (e.g., `json`)

Alternatively, set environment variables:

```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_DEFAULT_REGION="eu-west-1"
```

### 2. SSH Keys Configuration

SSH keys are used for secure authentication between your machine and the EC2 instance.

#### Generate New Keys (if needed)

```bash
ssh-keygen -t ed25519 -f keys/key -N ""
```

Or for RSA (older systems):

```bash
ssh-keygen -t rsa -b 4096 -f keys/key -N ""
```

This creates:
- `keys/key` - Private key (keep secure, permissions 600)
- `keys/key.pub` - Public key

#### Set Proper Permissions

```bash
chmod 600 keys/key
chmod 644 keys/key.pub
```

**Security Note**: Never commit private keys to version control. The `.gitignore` file in `keys/` prevents this.

### 3. Terraform Configuration

#### Step 1: Define Variables

Edit [terraform/variables.auto.tfvars](terraform/variables.auto.tfvars) to specify:

```hcl
ami           = "ami-04df1508c6be5879e"  # Ubuntu 22.04 LTS in eu-west-1
instance_type = "t3.micro"               # Free tier eligible
```

**Common Ubuntu AMIs:**
- **eu-west-1 (Ireland)**: `ami-04df1508c6be5879e` (Ubuntu 22.04 LTS)
- **us-east-1 (N. Virginia)**: `ami-0c55b159cbfafe1f0` (Ubuntu 22.04 LTS)
- Find your region's AMI: https://cloud-images.ubuntu.com/locator/ec2/

**Instance Types:**
- `t3.micro` - Free tier, suitable for testing
- `t3.small` - ~$0.023/hour, more resources
- `t2.micro` - Previous generation free tier option

#### Step 2: Review Module Configurations

**Network Module** ([terraform/network/main.tf](terraform/network/main.tf)):
- Creates VPC, subnet, internet gateway, and route table
- Configures network infrastructure

**Security Module** ([terraform/security/main.tf](terraform/security/main.tf)):
- Creates security group with inbound/outbound rules
- Manages firewall rules for EC2 access

#### Step 3: Initialize and Plan

```bash
cd terraform

# Initialize Terraform (downloads providers and modules)
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan
```

#### Step 4: Apply Configuration

```bash
# Create AWS resources
terraform apply

# Review and confirm by typing 'yes'
```

After successful deployment, Terraform outputs the EC2 instance IP address.

#### Step 5: Destroy Resources (when done)

```bash
terraform destroy

# Confirm by typing 'yes' to avoid accidental deletion
```

### 4. Ansible Configuration

Ansible automates the deployment and configuration of the application on the EC2 instance.

#### Update Inventory

Edit [ansible/inventory](ansible/inventory) with your EC2 instance IP:

```ini
[server]
<YOUR_EC2_IP> ansible_user=ubuntu ansible_ssh_private_key_file=../keys/key
```

Example:
```ini
[server]
35.180.97.219 ansible_user=ubuntu ansible_ssh_private_key_file=../keys/key
```

**Key Parameters:**
- `ansible_user` - SSH user for EC2 (typically `ubuntu` or `ec2-user` depending on AMI)
- `ansible_ssh_private_key_file` - Path to your private SSH key

#### Configure Ansible

Review [ansible/ansible.cfg](ansible/ansible.cfg):

```ini
[defaults]
inventory      = ./inventory           # Points to inventory file
sudo_user      = root                  # Sudo user for privilege escalation

[privilege_escalation]
become         = True                  # Enable sudo
become_user    = root                  # User to become
```

Adjust if needed for your setup (e.g., different inventory location).

#### Review Playbook

The [ansible/node_service.yml](ansible/node_service.yml) playbook performs:
1. Update package manager (apt)
2. Install Node.js and npm
3. Clone project repository from GitHub
4. Install Node.js dependencies (npm install)
5. Copy systemd service file
6. Enable and start the application service

#### Run Playbook

```bash
cd ansible

# Test connectivity (optional)
ansible all -i inventory -m ping

# Run the playbook
ansible-playbook node_service.yml

# Run with verbose output for debugging
ansible-playbook -v node_service.yml
```

After successful execution, your application will be running on the EC2 instance.

### 5. Systemd Service Configuration

The application runs as a systemd service for automatic management.

**Service File:** [systemd/app.service](systemd/app.service)

```ini
[Unit]
Description=Node.js Application Service
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=root
ExecStart=/usr/bin/node /root/work/Node.js-Service-Deployment/app/index.js

[Install]
WantedBy=multi-user.target
```

**Key Features:**
- `Restart=always` - Automatically restarts if the application crashes
- `RestartSec=1` - Waits 1 second before restarting
- `Type=simple` - Runs in the foreground

**Manage Service (on EC2):**

```bash
# Check service status
sudo systemctl status app.service

# Start/stop service
sudo systemctl start app.service
sudo systemctl stop app.service

# View service logs
sudo journalctl -u app.service -f
```

## Node.js Application

The application is a simple Express.js server:

**File:** [app/index.js](app/index.js)

```javascript
const express = require('express')
const app = express()
const port = 80

app.get('/', (req, res) => {
    res.send('Hello, world!')
})

app.listen(port, () => {
    console.log(`Example app listening on port ${port}`)
})
```

**Port**: Runs on port 80 (HTTP)

**Dependencies** ([app/package.json](app/package.json)):
- `express` ^5.2.1 - Web framework

### Modify the Application

To customize:

1. Edit [app/index.js](app/index.js) with your Express routes
2. Update dependencies in [app/package.json](app/package.json)
3. Commit and push to your GitHub repository
4. Ansible will pull the latest version when you run the playbook again

## Deployment Workflow

### Full Deployment (First Time)

```bash
# 1. Configure AWS credentials
aws configure

# 2. Set up SSH keys
ssh-keygen -t ed25519 -f keys/key -N ""
chmod 600 keys/key

# 3. Deploy infrastructure with Terraform
cd terraform
terraform init
terraform plan
terraform apply

# 4. Wait for instance to boot (~30 seconds)
# Note the EC2 instance IP from Terraform output

# 5. Update Ansible inventory
cd ../ansible
# Edit inventory file with EC2 IP

# 6. Run Ansible playbook
ansible-playbook node_service.yml

# 7. Verify deployment
# Access http://<YOUR_EC2_IP> in a browser
```

### Update Application

```bash
# 1. Push changes to GitHub
git add .
git commit -m "Update application"
git push

# 2. SSH into instance and pull latest changes
ssh -i keys/key ubuntu@<YOUR_EC2_IP>
cd ~/work/Node.js-Service-Deployment
git pull

# 3. Restart service
sudo systemctl restart app.service

# Or re-run Ansible playbook
cd ../ansible
ansible-playbook node_service.yml
```

### Destroy Infrastructure

```bash
cd terraform
terraform destroy
```

## GitHub Actions CI/CD

The project includes a GitHub Actions workflow for automated deployment.

**File:** [.github/workflows/github_actions.yml](.github/workflows/github_actions.yml)

Configure secrets in GitHub:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `TF_VAR_ami`
- `TF_VAR_instance_type`

## Troubleshooting

### SSH Connection Issues

```bash
# Test SSH connectivity
ssh -i keys/key ubuntu@<YOUR_EC2_IP>

# Debug SSH connection
ssh -vvv -i keys/key ubuntu@<YOUR_EC2_IP>
```

**Common Issues:**
- Wrong IP address - Verify from `terraform output`
- Wrong username - Check EC2 AMI documentation (usually `ubuntu` or `ec2-user`)
- Wrong key path - Ensure private key has 600 permissions
- Security group - Verify port 22 is open in Terraform security group

### Ansible Failures

```bash
# Test Ansible connectivity
cd ansible
ansible all -i inventory -m ping

# Run with debug output
ansible-playbook -vvv node_service.yml

# Check specific host
ansible -i inventory server -m setup
```

### Application Not Running

```bash
# SSH into instance
ssh -i keys/key ubuntu@<YOUR_EC2_IP>

# Check service status
sudo systemctl status app.service

# View logs
sudo journalctl -u app.service -n 50

# Manually test
curl http://localhost/
```

### Terraform State Issues

```bash
# If state gets corrupted, refresh it
terraform refresh

# View current state
terraform state list
terraform state show aws_instance.main
```

## Security Best Practices

1. **SSH Keys**: 
   - Keep private keys secure (never commit to Git)
   - Use strong passphrases if not using ed25519
   - Rotate keys periodically

2. **AWS Credentials**:
   - Use IAM users instead of root account
   - Rotate access keys regularly
   - Use environment variables instead of config files in Git

3. **Security Groups**:
   - Restrict SSH access to your IP only
   - Use HTTPS in production (configure with certificates)
   - Limit outbound rules if not needed

4. **Application**:
   - Run with minimal privileges (non-root user recommended)
   - Keep dependencies updated
   - Implement input validation

## Additional Resources

- [Terraform AWS Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [Express.js Guide](https://expressjs.com/)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [Systemd Documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)

## License

See LICENSE file for details.

## Support

For issues or questions:
1. Check the Troubleshooting section
2. Review log files (Terraform, Ansible, systemd)
3. Consult the Additional Resources section
4. Open an issue on GitHub
