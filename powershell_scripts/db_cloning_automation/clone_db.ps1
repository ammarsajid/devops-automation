
param(
[Parameter(Mandatory=$True)]
[string]$ddb,
[Parameter(Mandatory=$False)]
[string]$sdb,
[Parameter(Mandatory=$False)]
[switch]$backupOnly,
[Parameter(Mandatory=$False)]
[switch]$new,
[Parameter(Mandatory=$True)]
[ValidateSet('an','tmx','vic','sp')]
[System.String]$dsub,
[Parameter(Mandatory=$False)]
[ValidateSet('an','tmx','vic','sp')]
[System.String]$ssub

)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Getting database information from json file
$curDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

$dbFilePath = $curDir + "\"+$dsub+ ".json"
$dbFilePath = "D:\Techlogix\GitLab\Cloudops-09-25-18\cloudops\powershell_scripts\db_cloning_automation\an.json"
$allDbsJson = ConvertFrom-Json "$(get-content $dbFilePath)"

#Login to Azure Account
# Login-AzureRmAccount
Select-AzureRmSubscription -SubscriptionID $allDbsJson.SubscriptionId

if(-not($new))
{
    # Storage account info to store BACPAC
    # https://ancloudops.blob.core.windows.net/dbbackups2/BRAINS-prod-from-zain.bacpac
    $BaseStorageUri = "https://" + $allDbsJson.StorageAccName + ".blob.core.windows.net/" + $allDbsJson.StorageContainer + "/"
    #$StorageKeytype = $allDbsJson.StorageKeytype
    #$StorageKey = $allDbsJson.StorageKey
    $bacpacFilename = $allDbsJson.Databases.$ddb.dbname + (Get-Date).ToString("yyyy-MM-dd-HH-mm") + ".bacpac"
    $BacpacUri = $BaseStorageUri +"-"+ $bacpacFilename

    # exporting db to bacpac
    $exportRequest = New-AzureRmSqlDatabaseExport -ResourceGroupName $allDbsJson.Databases.$ddb.resourcegroup $allDbsJson.Databases.$ddb.server `
                        -DatabaseName $allDbsJson.Databases.$ddb.dbname -StorageKeytype $allDbsJson.StorageKeytype -StorageKey $allDbsJson.StorageKey `
                        -StorageUri $BacpacUri -AdministratorLogin $allDbsJson.Server_credentials.($allDbsJson.Databases.$ddb.server).username `
                        -AdministratorLoginPassword ($allDbsJson.Server_credentials.($allDbsJson.Databases.$ddb.server).password | ConvertTo-SecureString -AsPlainText -Force )

    Write-Host "Backup of" $allDbsJson.Databases.$ddb.dbname "is in progress" 
    $exportStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $exportRequest.OperationStatusLink
    while ($exportStatus.Status -ne 'Succeeded')
    {
        start-sleep -s 5
        $exportStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $exportRequest.OperationStatusLink
        Write-Host "Backup of" $allDbsJson.Databases.$ddb.dbname "is in progress" 
    }

    Write-Host "Backup completed, URL:" $BacpacUri -ForegroundColor Green
}

if(-not($backupOnly))
{
    if(-not($new))
    {
        Write-Host "Deleting database" $allDbsJson.Databases.$ddb.dbname -ForegroundColor Yellow
        Remove-AzureRmSqlDatabase -ResourceGroupName $allDbsJson.Databases.$ddb.resourcegroup -ServerName $allDbsJson.Databases.$ddb.server `
            -DatabaseName $allDbsJson.Databases.$ddb.dbname -Force
    }
    Write-Host "Copying database to destination" -ForegroundColor Yellow

    # Copy source database to the target server


    $databasecopy = New-AzureRmSqlDatabaseCopy -ResourceGroupName $allDbsJson.Databases.$sdb.resourcegroup -ServerName $allDbsJson.Databases.$sdb.server `
                        -DatabaseName $allDbsJson.Databases.$sdb.dbname -CopyResourceGroupName $allDbsJson.Databases.$ddb.resourcegroup `
                        -CopyServerName $allDbsJson.Databases.$ddb.server -CopyDatabaseName $allDbsJson.Databases.$ddb.dbname `
                        -ServiceObjectiveName "S0"

    start-sleep -s 1
    # Adding to the respective elastic pool
    Write-Host "Adding database to Elastic Pool if any" -ForegroundColor Yellow
    if ($allDbsJson.Server_credentials.($allDbsJson.Databases.$ddb.server).ElasticPoolName -ne "NA")
    {
        Set-AzureRmSqlDatabase -ResourceGroupName $allDbsJson.Databases.$ddb.resourcegroup `
        -ServerName $allDbsJson.Databases.$ddb.server -DatabaseName $allDbsJson.Databases.$ddb.dbname `
        -ElasticPoolName $allDbsJson.Server_credentials.($allDbsJson.Databases.$ddb.server).ElasticPoolName
    }
    

}