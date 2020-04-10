    Param (
        [Parameter(Mandatory = $true)]
        [string]
        $Username,

        [string]
        $EnableRDSH,

        [string]
        $branch,

        [string]
        $ASDKConfiguratorObject
    )


# Functions

    function DownloadWithRetry([string] $Uri, [string] $DownloadLocation, [int] $Retries = 5, [int]$RetryInterval = 10)
    {
        while ($true)
        {
            try
            {
                Start-BitsTransfer -Source $Uri -Destination $DownloadLocation -DisplayName $Uri
                break
            }
            catch
            {
                $exceptionMessage = $_.Exception.Message
                Write-Host "Failed to download '$Uri': $exceptionMessage"
                if ($retries -gt 0)
                {
                    $retries--
                    Write-Host "Waiting $RetryInterval seconds before retrying. Retries left: $Retries"
                    Clear-DnsClientCache
                    Start-Sleep -Seconds $RetryInterval
        
                }
                else
                {
                    $exception = $_.Exception
                    throw $exception
                }
            }
        }
    }


# Configure C: Partition

    $size = Get-Volume -DriveLetter c | Get-PartitionSupportedSize
    Resize-Partition -DriveLetter c -Size $size.sizemax


# Set Path Values

    $defaultLocalPath = "C:\AzureStackOnAzureVM"
    New-Item -Path $defaultLocalPath -ItemType Directory -Force
    $transcriptLog = "post-config-transcript.txt"
    Start-Transcript -Path $(Join-Path -Path $defaultLocalPath -ChildPath $transcriptLog) -Append

    $logFileFullPath = "$defaultLocalPath\postconfig.log"
    $writeLogParams=
    @{
        LogFilePath = $logFileFullPath
    }

    $branchFullPath = "https://raw.githubusercontent.com/rkauf00/AzureStack-VM-PoC/$branch"


# Download ASDK Help Module and Tested Versions file

    DownloadWithRetry -Uri "$branchFullPath/scripts/ASDKHelperModule.psm1" -DownloadLocation "$defaultLocalPath\ASDKHelperModule.psm1"
    DownloadWithRetry -Uri "$branchFullPath/scripts/testedVersions" -DownloadLocation "$defaultLocalPath\testedVersions"

    if (Test-Path "$defaultLocalPath\ASDKHelperModule.psm1")
    {
        Import-Module "$defaultLocalPath\ASDKHelperModule.psm1" -ErrorAction Stop
    }
    else
    {
        throw "required module $defaultLocalPath\ASDKHelperModule.psm1 not found"   
    }


# Download Install-ASDK.ps1

    DownloadWithRetry -Uri "$branchFullPath/scripts/Install-ASDK.ps1" -DownloadLocation "$defaultLocalPath\Install-ASDK.ps1"


# Download MSFT Edge Enterprise MSI

    DownloadWithRetry -Uri "$branchFullPath/files/MicrosoftEdgeEnterpriseX64.msi" -DownloadLocation "$defaultLocalPath\MicrosoftEdgeEnterpriseX64.msi"


# Download MSDocs Azure Stack Development Kit PDF

    New-Item -Path 'C:\_GettingStarted' -ItemType Directory
    DownloadWithRetry -Uri "$branchFullPath/files/MSDocs-ASDK-28FEB2020.pdf" -DownloadLocation "C:\_GettingStarted\MSDocs-ASDK-28FEB2020.pdf"


# Download Getting Started Favorites File

    New-Item -Path 'C:\_GettingStarted' -ItemType Directory
    DownloadWithRetry -Uri "$branchFullPath/files/Getting_Started.html" -DownloadLocation "C:\_GettingStarted\Getting_Started.html"


# Download and Extract Mobaxterm

        DownloadWithRetry -Uri "https://aka.ms/mobaxtermLatest" -DownloadLocation "$defaultLocalPath\Mobaxterm.zip"
        Expand-Archive -Path "$defaultLocalPath\Mobaxterm.zip" -DestinationPath "$defaultLocalPath\Mobaxterm"
        Remove-Item -Path "$defaultLocalPath\Mobaxterm.zip" -Force


# Enable Remoting Firewall Rule

    Get-NetFirewallRule -Name WINRM-HTTP-In-TCP-PUBLIC | Get-NetFirewallAddressFilter | Set-NetFirewallAddressFilter -RemoteAddress any -PassThru -OutVariable firewallRuleResult | Get-NetFirewallRule | Enable-NetFirewallRule
    Write-Log @writeLogParams -Message $firewallRuleResult
    Remove-Variable -Name firewallRuleResult -Force -ErrorAction SilentlyContinue


# Disable Internet Explorer Enhanced Security Configuration

    Disable-InternetExplorerESC


# Enable Internet Explorer File Download

    New-Item -Path 'HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3' -Force
    New-Item -Path 'HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\0' -Force
    New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3' -Name 1803 -Value 0 -PropertyType DWORD -Force
    New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\0' -Name 1803 -Value 0 -PropertyType DWORD -Force

    
# Process ASDK Configurator Object

    if ($ASDKConfiguratorObject)
    {
        # Convert ASDKConfiguratorObject (double conversion required)
        $AsdkConfigurator = ConvertFrom-Json $ASDKConfiguratorObject | ConvertFrom-Json

        if ($?)
        {
            # Convert Configurator Params to Hash Table
            $ASDKConfiguratorParams = $AsdkConfigurator.ASDKConfiguratorParams | ConvertTo-HashtableFromPsCustomObject

            # Create Temp Directory
            if (!(Test-Path 'C:\Temp'))
            {
                New-Item 'C:\Temp' -ItemType Directory -Force
            }
        
            if (!($ASDKConfiguratorParams.downloadPath))
            {
                $ASDKConfiguratorParams.Add("downloadPath", "D:\ASDKfiles")
            }

            # Create ConfigASDK Directory
            if ($AsdkConfigurator.path)
            {
                New-Item -ItemType Directory -Path $AsdkConfigurator.path -Force -Verbose
            }

            # Create Params Array used in Run-ConfigASDK.ps1
            $paramsArray = @()
            foreach ($param in $ASDKConfiguratorParams.keys)
            {
                if ($ASDKConfiguratorParams["$param"] -eq 'true' -or $ASDKConfiguratorParams["$param"] -eq '' -or $null -eq $ASDKConfiguratorParams["$param"])
                {
                    $paramsArray += "-" + "$param" + ":`$true"
                }
                elseif ($ASDKConfiguratorParams["$param"] -eq 'false')
                {
                    $paramsArray += "-" + "$param" + ":`$false"
                }
                else 
                {
                    $paramsArray += "-" + "$param " + "`'" + "$($ASDKConfiguratorParams["$param"])" + "`'"
                }
            }

            $paramsString = $paramsArray -join " "

            $commandsToRun = "$(Join-Path -Path $AsdkConfigurator.path -ChildPath $AsdkConfigurator.command) $paramsString"

            # Create Download Directory
            New-Item -ItemType Directory -Path $ASDKConfiguratorParams.downloadPath -Force -Verbose
            New-Item -ItemType Directory -Path (Join-Path -Path $ASDKConfiguratorParams.downloadPath -ChildPath ASDK) -Force -Verbose
            New-Item -ItemType Directory -Path $AsdkConfigurator.path -Force -Verbose

            # Download Configurator
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-Webrequest $AsdkConfigurator.AzSPoCURL -UseBasicParsing -OutFile (Join-Path -Path $AsdkConfigurator.path -ChildPath $AsdkConfigurator.command) -Verbose
            
            # Download ISO Files
            if ($ASDKConfiguratorParams.IsoPath2019)
            {
                DownloadWithRetry -Uri https://software-download.microsoft.com/download/17763.253.190108-0006.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us_1.iso -DownloadLocation $ASDKConfiguratorParams.IsoPath2019
            }

            if ($ASDKConfiguratorParams.IsoPath2016)
            {
                DownloadWithRetry -Uri http://download.microsoft.com/download/1/4/9/149D5452-9B29-4274-B6B3-5361DBDA30BC/14393.0.161119-1705.RS1_REFRESH_SERVER_EVAL_X64FRE_EN-US.ISO -DownloadLocation $ASDKConfiguratorParams.IsoPath
            }

            if ($ASDKConfiguratorParams.IsoPathWin10)
            {
                DownloadWithRetry -Uri https://software-download.microsoft.com/download/18363.418.191007-0143.19h2_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso -DownloadLocation $ASDKConfigurator.IsoPathWin10
            }

            # Set Run-ConfigASDK.ps1 Content
            $commandsToRun |  Out-File -FilePath (Join-Path -Path $defaultLocalPath -ChildPath Run-ConfigASDK.ps1) -Encoding ASCII
        }
    }
    else
    {
        Write-Log @writeLogParams -Message 'ASDKConfiguratorObject array missing; exiting'
        Break ; Break
    }


# Create / Set Required Registry Values

    New-Item HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials -Force
    New-Item HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials -Name 1 -Value "wsman/*" -Type STRING -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name 1 -Value "wsman/*" -Type STRING -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation -Name AllowFreshCredentials -Value 1 -Type DWORD -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation -Name AllowFreshCredentialsWhenNTLMOnly -Value 1 -Type DWORD -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation -Name ConcatenateDefaults_AllowFresh -Value 1 -Type DWORD -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation -Name ConcatenateDefaults_AllowFreshNTLMOnly -Value 1 -Type DWORD -Force
    Set-ItemProperty -LiteralPath HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled -Value 1 -Type DWord -Force
    Set-Item -Force WSMan:\localhost\Client\TrustedHosts "*"
    Enable-WSManCredSSP -Role Client -DelegateComputer "*" -Force
    Enable-WSManCredSSP -Role Server -Force


# Install nuget

    Install-PackageProvider nuget -Force 


# Update Execution Policy

    Set-ExecutionPolicy unrestricted -Force


# Download ASDK Downloader

    DownloadWithRetry -Uri "https://aka.ms/azurestackdevkitdownloader" -DownloadLocation "D:\AzureStackDownloader.exe"


# Download ASDK Files (BINS and EXE)

    if (!($AsdkFileList))
    {
        $AsdkFileList = @("AzureStackDevelopmentKit.exe")
        1..10 | ForEach-Object {$AsdkFileList += "AzureStackDevelopmentKit-$_" + ".bin"}
    }

    if (Test-Path -Path $defaultLocalPath\testedVersions)
    {
        $latestASDK = Get-Content $defaultLocalPath\testedVersions | Select-Object -First 1
    }
    else
    {
        $latestASDK = (findLatestASDK -asdkURIRoot "https://azurestack.azureedge.net/asdk" -asdkFileList $AsdkFileList)[0]
    }
    
    Write-Log @writeLogParams -Message "Finding available ASDK versions"

    $asdkDownloadPath = "d:\"
    $asdkExtractFolder = "Azure Stack Development Kit"

    $asdkFiles = ASDKDownloader -Version $latestASDK -Destination $asdkDownloadPath

    Write-Log @writeLogParams -Message "$asdkFiles"


# Extract Azure Stack Development Kit Files

    $f = Join-Path -Path $asdkDownloadPath -ChildPath $asdkFiles[0].Split("/")[-1]
    $d = Join-Path -Path $asdkDownloadPath -ChildPath $asdkExtractFolder

    Write-Log @writeLogParams -Message "Extracting Azure Stack Development kit files;"
    Write-Log @writeLogParams -Message "to $d"

    ExtractASDK -File $f -Destination $d

    $vhdxFullPath = Join-Path -Path $d -ChildPath "cloudbuilder.vhdx"

    if (Test-Path -Path $vhdxFullPath)
    {
        Write-Log @writeLogParams -Message "About to Start Copying ASDK files to C:\"
        Write-Log @writeLogParams -Message "Mounting cloudbuilder.vhdx"
        Copy-ASDKContent -vhdxFullPath $vhdxFullPath -Verbose
    } 


# Create Install-ASDK Desktop Shortcut

    Write-Log @writeLogParams -Message "Creating shortcut: 1_Install-ASDK.lnk"
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\1_AAD_LatestVer_Install-ASDK.lnk")
    $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Shortcut.WorkingDirectory = "$defaultLocalPath"
    $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDK.ps1 -LocalAdminPass $($ASDKConfiguratorParams.VMpwd) -DeploymentType AAD -AADTenant $($ASDKConfiguratorParams.azureDirectoryTenantName) -Version latest}"
    $Shortcut.Save()

    Write-Log @writeLogParams -Message "Creating shortcut: 2_Run-ConfigAsdk.lnk"
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\2_Run-ASDK.lnk")
    $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Shortcut.WorkingDirectory = "$defaultLocalPath"
    $Shortcut.Arguments = "-Noexit -command & {.\Run-ConfigASDK.ps1}"
    $Shortcut.Save()


# Enable Differencing Roles from ASDKImage (except .NET framework 3.5)

    Enable-WindowsOptionalFeature -Online -All -NoRestart -FeatureName @("ActiveDirectory-PowerShell", "DfsMgmt", "DirectoryServices-AdministrativeCenter", "DirectoryServices-DomainController", "DirectoryServices-DomainController-Tools", "DNS-Server-Full-Role", "DNS-Server-Tools", "DSC-Service", "FailoverCluster-AutomationServer", "FailoverCluster-CmdInterface", "FSRM-Management", "IIS-ASPNET45", "IIS-HttpTracing", "IIS-ISAPIExtensions", "IIS-ISAPIFilter", "IIS-NetFxExtensibility45", "IIS-RequestMonitor", "ManagementOdata", "NetFx4Extended-ASPNET45", "NFS-Administration", "RSAT-ADDS-Tools-Feature", "RSAT-AD-Tools-Feature", "Server-Manager-RSAT-File-Services", "UpdateServices-API", "UpdateServices-RSAT", "UpdateServices-UI", "WAS-ConfigurationAPI", "WAS-ProcessModel", "WAS-WindowsActivationService", "WCF-HTTP-Activation45", "Microsoft-Hyper-V-Management-Clients")


# Download OneNodeRole.xml

    DownloadWithRetry -Uri "$branchFullPath/scripts/OneNodeRole.xml" -DownloadLocation "$defaultLocalPath\OneNodeRole.xml"


# Install Windows Features

    [xml]$rolesXML = Get-Content -Path "$defaultLocalPath\OneNodeRole.xml" -Raw
    $WindowsFeature = $rolesXML.role.PublicInfo.WindowsFeature
    $dismFeatures = (Get-WindowsOptionalFeature -Online).FeatureName

    if ($null -ne $WindowsFeature.Feature.Name)
    {
        $featuresToInstall = $dismFeatures | Where-Object { $_ -in $WindowsFeature.Feature.Name }
        if ($null -ne $featuresToInstall -and $featuresToInstall.Count -gt 0)
        {
            Write-Log @writeLogParams -Message "Following roles will be installed"
            Write-Log @writeLogParams -Message "$featuresToInstall"
            Enable-WindowsOptionalFeature -FeatureName $featuresToInstall -Online -All -NoRestart
        }

        if ($EnableRDSH)
        {
            Write-Log @writeLogParams -Message "User also chose to enable RDSH. Adding the Remote Desktop Session Host role"
            Enable-WindowsOptionalFeature -FeatureName @("AppServer", "Licensing-Diagnosis-UI") -Online -All -NoRestart
        }
    }


# Disable Windows Features

    if ($null -ne $WindowsFeature.RemoveFeature.Name)
    {
        $featuresToRemove = $dismFeatures | Where-Object { $_ -in $WindowsFeature.RemoveFeature.Name }
        if ($null -ne $featuresToRemove -and $featuresToRemove.Count -gt 0)
        {
            Write-Log @writeLogParams -Message "Following roles will be uninstalled"
            Write-Log @writeLogParams -Message "$featuresToRemove"
            Disable-WindowsOptionalFeature -FeatureName $featuresToRemove -Online -Remove -NoRestart
        }
    }


# Update Local Admin Account

    Rename-LocalUser -Name $username -NewName Administrator
    Set-LocalUser -Name Administrator -Password ($ASDKConfiguratorParams.VMpwd | ConvertTo-SecureString -AsPlainText -Force)


# Install Microsoft Edge Enterprise

    $MSI = "C:\AzureStackOnAzureVM\MicrosoftEdgeEnterpriseX64.msi"
    if ([System.IO.File]::Exists($MSI) -eq $TRUE)
    {
        $SH = '974EC5E0CB73A298E6FB094EBAE71961462A6A13AEED6CD8BC84977BCB30A7E0A48EC73A381A55E5B010C0E2967F7661003AF74E2FE46ACE5870C48990C6C939'
        if ((Get-FileHash -Path $MSI -Algorithm SHA512).Hash -ne $SH)
        {
            Write-Log @writeLogParams -Message "`n`n ********** `n`n File hash mismatch detected on $($MSI); installation aborted `n`n ********** `n`n"
        }
        else
        {
            $File = Get-Item -Path $MSI
            Write-Log @writeLogParams -Message "Installing $($File.BaseName)"
            $DataStamp = get-date -Format yyyyMMddTHHmmss
            $logFile = '{0}-{1}.log' -f $File.Fullname,$DataStamp
            $MSIArguments = @(
                "/i"
                ('"{0}"' -f $File.Fullname)
                "/qn"
                "/norestart"
                "/L*v"
                $logFile
            )
            Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow
            Write-Log @writeLogParams -Message "Installation finished"
        }
    }


# Stop Installation Transcript

    Stop-Transcript


# Restart Computer

    Restart-Computer -Force
