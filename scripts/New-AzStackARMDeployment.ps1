
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
    [string] $Template = "https://raw.githubusercontent.com/RKauf00/AzureStack-VM-PoC/$gitBranch/azuredeploy.json"
    
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


# Collect Azure Subscription Data

    $Subscription = Get-AzSubscription

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

    Select-AzSubscription -Tenant $TenantID -Subscription $SubscriptionID


# Template Variables

    # Set Instance Number
    [int]    $instanceNumber           =  2                                      # Resource Group Name Suffix

    # Set Azure Values
    [string] $AzureADTenant            =  Read-Host "Azure AD Tenant (Format: <AzureADTenant>.onmicrosoft.com)"
    [string] $siteLocation             =  $Location                              #"usgovtexas"
    [string] $resourceGroupNamePrefix  =  'AzStackPOC'                           # Resource Group Name Prefix
    [string] $resourceGroupName        =  "$($resourceGroupNamePrefix)-$($instanceNumber)"
    [string] $AzureADGlobalAdmin       =  Read-Host "Azure AD Global Admin account UPN"

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
    [bool]   $autoInstallASDK          =  $TRUE                                   # $TRUE or $FALSE

    # Set Administrator Passwords
    [SecureString] $SecureAdminPassword         =  Read-Host -AsSecureString -Prompt "Provide password for local Administrator ($($adminUsername))" | ConvertTo-SecureString -AsPlainText -Force
    [SecureString] $AzureADGlobalAdminPassword  =  Read-Host -AsSecureString -Prompt "Provide password for $($AzureADGlobalAdmin)" | ConvertTo-SecureString -AsPlainText -Force


# Create ARM Template Parameter Object

    Remove-Variable templateParameterObject -ErrorAction SilentlyContinue

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

    #$Count=1
    #do
    #{
    #    if ($Job.State -eq 'Running')
    #    {
    #        Write-Host "`nStatus Check -- $($Count)`n" -ForegroundColor Cyan
    #        Write-Host "    Job ID:    $($Job.ID)" -ForegroundColor Cyan
    #        Write-Host "    Job State: $($Job.JobStateInfo)" -ForegroundColor Cyan
    #        $Count++
    #        Start-Sleep -Seconds 60
    #    }
    #    elseif ($Job.State -eq 'Failed')
    #    {
    #        Write-Host "`nStatus Check -- $($Count)`n" -ForegroundColor Red
    #        Write-Host "    Job ID:    $($Job.ID)" -ForegroundColor Red
    #        Write-Host "    Job State: $($Job.JobStateInfo)`n" -ForegroundColor Red
    #        return Write-Host $Job.Error -ForegroundColor Red
    #    }
    #    else
    #    {
    #        Write-Host "`nStatus Check -- $($Count)`n" -ForegroundColor Red
    #        Write-Host "    Job ID:    $($Job.ID)" -ForegroundColor Red
    #        Write-Host "    Job State: $($Job.JobStateInfo)`n" -ForegroundColor Red
    #    }
    #}
    #while
    #(
    #    $Job.State -eq 'Running'
    #)

# Purge Resource Group if DeploymentTest set to TRUE

    if ($DeploymentTest -eq $TRUE)
    {
        Pause
        Get-AzResourceGroup -Name $resourceGroupName | Remove-AzResourceGroup -AsJob -Force
    }
