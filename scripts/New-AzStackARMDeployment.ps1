
    # Notes
    #
    #   Azure Region must host E and D VM sizes supporting nested virtualization (Confirmed:usgovtexas and East US2)
    #
    #
    #

    # Script Parameters

    Import-Module AZ

    # Script Parameters

    [bool] $DeploymentTest = $FALSE    # $TRUE deletes resource group post deployment
    [bool] $UseParamObject = $TRUE
    
    [bool] $GovDeployment  = $TRUE

    if ($GovDeployment -eq $TRUE)
    {
        [string] $AzEnv = 'AzureUSGovernment'
        [string] $Location = 'usgovtexas'
    }
    else
    {
        [string] $AzEnv = $NULL
        [string] $Location = 'eastus2'
    }

    [ValidateSet("development","master")] [string] $gitBranch = "master"        # GitHub branch 
    [string] $Template = "https://raw.githubusercontent.com/RKauf00/AzureStack-VM-PoC/$($gitBranch)/azuredeploy.json"
    
    if ($UseParamObject -eq $FALSE)
    {
        [string] $TemplateParams = "<Path to File>"
    }

    
# Connect Azure Account

    Disconnect-AzAccount -ErrorAction SilentlyContinue

    if ($AzEnv)
    {
        Connect-AzAccount -Environment $AzEnv
        #Connect-AzAccount -TenantId $tenantID -Subscription $subscriptionID -Environment $AzEnv
        [ValidateSet("usgovvirginia","usgoviowa","usdodeast","usdodcentral","usgovtexas","usgovarizona")] [string] $location = $Location
    }
    else
    {
        Connect-AzAccount
        #Connect-AzAccount -TenantId $tenantID -Subscription $subscriptionID
        [ValidateSet("eastasia","southeastasia","centralus","eastus","eastus2","westus","northcentralus","southcentralus","northeurope","westeurope","japanwest","japaneast","bazilsouth","australiaeast","australiasoutheast","southindia","centralindia","westindia","canadacentral","canadaeast","uksouth","ukwest","westcentralus","wstus2","koreacentral","koreasouth","francecentral","francesouth","australiacentral","australiacentral2","uaecentral","uaenorth","southafricanorth","southaricawest","switzerlandnorth","switzerlandwest","germanynorth","germanywestcentral","norwaywest","norwayeast")][string]$location = $Location
    }


# Set Azure Subscription

    # Collect Azure Subscription Data
    $Subscription = Get-AzSubscription

    # Evaluate Azure Subscription Data
    if ($Subscription.Id.Count -gt 1)
    {
        $Count             =    0
        $Choice            =    Read-Host "Select Subscription`n $( foreach ($S in $Subscription.Id) { "$($Count): $S`n" ; $Count ++ } )"
        $SubscriptionID    =    ($Subscription.Id)[$Choice]
        $TenantID          =    ($Subscription.TenantId)[$Choice]
    }
    else
    {
        $SubscriptionID    =    $Subscription.Id
        $TenantID          =    $Subscription.TenantId
    }

    # Select Azure Subscription
    Select-AzSubscription -Tenant $TenantID -Subscription $SubscriptionID


# Template Variables

    # Set Instance Number
    [int]    $instanceNumber           =  1                                      # Resource Group Name Suffix

    # Set Azure Values
    [string] $AzureADTenant            =  'Azure-Stack.us' #Read-Host "Azure AD Tenant (Format: <AzureADTenant>.onmicrosoft.com)"
    [string] $siteLocation             =  $Location                              #"usgovtexas"
    [string] $resourceGroupNamePrefix  =  'AzStackPOC'                           # Resource Group Name Prefix
    [string] $resourceGroupName        =  "$($resourceGroupNamePrefix)-$($instanceNumber)"
    [string] $AzureADGlobalAdmin       =  'AzStackHostAdmin@Azure-Stack.us' #Read-Host "Azure AD Global Admin account UPN"

    # Set Azure VM Values
    [string] $adminUsername            =  'AzStackAdmin'                          # Admin User Name
    [string] $virtualMachineName       =  'AzStackHost'
    [string] $virtualMachineSize       =  'Standard_E48s_v3'                      # v1811+ requires 256GB RAM
    [int]    $dataDiskSizeinGB         =  1024
    [int]    $dataDiskCount            =  8
    [bool]   $enableRDSH               =  $FALSE

    # Set Azure Networking Values
    [string] $virtualNetworkName       =  'AzureStack-VNET'
    [string] $addressPrefix            =  '10.0.0.0/24'
    [string] $subnetName               =  'default'
    [string] $subnetPrefix             =  '10.0.0.0/24'
    [string] $publicDnsNamePrefix      =  'AzStackPOC'                            # DNS Name Prefix
    [string] $publicDnsName            =  "$($publicDnsNamePrefix)$($instanceNumber)"
    [string] $publicIpAddressType      =  'Dynamic'

    # Enable / Disable ASDK Auto-Download and Auto-Install
    [bool]   $autoDownloadASDK         =  $TRUE                                   # $TRUE or $FALSE; $TRUE adds ~35 mins to deployment time
    [bool]   $autoInstallASDK          =  $FALSE                                  # $TRUE or $FALSE

    # Set Administrator Passwords
    [String] $SecureAdminPassword         =  '*W^Ma03,k.u^49)6cq'  | ConvertTo-SecureString -AsPlainText -Force #Read-Host -AsSecureString -Prompt "Provide password for local Administrator ($($adminUsername))" | ConvertTo-SecureString -AsPlainText -Force
    [String] $AzureADGlobalAdminPassword  =  '1209qwpo!@)(QWPO'  | ConvertTo-SecureString -AsPlainText -Force #Read-Host -AsSecureString -Prompt "Provide password for $($AzureADGlobalAdmin)" | ConvertTo-SecureString -AsPlainText -Force


# Create ARM Template Parameter Object

    # Purge templateParameterObject Variable
    Remove-Variable templateParameterObject -ErrorAction SilentlyContinue

    # Build templateParameterObject Variable
    $templateParameterObject=@{}
    $templateParameterObject.Add("AzureADTenant",$AzureADTenant)
    $templateParameterObject.Add("siteLocation",$siteLocation)
    $templateParameterObject.Add("AzureADGlobalAdmin",$AzureADGlobalAdmin)
    $templateParameterObject.Add("adminUsername",$adminUsername)
    $templateParameterObject.Add("adminPassword", $SecureAdminPassword)
    $templateParameterObject.Add("virtualMachineName",$virtualMachineName)
    $templateParameterObject.Add("virtualMachineSize",$virtualMachineSize)
    $templateParameterObject.Add("dataDiskSizeinGB",$dataDiskSizeinGB)
    $templateParameterObject.Add("dataDiskCount",$dataDiskCount)
    $templateParameterObject.Add("enableRDSH",$enableRDSH)
    $templateParameterObject.Add("virtualNetworkName",$virtualNetworkName)
    $templateParameterObject.Add("addressPrefix",$addressPrefix)
    $templateParameterObject.Add("subnetName",$subnetName)
    $templateParameterObject.Add("subnetPrefix",$subnetPrefix)
    $templateParameterObject.Add("publicDnsName",$publicDnsName.ToLower())
    $templateParameterObject.Add("publicIpAddressType",$publicIpAddressType)
    $templateParameterObject.Add("autoDownloadASDK",$autoDownloadASDK)
    $templateParameterObject.Add("autoInstallASDK",$autoInstallASDK)
    $templateParameterObject.Add("AzureADGlobalAdminPassword",$AzureADGlobalAdminPassword)


# Create ARM template parameter object
#
#    $templateParameterObject = @{}
#    $templateParameterObject.Add("adminPassword", $SecureAdminPassword)
#    $templateParameterObject.Add("publicDnsName",$publicDnsName.ToLower())
#    $templateParameterObject.Add("autoDownloadASDK", $autoDownloadASDK)
#    $templateParameterObject.Add("autoInstallASDK", $autoInstallASDK)
#    $templateParameterObject.Add("virtualMachineSize", $virtualMachineSize)
#    $templateParameterObject.Add("adminUsername", $adminUsername)
#    $templateParameterObject.Add("AzureADTenant", $AzureADTenant)
#    $templateParameterObject.Add("AzureADGlobalAdmin", $AzureADGlobalAdmin)
#    $templateParameterObject.Add("AzureADGlobalAdminPassword", $AzureADGlobalAdminPassword)


# Create Resource Group

    New-AzResourceGroup -Name $resourceGroupName -Location $Location


# Deploy GitHub ARM Template

    if ($UseParamObject -eq $TRUE)
    {
        # Use ARM Template Parameters Object
        New-AzResourceGroupDeployment `
            -Name "$resourceGroupName-POC-Deployment" `
            -ResourceGroupName $resourceGroupName `
            -TemplateUri $Template `
            -TemplateParameterObject $templateParameterObject `
            -Mode Incremental `
            -AsJob
    }
    else
    {
        # Use ARM Template Parameters File
        New-AzResourceGroupDeployment `
            -Name "$resourceGroupName-POC-Deployment" `
            -ResourceGroupName $resourceGroupName `
            -TemplateUri $Template `
            -TemplateParameterFile $TemplateParams `
            -Mode Incremental `
            -AsJob
    }


# Open Deployment Blade in Azure Portal

    if ($GovDeployment -eq $TRUE)
    {
        Start-Process microsoft-edge:"https://portal.azure.us/#blade/HubsExtension/DeploymentDetailsBlade/overview/id/%2Fsubscriptions%2F$($SubscriptionID)%2FresourceGroups%2F$($resourceGroupName)%2Fproviders%2FMicrosoft.Resources%2Fdeployments%2F$($resourceGroupName)-POC-Deployment"
    }
    else
    {
        Start-Process microsoft-edge:"https://portal.azure./#blade/HubsExtension/DeploymentDetailsBlade/overview/id/%2Fsubscriptions%2F$($SubscriptionID)%2FresourceGroups%2F$($resourceGroupName)%2Fproviders%2FMicrosoft.Resources%2Fdeployments%2F$($resourceGroupName)-POC-Deployment"
    }


# Purge Resource Group if DeploymentTest set to TRUE
#
#    if ($DeploymentTest -eq $TRUE)
#    {
#       Pause
#        Get-AzResourceGroup -Name $resourceGroupName | Remove-AzResourceGroup -AsJob -Force
#    }
