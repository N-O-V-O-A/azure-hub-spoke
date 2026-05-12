#!/bin/bash
# ============================================================
# Azure Hub & Spoke Network Architecture - Teardown Script
# Week 1 - Azure Portfolio Project Series
# Author: Bryan Novoa
# ============================================================

RESOURCE_GROUP="rg-hubspoke-demo"

echo "============================================================"
echo " Azure Hub & Spoke Teardown"
echo "============================================================"

# ------------------------------------------------------------
# Option 1: Deallocate VMs only (keeps architecture, stops billing)
# ------------------------------------------------------------
echo ""
echo "Deallocating VMs to stop compute billing..."

az vm deallocate \
  --resource-group $RESOURCE_GROUP \
  --name vm-spoke1 \
  --no-wait

az vm deallocate \
  --resource-group $RESOURCE_GROUP \
  --name vm-spoke2 \
  --no-wait

echo "VMs deallocated. Architecture preserved, compute billing stopped."
echo ""

# ------------------------------------------------------------
# Option 2: Full teardown (uncomment to delete everything)
# WARNING: This permanently deletes all resources
# ------------------------------------------------------------

# echo "Deleting entire resource group..."
# az group delete \
#   --name $RESOURCE_GROUP \
#   --yes \
#   --no-wait
# echo "Resource group deletion initiated. All resources will be removed."

echo "============================================================"
echo " Teardown complete!"
echo " To fully delete all resources, uncomment the"
echo " 'az group delete' section and re-run this script."
echo "============================================================"
