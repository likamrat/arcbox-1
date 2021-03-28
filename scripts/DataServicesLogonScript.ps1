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
Start-Sleep -s 30

New-Item -Path "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force

# Deploying Azure Arc PostgreSQL Hyperscale Server Group
azdata login --namespace $env:arcDcName
azdata arc postgres server create --name $env:POSTGRES_NAME --workers $env:POSTGRES_WORKER_NODE_COUNT --storage-class-data managed-premium --storage-class-logs managed-premium
azdata arc postgres endpoint list --name $env:POSTGRES_NAME


# Retreving PostgreSQL Server IP
azdata arc postgres endpoint list --name $env:POSTGRES_NAME | Tee-Object "C:\ArcBox\postgres_instance_endpoint.txt"
Get-Content "C:\ArcBox\postgres_instance_endpoint.txt" | Where-Object {$_ -match '@'} | Set-Content "C:\ArcBox\out.txt"
$s = Get-Content "C:\ArcBox\out.txt" 
$s.Split('@')[-1] | Out-File "C:\ArcBox\out.txt"
$s = Get-Content "C:\ArcBox\out.txt"
$s.Substring(0, $s.IndexOf(':')) | Out-File -FilePath "C:\ArcBox\merge.txt" -Encoding ascii -NoNewline
# Retreving PostgreSQL Server Name
Add-Content -Path "C:\ArcBox\merge.txt" -Value ("   ","postgres") -Encoding ascii -NoNewline
# Adding PostgreSQL Server Name & IP to Hosts file
Copy-Item -Path "C:\Windows\System32\drivers\etc\hosts" -Destination "C:\ArcBox\hosts_backup" -Recurse -Force -ErrorAction Continue
$s = Get-Content "C:\ArcBox\merge.txt"
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value $s -Encoding ascii
# Creating Azure Data Studio settings for PostgreSQL connection
azdata arc postgres endpoint list --name $env:POSTGRES_NAME | Tee-Object "C:\ArcBox\postgres_instance_endpoint.txt"
Copy-Item -Path "C:\ArcBox\settings_template.json" -Destination "C:\ArcBox\settings_template_backup.json" -Recurse -Force -ErrorAction Continue
Get-Content "C:\ArcBox\postgres_instance_endpoint.txt" | Where-Object {$_ -match '@'} | Set-Content "C:\ArcBox\out.txt"
$s = Get-Content "C:\ArcBox\out.txt" 
$s.Split('@')[-1] | Out-File "C:\ArcBox\out.txt"
$s = Get-Content "C:\ArcBox\out.txt"
$s.Substring(0, $s.IndexOf(':')) | Out-File -FilePath "C:\ArcBox\merge.txt" -Encoding ascii -NoNewline
$s = (Get-Content "C:\ArcBox\merge.txt").Trim()
(Get-Content -Path "C:\ArcBox\settings_template.json" -Raw) -replace 'arc_postgres',$s | Set-Content -Path "C:\ArcBox\settings_template.json"
(Get-Content -Path "C:\ArcBox\settings_template.json" -Raw) -replace 'ps_password',$env:AZDATA_PASSWORD | Set-Content -Path "C:\ArcBox\settings_template.json"
(Get-Content -Path "C:\ArcBox\settings_template.json" -Raw) -replace 'false','true' | Set-Content -Path "C:\ArcBox\settings_template.json"
Copy-Item -Path "C:\ArcBox\settings_template.json" -Destination "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json" -Recurse -Force -ErrorAction Continue
# Cleaning garbage
Remove-Item "C:\ArcBox\postgres_instance_endpoint.txt" -Force
Remove-Item "C:\ArcBox\merge.txt" -Force
Remove-Item "C:\ArcBox\out.txt" -Force
# Restoring demo database
$podname = "$env:POSTGRES_NAME" + "c-0"
kubectl exec $podname -n $env:ARC_DC_NAME -c postgres -- /bin/bash -c "cd /tmp && curl -k -Ohttps://raw.githubusercontent.com/dkirby-ms/arcbox/main/scripts/AdventureWorks.sql"
kubectl exec $podname -n $env:ARC_DC_NAME -c postgres -- sudo -u postgres psql -c 'CREATE DATABASE "adventureworks";' postgres
kubectl exec $podname -n $env:ARC_DC_NAME -c postgres -- sudo -u postgres psql -d adventureworks -f /tmp/AdventureWorks.sql

# Deploying Azure Arc SQL Managed Instance
# azdata login --namespace $env:arcDcName
# azdata arc sql mi create --name $env:mssqlmiName --storage-class-data managed-premium --storage-class-logs managed-premium

# azdata arc sql mi list

# Downloading demo database and restoring onto SQL MI
# $podname = "$env:mssqlMiName" + "-0"
# Start-Sleep -Seconds 300
# Write-Host "Ready to go!"
# kubectl exec $podname -n $env:ARC_DC_NAME -c arc-sqlmi -- wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak -O /var/opt/mssql/data/AdventureWorks2019.bak
# Start-Sleep -Seconds 5
# kubectl exec $podname -n $env:ARC_DC_NAME -c arc-sqlmi -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $env:AZDATA_USERNAME -P $env:AZDATA_PASSWORD -Q "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2017' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2017_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'"

# Write-Host ""
# Write-Host "Creating Azure Data Studio settings for SQL Managed Instance connection"
# Copy-Item -Path "C:\ArcBox\settings_template.json" -Destination "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"
# $settingsFile = "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"
# azdata arc sql mi list | Tee-Object "C:\ArcBox\sql_instance_list.txt"
# $file = "C:\ArcBox\sql_instance_list.txt"
# (Get-Content $file | Select-Object -Skip 2) | Set-Content $file
# $string = Get-Content $file
# $string.Substring(0, $string.IndexOf(',')) | Set-Content $file
# $sql = Get-Content $file

# (Get-Content -Path $settingsFile) -replace 'arc_sql_mi',$sql | Set-Content -Path $settingsFile
# (Get-Content -Path $settingsFile) -replace 'sa_username',$env:AZDATA_USERNAME | Set-Content -Path $settingsFile
# (Get-Content -Path $settingsFile) -replace 'sa_password',$env:AZDATA_PASSWORD | Set-Content -Path $settingsFile
# (Get-Content -Path $settingsFile) -replace 'false','true' | Set-Content -Path $settingsFile

# Starting Azure Data Studio
Start-Process -FilePath "C:\Program Files\Azure Data Studio\azuredatastudio.exe" -WindowStyle Maximized
Stop-Process -Name powershell -Force

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "DataServicesLogonScript" -Confirm:$false