
    # Params﻿

        $DeploymentTest = $FALSE                                                  # $TRUE deletes resource group post deployment
        [string]$AzEnv = 'AzureUSGovernment'
        [string]$Location = 'usgovtexas'                                          # 'usgovtexas' 'East US2'  ||  Region must host E and D VM sizes supporting nested virtualization
        
    # Connect Azure Account

        if ($AzEnv)
        {
            Connect-AzAccount -TenantId $tenantID -Subscription $subscriptionID -Environment $AzEnv
            [ValidateSet("usgovvirginia","usgoviowa","usdodeast","usdodcentral","usgovtexas","usgovarizona")][string]$location = $Location
        }
        else
        {
            Connect-AzAccount -TenantId $tenantID -Subscription $subscriptionID
            [ValidateSet("eastasia","southeastasia","centralus","eastus","eastus2","westus","northcentralus","southcentralus","northeurope","westeurope","japanwest","japaneast","bazilsouth","australiaeast","australiasoutheast","southindia","centralindia","westindia","canadacentral","canadaeast","uksouth","ukwest","westcentralus","wstus2","koreacentral","koreasouth","francecentral","francesouth","australiacentral","australiacentral2","uaecentral","uaenorth","southafricanorth","southaricawest","switzerlandnorth","switzerlandwest","germanynorth","germanywestcentral","norwaywest","norwayeast")][string]$location = $Location
        }

        $Subscription = Get-AzSubscription
        if ($Subscription.Id.Count -gt 1)
        {
            $Count=0
            $Choice = Read-Host "Select Subscription`n $( foreach ($S in $Subscription.Id) { "$($Count): $S`n" ; $Count ++ } )"
            $SubscriptionID=($Subscription.Id)[$Choice]
            $TenantID = ($Subscription.TenantId)[$Choice]
        }
        else
        {
            $SubscriptionID = $Subscription.Id
            $TenantID = $Subscription.TenantId
        }

    # Set Administrator Password
    
        #$SecureAdminPassword = Read-Host -AsSecureString -Prompt "Provide local Administrator password for Azure Stack host VM" | ConvertTo-SecureString -AsPlainText -Force
        $SecureAdminPassword = "1q2w9o0p!Q@W(O)P" | ConvertTo-SecureString -AsPlainText -Force
    
    # Variables

        [int]$instanceNumber = 1                                                  # Resource Group Name Suffix
        [string]$adminUsername = 'AzStackAdmin'                                   # Admin User Name
        [bool]$autoDownloadASDK = $FALSE                                          # $TRUE or $FALSE; $TRUE adds ~35 mins to deployment time
        [string]$resourceGroupNamePrefix = "AzStackPOC"                           # Resource Group Name Prefix
        [string]$publicDnsNamePrefix = "AzStackPOC"                               # DNS Name Prefix
        [string]$virtualMachineSize = "Standard_E48s_v3"                          # v1811+ requires 256GB RAM
        [ValidateSet("development","master")][string]$gitBranch = "master"        # GitHub branch 
        [string]$resourceGroupName = "$resourceGroupNamePrefix-$instanceNumber"
        [string]$publicDnsName = "$publicDnsNamePrefix$instanceNumber"
        #[string]$location = 'East US2'                                            # can be any region that supports E and D VM sizes that supports nested virtualization.

    # Create ARM template parameter object

        $templateParameterObject = @{}
        $templateParameterObject.Add("adminPassword", $SecureAdminPassword)
        $templateParameterObject.Add("publicDnsName",$publicDnsName.ToLower())
        $templateParameterObject.Add("autoDownloadASDK", $autoDownloadASDK)
        $templateParameterObject.Add("virtualMachineSize", $virtualMachineSize)
        $templateParameterObject.Add("adminUsername", $adminUsername)

    # Create Resource Group

        if (!(Get-AzResourceGroup -Name $resourceGroupName -Location $Location))
        {
            New-AzResourceGroup -Name $resourceGroupName -Location $Location
        }

    # Deploy GitHub ARM template using local ARM template parameters

        New-AzResourceGroupDeployment `
            -Name "$resourceGroupName-POC-Deployment" `
            -ResourceGroupName $resourceGroupName `
            -TemplateUri "https://raw.githubusercontent.com/RKauf00/AzureStack-VM-PoC/$gitBranch/azuredeploy.json" `
            -TemplateParameterObject $templateParameterObject `
            -Mode Incremental `
            -AsJob

    # Purge Resource Group if DeploymentTest set to TRUE

        if ($DeploymentTest -eq $TRUE)
        {
            Pause
            Get-AzResourceGroup -Name $resourceGroupName | Remove-AzResourceGroup -AsJob -Force
        }
