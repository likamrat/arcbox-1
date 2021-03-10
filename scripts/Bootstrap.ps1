param (
    [string]$adminUsername,
    [string]$spnClientId,
    [string]$spnClientSecret,
    [string]$spnTenantId,
    [string]$spnAuthority,
    [string]$subscriptionId,
    [string]$clusterName,
    [string]$resourceGroup,
    [string]$azdataUsername,
    [string]$azdataPassword,
    [string]$acceptEula,
    [string]$registryUsername,
    [string]$registryPassword,
    [string]$arcDcName,
    [string]$azureLocation,
    [string]$mssqlmiName,
    [string]$chocolateyAppList,
    [string]$dockerRegistry,
    [string]$dockerRepository,
    [string]$dockerTag
)

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_ID', $spnClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_SECRET', $spnClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_TENANT_ID', $spnTenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_AUTHORITY', $spnAuthority,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('clusterName', $clusterName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_USERNAME', $azdataUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_PASSWORD', $azdataPassword,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ACCEPT_EULA', $acceptEula,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('REGISTRY_USERNAME', $registryUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('REGISTRY_PASSWORD', $registryPassword,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ARC_DC_NAME', $arcDcName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ARC_DC_SUBSCRIPTION', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ARC_DC_REGION', $azureLocation,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('MSSQL_MI_NAME', $mssqlmiName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('DOCKER_REGISTRY', $dockerRegistry,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('DOCKER_REPOSITORY', $dockerRepository,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('DOCKER_TAG', $dockerTag,[System.EnvironmentVariableTarget]::Machine)

# Create path
Write-Output "Create ArcBox path"
$ArcBoxDir = "C:\ArcBox"
$vmDir = "C:\ArcBox\Virtual Machines"
$agentScript = "C:\ArcBox\agentScript"
$tempDir = "C:\Temp"
New-Item -Path $ArcBoxDir -ItemType directory -Force
New-Item -Path $vmDir -ItemType directory -Force
New-Item -Path $tempDir -ItemType directory -Force
New-Item -Path $agentScript -ItemType directory -Force

Start-Transcript "C:\ArcBox\Bootstrap.log"

$ErrorActionPreference = 'SilentlyContinue'

# $sourceFolder = "https://arcinbox.blob.core.windows.net/vhds"

# Uninstall Internet Explorer
Disable-WindowsOptionalFeature -FeatureName Internet-Explorer-Optional-amd64 -Online -NoRestart

# Disabling IE Enhanced Security Configuration
Write-Host "Disabling IE Enhanced Security Configuration"
function Disable-ieESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}
Disable-ieESC

# Extending C:\ partition to the maximum size
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Installing DHCP service 
Write-Output "Installing DHCP service"
Install-WindowsFeature -Name "DHCP" -IncludeManagementTools

# Install Windows Subsystem for Linux
# Used for Bash shell to SSH to the ArcBoxUbuntu
# Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
# dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart


# Installing tools
workflow ClientTools_01
        {
            $chocolateyAppList = 'azure-cli,az.powershell,kubernetes-cli,vcredist140,microsoft-edge,azcopy10,vscode,git,7zip,kubectx,terraform,putty.install'
            #Run commands in parallel.
            Parallel 
                {
                    InlineScript {
                        param (
                            [string]$chocolateyAppList
                        )
                        if ([string]::IsNullOrWhiteSpace($using:chocolateyAppList) -eq $false)
                        {
                            try{
                                choco config get cacheLocation
                            }catch{
                                Write-Output "Chocolatey not detected, trying to install now"
                                iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
                            }
                        }
                        if ([string]::IsNullOrWhiteSpace($using:chocolateyAppList) -eq $false){   
                            Write-Host "Chocolatey Apps Specified"  
                            
                            $appsToInstall = $using:chocolateyAppList -split "," | foreach { "$($_.Trim())" }
                        
                            foreach ($app in $appsToInstall)
                            {
                                Write-Host "Installing $app"
                                & choco install $app /y -Force| Write-Output
                            }
                        }                        
                    }
                    Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/stable" -OutFile "C:\ArcBox\azuredatastudio.zip"
                    Invoke-WebRequest "https://raw.githubusercontent.com/dkirby-ms/arcbox/main/scripts/settings_template.json" -OutFile "C:\ArcBox\settings_template.json"
                    Invoke-WebRequest "https://aka.ms/azdata-msi" -OutFile "C:\ArcBox\AZDataCLI.msi"
                    Invoke-WebRequest "https://raw.githubusercontent.com/dkirby-ms/arcbox/main/scripts/LogonScript.ps1" -OutFile "C:\ArcBox\LogonScript.ps1"
                    Invoke-WebRequest "https://raw.githubusercontent.com/dkirby-ms/arcbox/main/scripts/installArcAgent.ps1" -OutFile "C:\ArcBox\agentScript\installArcAgent.ps1"
                }
        }

ClientTools_01 | Format-Table

workflow ClientTools_02
        {
            #Run commands in parallel.
            Parallel
            {
                InlineScript {
                    Expand-Archive C:\ArcBox\azuredatastudio.zip -DestinationPath 'C:\Program Files\Azure Data Studio'
                    Start-Process msiexec.exe -Wait -ArgumentList '/I C:\ArcBox\AZDataCLI.msi /quiet'
                }
            }
        }
        
ClientTools_02 | Format-Table 



# Cloning the Azure Arc Jumpstart git repository
Write-Output "Clonning the Azure Arc Jumpstart git repository"
git clone https://github.com/microsoft/azure_arc.git "C:\ArcBox\azure_arc"

New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'
New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'

# Creating PowerShell sql_connectivity Script
$sql_connectivity = @'
Start-Transcript "C:\ArcBox\sql_connectivity.log"
New-Item -Path "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
Start-Transcript "C:\ArcBox\sql_connectivity.log"
New-Item -Path "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
# Retreving SQL Managed Instance IP
azdata arc sql mi list | Tee-Object "C:\ArcBox\sql_instance_list.txt"
$lines = Get-Content "C:\ArcBox\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\ArcBox\sql_instance_list.txt"
$lines = Get-Content "C:\ArcBox\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\ArcBox\sql_instance_list.txt"
$s = Get-Content "C:\ArcBox\sql_instance_list.txt"
$s.Substring(0, $s.LastIndexOf(':')) | Out-File "C:\ArcBox\sql_instance_list.txt"
$s = Get-Content "C:\ArcBox\sql_instance_list.txt"
$s.Split(' ')[-1] | Out-File -FilePath "C:\ArcBox\merge.txt" -Encoding ascii -NoNewline
# Retreving SQL Managed Instance FQDN
azdata arc sql mi list | Tee-Object "C:\ArcBox\sql_instance_list.txt"
$lines = Get-Content "C:\ArcBox\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\ArcBox\sql_instance_list.txt"
$lines = Get-Content "C:\ArcBox\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\ArcBox\sql_instance_list.txt"
$s = Get-Content "C:\ArcBox\sql_instance_list.txt"
$s.Substring(0, $s.IndexOf(' ')) | Out-File "C:\ArcBox\sql_instance_list.txt"
$s = Get-Content "C:\ArcBox\sql_instance_list.txt"
Add-Content -Path "C:\ArcBox\merge.txt" -Value ("   ",$s) -Encoding ascii -NoNewline
# Adding SQL Instance FQDN & IP to Hosts file
Copy-Item -Path "C:\Windows\System32\drivers\etc\hosts" -Destination "C:\ArcBox\hosts_backup" -Recurse -Force -ErrorAction Continue
$s = Get-Content "C:\ArcBox\merge.txt"
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value $s -Encoding ascii
# Retreving SQL Managed Instance FQDN & Port
azdata arc sql mi list | Tee-Object "C:\ArcBox\sql_instance_list.txt"
$lines = Get-Content "C:\ArcBox\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\ArcBox\sql_instance_list.txt"
$lines = Get-Content "C:\ArcBox\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\ArcBox\sql_instance_list.txt"
$s = Get-Content "C:\ArcBox\sql_instance_list.txt"
$s.Substring(0, $s.LastIndexOf(':')) | Out-File "C:\ArcBox\sql_instance_list.txt"
$s = Get-Content "C:\ArcBox\sql_instance_list.txt"
$s.Split(' ')[-1] | Out-File -FilePath "C:\ArcBox\sql_instance_settings.txt" -Encoding ascii -NoNewline
# Creating Azure Data Studio settings for SQL Managed Instance connection
Copy-Item -Path "C:\ArcBox\settings_template.json" -Destination "C:\ArcBox\settings_template_backup.json" -Recurse -Force -ErrorAction Continue
$s = Get-Content "C:\ArcBox\sql_instance_settings.txt"
(Get-Content -Path "C:\ArcBox\settings_template.json" -Raw) -replace 'arc_sql_mi',$s | Set-Content -Path "C:\ArcBox\settings_template.json"
(Get-Content -Path "C:\ArcBox\settings_template.json" -Raw) -replace 'sa_username',$env:AZDATA_USERNAME | Set-Content -Path "C:\ArcBox\settings_template.json"
(Get-Content -Path "C:\ArcBox\settings_template.json" -Raw) -replace 'sa_password',$env:AZDATA_PASSWORD | Set-Content -Path "C:\ArcBox\settings_template.json"
(Get-Content -Path "C:\ArcBox\settings_template.json" -Raw) -replace 'false','true' | Set-Content -Path "C:\ArcBox\settings_template.json"
Copy-Item -Path "C:\ArcBox\settings_template.json" -Destination "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json" -Recurse -Force -ErrorAction Continue
# Cleaning garbage
Remove-Item "C:\ArcBox\sql_instance_settings.txt" -Force
Remove-Item "C:\ArcBox\sql_instance_list.txt" -Force
Remove-Item "C:\ArcBox\merge.txt" -Force
# Downloading demo database
$podname = "$env:MSSQL_MI_NAME" + "-0"
kubectl exec $podname -n $env:ARC_DC_NAME -c arc-sqlmi -- wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak -O /var/opt/mssql/data/AdventureWorks2019.bak
kubectl exec $podname -n $env:ARC_DC_NAME -c arc-sqlmi -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $env:AZDATA_USERNAME -P $env:AZDATA_PASSWORD -Q "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2017' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2017_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'"
Stop-Transcript
'@ > C:\ArcBox\sql_connectivity.ps1

# Creating Data Services Logon Script
$DataServicesLogonScript = @'
Start-Transcript -Path C:\ArcBox\DataServicesLogonScript.log
$azurePassword = ConvertTo-SecureString $env:SPN_CLIENT_SECRET -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($env:SPN_CLIENT_ID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $env:SPN_TENANT_ID -ServicePrincipal
Import-AzAksCredential -ResourceGroupName $env:resourceGroup -Name $env:clusterName -Force
kubectl get nodes
azdata --version
Write-Host "Installing Azure Data Studio Extensions"
Write-Host "`n"
$env:argument1="--install-extension"
$env:argument2="Microsoft.arc"
$env:argument3="microsoft.azuredatastudio-postgresql"
& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $env:argument1 $env:argument2
& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $env:argument1 $env:argument3
Write-Host "Creating Azure Data Studio Desktop shortcut"
Write-Host "`n"
$TargetFile = "C:\Program Files\Azure Data Studio\azuredatastudio.exe"
$ShortcutFile = "C:\Users\$env:adminUsername\Desktop\Azure Data Studio.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()
# Deploying Azure Arc Data Controller
start PowerShell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; sleep 5; clear }}
azdata arc dc config init --source azure-arc-aks-premium-storage --path ./custom
if(($env:DOCKER_REGISTRY -ne $NULL) -or ($env:DOCKER_REGISTRY -ne ""))
{
    azdata arc dc config replace --path ./custom/control.json --json-values "spec.docker.registry=$env:DOCKER_REGISTRY"
}
if(($env:DOCKER_REPOSITORY -ne $NULL) -or ($env:DOCKER_REPOSITORY -ne ""))
{
    azdata arc dc config replace --path ./custom/control.json --json-values "spec.docker.repository=$env:DOCKER_REPOSITORY"
}
if(($env:DOCKER_TAG -ne $NULL) -or ($env:DOCKER_TAG -ne ""))
{
    azdata arc dc config replace --path ./custom/control.json --json-values "spec.docker.imageTag=$env:DOCKER_TAG"
}
azdata arc dc create --namespace $env:ARC_DC_NAME --name $env:ARC_DC_NAME --subscription $env:ARC_DC_SUBSCRIPTION --resource-group $env:resourceGroup --location $env:ARC_DC_REGION --connectivity-mode direct --path ./custom
# Deploying Azure Arc SQL Managed Instance
azdata login --namespace $env:ARC_DC_NAME
azdata arc sql mi create --name $env:MSSQL_MI_NAME --storage-class-data managed-premium --storage-class-logs managed-premium
azdata arc sql mi list
# Creating MSSQL Instance connectivity details
Start-Process powershell -ArgumentList "C:\ArcBox\sql_connectivity.ps1" -WindowStyle Hidden -Wait
Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$false
Stop-Transcript
# Starting Azure Data Studio
Start-Process -FilePath "C:\Program Files\Azure Data Studio\azuredatastudio.exe" -WindowStyle Maximized
Stop-Process -Name powershell -Force
'@ > C:\ArcBox\DataServicesLogonScript.ps1

# Creating scheduled task for LogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\ArcBox\LogonScript.ps1'
Register-ScheduledTask -TaskName "LogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Creating scheduled task for DataServicesLogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\ArcBox\DataServicesLogonScript.ps1'
Register-ScheduledTask -TaskName "DataServicesLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

# Install Hyper-V and reboot
Write-Host "Installing Hyper-V and restart"
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart