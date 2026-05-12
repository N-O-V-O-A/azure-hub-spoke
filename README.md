# Azure Hub & Spoke Network Architecture
> Week 1 of my Azure Portfolio Project Series

## Overview
A production-pattern Hub & Spoke network architecture deployed entirely via Azure CLI. This project demonstrates enterprise network segmentation, centralized security enforcement, and forced traffic routing — built from scratch using only the command line.

## Architecture
```
rg-hubspoke-demo (westus)
├── vnet-hub      10.0.0.0/16
│   ├── peering: hub-to-spoke1 ✅ Connected / FullyInSync
│   └── peering: hub-to-spoke2 ✅ Connected / FullyInSync
├── vnet-spoke1   10.1.0.0/16
│   ├── snet-workload-spoke1   10.1.1.0/24
│   ├── nsg-spoke1             (deny-internet-inbound)
│   ├── rt-spoke1              (0.0.0.0/0 → 10.0.0.4)
│   └── vm-spoke1              Ubuntu 22.04 / Standard_D2s_v3
└── vnet-spoke2   10.2.0.0/16
    ├── snet-workload-spoke2   10.2.1.0/24
    ├── nsg-spoke2             (deny-internet-inbound)
    ├── rt-spoke2              (0.0.0.0/0 → 10.0.0.4)
    └── vm-spoke2              Ubuntu 22.04 / Standard_D2s_v3
```

## Design Decisions
- **Spoke-to-spoke traffic is intentionally blocked.** Without an Azure Firewall in the hub, spokes are isolated from each other — that's the point. Validated with a ping that failed exactly as expected.
- **Forced tunneling via route tables** ensures all outbound traffic routes through the hub (10.0.0.4) before going anywhere — ready for a future Azure Firewall.
- **NSGs deny all inbound internet traffic** to spoke subnets, enforcing a zero-trust perimeter.

## Real-World Use Case
This pattern is used by enterprises to isolate workloads (e.g. finance vs engineering departments) while maintaining shared services and centralized security inspection in the hub.

## Deployment Commands

### 1. Create Resource Group
```bash
az group create \
  --name rg-hubspoke-demo \
  --location westus
```

### 2. Create VNets
```bash
# Hub
az network vnet create \
  --resource-group rg-hubspoke-demo \
  --name vnet-hub \
  --address-prefix 10.0.0.0/16 \
  --location westus

# Spoke1
az network vnet create \
  --resource-group rg-hubspoke-demo \
  --name vnet-spoke1 \
  --address-prefix 10.1.0.0/16 \
  --location westus

# Spoke2
az network vnet create \
  --resource-group rg-hubspoke-demo \
  --name vnet-spoke2 \
  --address-prefix 10.2.0.0/16 \
  --location westus
```

### 3. Create VNet Peerings
```bash
# Hub to Spoke1
az network vnet peering create \
  --name hub-to-spoke1 \
  --resource-group rg-hubspoke-demo \
  --vnet-name vnet-hub \
  --remote-vnet vnet-spoke1 \
  --allow-vnet-access \
  --allow-forwarded-traffic

# Spoke1 to Hub
az network vnet peering create \
  --name spoke1-to-hub \
  --resource-group rg-hubspoke-demo \
  --vnet-name vnet-spoke1 \
  --remote-vnet vnet-hub \
  --allow-vnet-access \
  --allow-forwarded-traffic

# Hub to Spoke2
az network vnet peering create \
  --name hub-to-spoke2 \
  --resource-group rg-hubspoke-demo \
  --vnet-name vnet-hub \
  --remote-vnet vnet-spoke2 \
  --allow-vnet-access \
  --allow-forwarded-traffic

# Spoke2 to Hub
az network vnet peering create \
  --name spoke2-to-hub \
  --resource-group rg-hubspoke-demo \
  --vnet-name vnet-spoke2 \
  --remote-vnet vnet-hub \
  --allow-vnet-access \
  --allow-forwarded-traffic
```

### 4. Create Subnets
```bash
# Spoke1 workload subnet
az network vnet subnet create \
  --resource-group rg-hubspoke-demo \
  --vnet-name vnet-spoke1 \
  --name snet-workload-spoke1 \
  --address-prefix 10.1.1.0/24

# Spoke2 workload subnet
az network vnet subnet create \
  --resource-group rg-hubspoke-demo \
  --vnet-name vnet-spoke2 \
  --name snet-workload-spoke2 \
  --address-prefix 10.2.1.0/24
```

### 5. Create and Attach NSGs
```bash
# Create NSGs
az network nsg create --resource-group rg-hubspoke-demo --name nsg-spoke1
az network nsg create --resource-group rg-hubspoke-demo --name nsg-spoke2

# Attach to subnets
az network vnet subnet update --resource-group rg-hubspoke-demo --vnet-name vnet-spoke1 --name snet-workload-spoke1 --network-security-group nsg-spoke1
az network vnet subnet update --resource-group rg-hubspoke-demo --vnet-name vnet-spoke2 --name snet-workload-spoke2 --network-security-group nsg-spoke2

# Deny internet inbound rules
az network nsg rule create --resource-group rg-hubspoke-demo --nsg-name nsg-spoke1 --name deny-internet-inbound --priority 1000 --direction Inbound --access Deny --protocol '*' --source-address-prefix Internet --source-port-range '*' --destination-address-prefix '*' --destination-port-range '*'
az network nsg rule create --resource-group rg-hubspoke-demo --nsg-name nsg-spoke2 --name deny-internet-inbound --priority 1000 --direction Inbound --access Deny --protocol '*' --source-address-prefix Internet --source-port-range '*' --destination-address-prefix '*' --destination-port-range '*'
```

### 6. Create Route Tables with Forced Tunneling
```bash
# Create route tables
az network route-table create --resource-group rg-hubspoke-demo --name rt-spoke1 --location westus
az network route-table create --resource-group rg-hubspoke-demo --name rt-spoke2 --location westus

# Add default routes to hub
az network route-table route create --resource-group rg-hubspoke-demo --route-table-name rt-spoke1 --name default-to-hub --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.0.4
az network route-table route create --resource-group rg-hubspoke-demo --route-table-name rt-spoke2 --name default-to-hub --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.0.4

# Attach to subnets
az network vnet subnet update --resource-group rg-hubspoke-demo --vnet-name vnet-spoke1 --name snet-workload-spoke1 --route-table rt-spoke1
az network vnet subnet update --resource-group rg-hubspoke-demo --vnet-name vnet-spoke2 --name snet-workload-spoke2 --route-table rt-spoke2
```

### 7. Deploy VMs
```bash
az vm create \
  --resource-group rg-hubspoke-demo \
  --name vm-spoke1 \
  --vnet-name vnet-spoke1 \
  --subnet snet-workload-spoke1 \
  --image Ubuntu2204 \
  --size Standard_D2s_v3 \
  --admin-username azureuser \
  --generate-ssh-keys \
  --no-wait

az vm create \
  --resource-group rg-hubspoke-demo \
  --name vm-spoke2 \
  --vnet-name vnet-spoke2 \
  --subnet snet-workload-spoke2 \
  --image Ubuntu2204 \
  --size Standard_D2s_v3 \
  --admin-username azureuser \
  --generate-ssh-keys \
  --no-wait
```

### 8. Deallocate VMs When Done Testing
```bash
az vm deallocate --resource-group rg-hubspoke-demo --name vm-spoke1 --no-wait
az vm deallocate --resource-group rg-hubspoke-demo --name vm-spoke2 --no-wait
```

### 9. Tear Down Everything
```bash
az group delete --name rg-hubspoke-demo --yes --no-wait
```

## Lessons Learned
- VM SKU availability varies significantly by region and subscription age — always check with `az vm list-skus` before deploying
- ARM64 VM sizes (B2pts_v2) are incompatible with standard x64 Ubuntu images — match architecture carefully
- NSGs blocking inbound traffic will also block SSH — use temporary allow rules for testing, then remove them
- Spoke-to-spoke traffic requires a hub firewall/NVA — peering alone is not enough for inter-spoke routing
- Rebuilding in a new region is a normal engineering workflow — second builds are always faster

## What's Next — Week 2
Adding Azure Firewall to the hub to enable controlled spoke-to-spoke traffic inspection and complete the production-ready architecture.

## Resources
- [Azure Hub-Spoke Topology Documentation](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Azure CLI Network Commands](https://docs.microsoft.com/en-us/cli/azure/network)
- [Azure NSG Documentation](https://docs.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview)
