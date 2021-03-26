Start-Transcript -Path C:\ArcBox\DataServicesLogonScript.log
$azurePassword = ConvertTo-SecureString $env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($env:spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $env:spnTenantId -ServicePrincipal
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
start PowerShell {for (0 -lt 1) {kubectl get pod -n $env:arcDcName; sleep 5; clear }}
azdata arc dc config init --source azure-arc-aks-premium-storage --path ./custom
if(($env:dockerRegistry -ne $NULL) -or ($env:dockerRegistry -ne ""))
{
    azdata arc dc config replace --path ./custom/control.json --json-values "spec.docker.registry=$env:dockerRegistry"
}
if(($env:dockerRepository -ne $NULL) -or ($env:dockerRepository -ne ""))
{
    azdata arc dc config replace --path ./custom/control.json --json-values "spec.docker.repository=$env:dockerRepository"
}
if(($env:dockerTag -ne $NULL) -or ($env:dockerTag -ne ""))
{
    azdata arc dc config replace --path ./custom/control.json --json-values "spec.docker.imageTag=$env:dockerTag"
}
azdata arc dc create --namespace $env:arcDcName --name $env:arcDcName --subscription $env:subscriptionId --resource-group $env:resourceGroup --location $env:azureLocation --connectivity-mode direct --path ./custom
# Deploying Azure Arc SQL Managed Instance
azdata login --namespace $env:arcDcName
azdata arc sql mi create --name $env:mssqlmiName --storage-class-data managed-premium --storage-class-logs managed-premium
azdata arc sql mi list

# Set up SQL Connectivity and install sample Adventureworks database
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
(Get-Content -Path "C:\ArcBox\settings_template.json" -Raw) -replace 'sa_username',$env:azdataUsername | Set-Content -Path "C:\ArcBox\settings_template.json"
(Get-Content -Path "C:\ArcBox\settings_template.json" -Raw) -replace 'sa_password',$env:azdataPassword | Set-Content -Path "C:\ArcBox\settings_template.json"
(Get-Content -Path "C:\ArcBox\settings_template.json" -Raw) -replace 'false','true' | Set-Content -Path "C:\ArcBox\settings_template.json"
Copy-Item -Path "C:\ArcBox\settings_template.json" -Destination "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json" -Recurse -Force -ErrorAction Continue
# Cleaning garbage
Remove-Item "C:\ArcBox\sql_instance_settings.txt" -Force
Remove-Item "C:\ArcBox\sql_instance_list.txt" -Force
Remove-Item "C:\ArcBox\merge.txt" -Force
# Downloading demo database
$podname = "$env:mssqlmiName" + "-0"
kubectl exec $podname -n $env:arcDcName -c arc-sqlmi -- wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak -O /var/opt/mssql/data/AdventureWorks2019.bak
kubectl exec $podname -n $env:arcDcName -c arc-sqlmi -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $env:azdataUsername -P $env:azdataPassword -Q "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2017' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2017_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'"

# Starting Azure Data Studio
Start-Process -FilePath "C:\Program Files\Azure Data Studio\azuredatastudio.exe" -WindowStyle Maximized
Stop-Process -Name powershell -Force