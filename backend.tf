terraform {
  backend "azurerm" {
    subscription_id       = "5d8bf94e-f520-4d04-b9c5-a3a9f4735a26" # DO NOT DELETE! While these values dont do anything in terraform unless you're using a managed identity, we store them for dso internal use.
    tenant_id             = "747381f4-e81f-4a43-bf68-ced6a1e14edf" # DO NOT DELETE! While these values dont do anything in terraform unless you're using a managed identity, we store them for dso internal use.
    resource_group_name   = "dso-terraform-state"
    storage_account_name  = "dsotstate153861893813308"
    key                   = "testremote.testremote.tfstate"
    container_name        = "testremote"
  }
}
