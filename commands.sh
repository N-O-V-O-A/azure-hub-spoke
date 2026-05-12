#!/bin/bash
# ============================================================
# Azure Hub & Spoke Network Architecture - Deployment Script
# Week 1 - Azure Portfolio Project Series
# Author: Bryan Novoa
# ============================================================

set -e  # Exit on any error

RESOURCE_GROUP="rg-hubspoke-demo"
LOCATION="westus"
VM_SIZE="Standard_D2s_v3"
ADMIN_USER="azureuser"

echo "============================================================"
echo " Azure Hub & Spoke Deployment"
echo " Resource Group : $RESOURCE_GROUP"
echo " Location       : $LOCATION"
echo "============================================================"

# ------------------------------------------------------------
# 1. Resource Group
# ------------------------------------------------------------
echo ""
echo "[1/7] Creating resource group..."
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# ------------------------------------------------------------
# 2. Virtual Networks
# ------------------------------------------------------------
echo ""
echo "[2/7] Creating VNets (hub + 2 spokes)..."

az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name vnet-hub \
  --address-prefix 10.0.0.0/16 \
  --location $LOCATION

az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name vnet-spoke1 \
  --address-prefix 10.1.0.0/16 \
  --location $LOCATION

az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name vnet-spoke2 \
  --address-prefix 10.2.0.0/16 \
  --location $LOCATION

# ------------------------------------------------------------
# 3. VNet Peerings
# ------------------------------------------------------------
echo ""
echo "[3/7] Creating VNet peerings..."

az network vnet peering create \
  --name hub-to-spoke1 \
  --resource-group $RESOURCE_GROUP \
  --vnet-name vnet-hub \
  --remote-vnet vnet-spoke1 \
  --allow-vnet-access \
  --allow-forwarded-traffic

az network vnet peering create \
  --name spoke1-to-hub \
  --resource-group $RESOURCE_GROUP \
  --vnet-name vnet-spoke1 \
  --remote-vnet vnet-hub \
  --allow-vnet-access \
  --allow-forwarded-traffic

az network vnet peering create \
  --name hub-to-spoke2 \
  --resource-group $RESOURCE_GROUP \
  --vnet-name vnet-hub \
  --remote-vnet vnet-spoke2 \
  --allow-vnet-access \
  --allow-forwarded-traffic

az network vnet peering create \
  --name spoke2-to-hub \
  --resource-group $RESOURCE_GROUP \
  --vnet-name vnet-spoke2 \
  --remote-vnet vnet-hub \
  --allow-vnet-access \
  --allow-forwarded-traffic

# ------------------------------------------------------------
# 4. Subnets
# ------------------------------------------------------------
echo ""
echo "[4/7] Creating workload subnets..."

az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name vnet-spoke1 \
  --name snet-workload-spoke1 \
  --address-prefix 10.1.1.0/24

az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name vnet-spoke2 \
  --name snet-workload-spoke2 \
  --address-prefix 10.2.1.0/24

# ------------------------------------------------------------
# 5. Network Security Groups
# ------------------------------------------------------------
echo ""
echo "[5/7] Creating and attaching NSGs..."

az network nsg create --resource-group $RESOURCE_GROUP --name nsg-spoke1
az network nsg create --resource-group $RESOURCE_GROUP --name nsg-spoke2

az network vnet subnet update \
  --resource-group $RESOURCE_GROUP \
  --vnet-name vnet-spoke1 \
  --name snet-workload-spoke1 \
  --network-security-group nsg-spoke1

az network vnet subnet update \
  --resource-group $RESOURCE_GROUP \
  --vnet-name vnet-spoke2 \
  --name snet-workload-spoke2 \
  --network-security-group nsg-spoke2

az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name nsg-spoke1 \
  --name deny-internet-inbound \
  --priority 1000 \
  --direction Inbound \
  --access Deny \
  --protocol '*' \
  --source-address-prefix Internet \
  --source-port-range '*' \
  --destination-address-prefix '*' \
  --destination-port-range '*'

az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name nsg-spoke2 \
  --name deny-internet-inbound \
  --priority 1000 \
  --direction Inbound \
  --access Deny \
  --protocol '*' \
  --source-address-prefix Internet \
  --source-port-range '*' \
  --destination-address-prefix '*' \
  --destination-port-range '*'

# ------------------------------------------------------------
# 6. Route Tables (Forced Tunneling)
# ------------------------------------------------------------
echo ""
echo "[6/7] Creating route tables with forced tunneling..."

az network route-table create --resource-group $RESOURCE_GROUP --name rt-spoke1 --location $LOCATION
az network route-table create --resource-group $RESOURCE_GROUP --name rt-spoke2 --location $LOCATION

az network route-table route create \
  --resource-group $RESOURCE_GROUP \
  --route-table-name rt-spoke1 \
  --name default-to-hub \
  --address-prefix 0.0.0.0/0 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 10.0.0.4

az network route-table route create \
  --resource-group $RESOURCE_GROUP \
  --route-table-name rt-spoke2 \
  --name default-to-hub \
  --address-prefix 0.0.0.0/0 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 10.0.0.4

az network vnet subnet update \
  --resource-group $RESOURCE_GROUP \
  --vnet-name vnet-spoke1 \
  --name snet-workload-spoke1 \
  --route-table rt-spoke1

az network vnet subnet update \
  --resource-group $RESOURCE_GROUP \
  --vnet-name vnet-spoke2 \
  --name snet-workload-spoke2 \
  --route-table rt-spoke2

# ------------------------------------------------------------
# 7. Virtual Machines
# ------------------------------------------------------------
echo ""
echo "[7/7] Deploying VMs in each spoke..."

az vm create \
  --resource-group $RESOURCE_GROUP \
  --name vm-spoke1 \
  --vnet-name vnet-spoke1 \
  --subnet snet-workload-spoke1 \
  --image Ubuntu2204 \
  --size $VM_SIZE \
  --admin-username $ADMIN_USER \
  --generate-ssh-keys \
  --no-wait

az vm create \
  --resource-group $RESOURCE_GROUP \
  --name vm-spoke2 \
  --vnet-name vnet-spoke2 \
  --subnet snet-workload-spoke2 \
  --image Ubuntu2204 \
  --size $VM_SIZE \
  --admin-username $ADMIN_USER \
  --generate-ssh-keys \
  --no-wait

echo ""
echo "============================================================"
echo " Deployment complete!"
echo " Run: az vm list --resource-group $RESOURCE_GROUP --show-details --output table"
echo " to verify both VMs are running."
echo "============================================================"
