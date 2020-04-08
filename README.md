# Azure Stack on Azure VM
Creates a new VM and installs prerequisites to install AzureStack Development kit (ASDK) to run PoC

### Description
This template creates a new Azure VM, and installs, configures all prerequisites that is required to install Azure Stack Development Kit to simplify evaluating all Azure Stack functionalities. 

### Deploy ARM template

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FRKauf00%2FAzureStack-VM-PoC%2Fmaster%2Fazuredeploy.json)

[![Deploy to Azure Gov](https://azuredeploy.net/AzureGov.png)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FRKauf00%2FAzureStack-VM-PoC%2Fmaster%2Fazuredeploy.json)

[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.png)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FRKauf00%2FAzureStack-VM-PoC%2Fmaster%2Fazuredeploy.json)

or use:
- https://aka.ms/Azure-AzStackPOC (Azure Commercial)
- https://aka.ms/AzureGov-AzStackPOC (Azure US Gov)

### High level steps to follow
  - Deploy the template ( check examples on cleanup and deploy.ps1)
  - Logon to Azure VM (default username is administrator)
  - Run Install-ASDK on the desktop (additional automated setup options are available on EXAMPLES.md including ARM template deployment examples) 
  - Follow on-screen instructions
  - Setup will download selected version of ASDK and extract files automatically
  - ASDK setup will be feeded with required default parameters and parameters collected above

### Updates / Change log

**updates on 08.04.2019**
- Tested with ASDK 1.1907.0.20
  
Feel free to post questions and enjoy!
