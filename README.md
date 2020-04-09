# __Azure Stack on Azure VM__

## __Description__

Creates a new VM and installs prerequisites to install AzureStack Development kit (ASDK) to run PoC


## __Purpose__

Facilitate [Azure Stack](https://azure.microsoft.com/en-us/overview/azure-stack/) learning and [Azure Stack Operator](https://azure.microsoft.com/en-us/blog/why-your-team-needs-an-azure-stack-operator/) training


## __Process__

### __Visualize ARM Template__

[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.png)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FRKauf00%2FAzureStack-VM-PoC%2Fmaster%2Fazuredeploy.json)


### __Deploy ARM template__

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FRKauf00%2FAzureStack-VM-PoC%2Fmaster%2Fazuredeploy.json)

[![Deploy to Azure Gov](https://azuredeploy.net/AzureGov.png)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FRKauf00%2FAzureStack-VM-PoC%2Fmaster%2Fazuredeploy.json)


### __Deployment Process__

  - Deploy the template on [Azure Commercial](https://aka.ms/Azure-AzStackPOC) or [Azure US Government](https://aka.ms/AzureGov-AzStackPOC)
  - Log on to Azure VM (default username is _administrator_)
  - Run Install-ASDK shortcut saved on the desktop
  - Provide local administrator password at prompt
  - Provide Azure Acccount details at Azure authentication prompt
  - Log on to the server following the server restart
    - Account updates to use AzureStack domain account
    - Acount Name: _AzureStack\AzureStackAdmin_
    - Account Password: Same as _Administrator_ account


### __Example__

`
<insert code snippet here>
`


## __Updates / Change log__

### __08.04.2019__
- Tested with ASDK 1.1907.0.20


## **Enjoy!**
