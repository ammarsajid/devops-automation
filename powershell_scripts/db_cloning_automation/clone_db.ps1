
param(
[Parameter(Mandatory=$True)]
[string]$sdb,
[Parameter(Mandatory=$True)]
[string]$ddb
)

#$sdb = "testing_prod"
#$ddb = "testing_stg"
#$subscriptionId = "cac601c4-4a4f-4aa3-939e-2923e23b1cd6"
#$curDir = "D:\Techlogix\GitLab\Cloudops-09-25-18\cloudops\powershell_scripts\db_cloning_automation"

$curDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$dbFilePath = $curDir + "\andatabases.json"
$allDbsJson = ConvertFrom-Json "$(get-content $dbFilePath)"

Login-AzureRmAccount
Select-AzureRmSubscription -SubscriptionID $allDbsJson.subscriptionId

# Storage account info for the BACPAC
$BaseStorageUri = "https://ancloudops.blob.core.windows.net/dbbackups/"
$StorageKeytype = "StorageAccessKey"
$StorageKey = "VHt9S600ZjY4qfUb0iWyC6Rswf6uVDSsoIIicY4n5GDyiIjJ/rE4GRV9meAZvk9L97IqzNfQr2m1u51beCP2wQ=="

#$creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $serverAdmin, $securePassword

$bacpacFilename = $allDbsJson.Databases.$ddb.dbname + (Get-Date).ToString("yyyy-MM-dd-HH-mm") + ".bacpac"
$BacpacUri = $BaseStorageUri + $bacpacFilename
$exportRequest = New-AzureRmSqlDatabaseExport -ResourceGroupName $allDbsJson.Databases.$ddb.resourcegroup $allDbsJson.Databases.$ddb.server `
                    -DatabaseName $allDbsJson.Databases.$ddb.dbname -StorageKeytype $StorageKeytype -StorageKey $StorageKey -StorageUri $BacpacUri `
                    -AdministratorLogin $allDbsJson.Credentials.($allDbsJson.Databases.$ddb.server).username `
                    -AdministratorLoginPassword ($allDbsJson.Credentials.($allDbsJson.Databases.$ddb.server).password | ConvertTo-SecureString -AsPlainText -Force )

Write-Output "Backup is in progress for $allDbsJson.Databases.$ddb.dbname"   
$exportStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $exportRequest.OperationStatusLink
while ($exportStatus.Status -ne 'Succeeded')
{
    start-sleep -s 5
    $exportStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $exportRequest.OperationStatusLink
    Write-Output "Backup is in progress for $allDbsJson.Databases.$ddb.dbname"
}

Write-Host "Backup completed, URL:" $BacpacUri -ForegroundColor Yellow

Write-Host "Deleting database" $allDbsJson.Databases.$ddb.dbname -ForegroundColor Yellow

Remove-AzureRmSqlDatabase -ResourceGroupName $allDbsJson.Databases.$ddb.resourcegroup -ServerName $allDbsJson.Databases.$ddb.server `
    -DatabaseName $allDbsJson.Databases.$ddb.dbname -Force

# Copy source database to the target server 
$databasecopy = New-AzureRmSqlDatabaseCopy -ResourceGroupName $allDbsJson.Databases.$sdb.resourcegroup -ServerName $allDbsJson.Databases.$sdb.server `
                    -DatabaseName $allDbsJson.Databases.$sdb.dbname -CopyResourceGroupName $allDbsJson.Databases.$ddb.resourcegroup `
                    -CopyServerName $allDbsJson.Databases.$ddb.server -CopyDatabaseName $allDbsJson.Databases.$ddb.dbname `
                    -ServiceObjectiveName "S0"
