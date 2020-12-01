# Configure the Azure provider
   terraform {
     required_version = "0.12.28"
     required_providers {
       azurerm = {
   #      source   = "hashicorp/azurerm"
         version  = ">= 2.0.0"
         features = {}
     }
       azuread = {
        version = "=0.7.0"
     }
   }
 }

data "azuread_user" "temp_user3" {
   user_principal_name = 	"DigitalStudioTempTestUser3@nomsdigitechoutlook.onmicrosoft.com" 
   }

data "azuread_group" "example_MyNewGroup" {
#    name = "AnotherTempGroupForTestPurposes"
    object_id = "85ce009e-62ee-4f87-a201-76ce5aad8133"
  }
 
 resource "azuread_group_member" "MyNewGroup_TempTestUser3" {
    	group_object_id   = data.azuread_group.example_MyNewGroup.id
    	member_object_id  = data.azuread_user.temp_user3.id

 lifecycle {
      create_before_destroy = true
 }
}
