# AzureInfra

Terraform-based Azure Infrastructure as Code (IaC) for deploying a **Hub-and-Spoke** network topology with **Azure Firewall** and **PaaS Services** integration.

## 📚 Overview

This repository contains Terraform code to provision a foundational Azure environment, including:
- Hub and Spoke Virtual Networks (VNets)
- Azure Firewall in the Hub
- Route Tables for traffic control
- Network Security Groups (NSGs)
- Virtual Machines in Spokes for validation
- **Azure PaaS Databases** (e.g., Azure SQL, PostgreSQL)


## 🏗️ Architecture

### High-Level Diagram

![Azure Hub and Spoke with Firewall and PaaS](https://raw.githubusercontent.com/wassim-dagash/AzureInfra/main/docs/azure_infra_diagram.png)

*(If the diagram does not exist yet, see "Diagram Generation" instructions below.)*

**Components:**
- **Hub VNet**:
  - Azure Firewall
  - Route Tables
- **Spoke VNet(s)**:
  - Virtual Machines
  - PaaS Database Services (Azure SQL / PostgreSQL)
  - NSGs
- **Peering**:
  - Hub <--> Spokes
- **Traffic Routing**:
  - All ingress/egress controlled via Azure Firewall
- **Private Endpoints** *(optional)*:
  - PaaS databases can be secured with Private Endpoints if configured

## 📦 Repository Structure

```bash
├── modules/         # Reusable Terraform modules
├── environments/    # Environment-specific configurations (e.g., dev, prod)
├── main.tf          # Entry point for Terraform
├── variables.tf     # Variables definition
├── outputs.tf       # Output values
├── docs/            # Documentation assets (e.g., diagrams)
├── README.md        # Project documentation
└── ...
```

## 🚀 Getting Started

### Prerequisites
- [Terraform](https://developer.hashicorp.com/terraform/downloads) v1.5+
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- Azure Subscription access

### Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/wassim-dagash/AzureInfra.git
   cd AzureInfra
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Plan the deployment:**
   ```bash
   terraform plan
   ```

4. **Apply the configuration:**
   ```bash
   terraform apply
   ```

> ℹ️ *Customize variables in `terraform.tfvars` if needed.*

## ⚙️ Configuration

All major inputs are declared in [`variables.tf`](variables.tf).

Example `terraform.tfvars`:
```hcl
location               = "East US"
resource_group         = "rg-azureinfra"
vnet_address_space_hub = "10.0.0.0/16"
vnet_address_space_spoke1 = "10.1.0.0/16"
vnet_address_space_spoke2 = "10.2.0.0/16"
```

## 📊 Outputs

After deployment, Terraform will output:
- Hub and Spoke VNet IDs
- Firewall Public IP
- VM Private IPs
- PaaS Database Connection Info (if applicable)

## 🛡️ Security Notes

- Only allow trusted IPs or subnets in NSG rules.
- Firewall policies are configurable for application rules.
- Recommend securing Terraform state with remote backends.
- Use Private Endpoints for PaaS database resources for enhanced security.

## 📄 License

MIT License. See [LICENSE](LICENSE).

## 👨‍💻 Support

For questions or issues, open an [Issue](https://github.com/wassim-dagash/AzureInfra/issues).

---

## 📊 Diagram Generation

If `docs/azure_infra_diagram.png` does not exist yet, you can use the following simple structure:

```plaintext
                    +----------------------+
                    |      Azure Firewall   |
                    |    (Hub VNet)          |
                    +----------------------+
                               |
                +--------------+--------------+
                |                             |
       +--------+--------+           +--------+--------+
       |   Spoke 1 VNet   |           |   Spoke 2 VNet   |
       | - VM(s)          |           | - VM(s)          |
       | - PaaS Database  |           | - PaaS Database  |
       +------------------+           +------------------+
```

