
param(
[Parameter(Mandatory=$True)]
[string]$ddb,
[Parameter(Mandatory=$False)]
[string]$sdb,
[Parameter(Mandatory=$False)]
[switch]$backupOnly,
[Parameter(Mandatory=$False)]
[string]$restoreURL,
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
$allDbsJson = ConvertFrom-Json "$(get-content $dbFilePath)"

#Login to Azure Account
Login-AzureRmAccount
Select-AzureRmSubscription -SubscriptionID $allDbsJson.SubscriptionId

if(-not($new))
{
    # Storage account info to store BACPAC
    $BaseStorageUri = "https://" + $allDbsJson.StorageAccName + ".blob.core.windows.net/" + $allDbsJson.StorageContainer + "/"
    $bacpacFilename = $allDbsJson.Databases.$ddb.dbname + "-" + (Get-Date).ToString("yyyy-MM-dd-HH-mm") + ".bacpac"
    $BacpacUri = $BaseStorageUri + $bacpacFilename
    $storageContextDest = New-AzureStorageContext -StorageAccountName $allDbsJson.StorageAccName -StorageAccountKey $allDbsJson.StorageKey

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

    
    if(-not($backupOnly))
    {
        Write-Host "Deleting database" $allDbsJson.Databases.$ddb.dbname -ForegroundColor Yellow
        Remove-AzureRmSqlDatabase -ResourceGroupName $allDbsJson.Databases.$ddb.resourcegroup -ServerName $allDbsJson.Databases.$ddb.server `
            -DatabaseName $allDbsJson.Databases.$ddb.dbname -Force -Confirm
    
        if($restoreURL)
        {
            $importRequest = New-AzureRmSqlDatabaseImport -ResourceGroupName $allDbsJson.Databases.$ddb.resourcegroup -ServerName $allDbsJson.Databases.$ddb.server `
                             -DatabaseName $allDbsJson.Databases.$ddb.dbname -StorageKeyType $allDbsJson.StorageKeytype -StorageKey $allDbsJson.StorageKey `
                             -AdministratorLogin $allDbsJson.Server_credentials.($allDbsJson.Databases.$ddb.server).username `
                             -AdministratorLoginPassword  ($allDbsJson.Server_credentials.($allDbsJson.Databases.$ddb.server).password | ConvertTo-SecureString -AsPlainText -Force )`
                             -StorageUri $restoreURL –Edition Standard –ServiceObjectiveName S0 -DatabaseMaxSizeBytes 200000000

            [int]$impStatusctr = 0
            $impStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
            while ($impStatus.Status -ne 'Succeeded')
            {
                Write-Host "Restoration of" $($allDbsJson.Databases.$ddb.dbname) "is in progress" 
                start-sleep -Milliseconds 300
                $impStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
            
            }
        }
    }

}

if(-not($backupOnly))
{
    
    if(!$restoreURL)
    {
        Write-Host "Copying database to destination" -ForegroundColor Yellow

        if($ssub)
        {
            $dbFilePathSrc = $curDir + "\"+$ssub+ ".json"
            $allDbsJsonSrc = ConvertFrom-Json "$(get-content $dbFilePathSrc)"
            Select-AzureRmSubscription -SubscriptionID $allDbsJsonSrc.SubscriptionId
        
            # Storage account info to store BACPAC
            $BaseStorageUriSrc = "https://" + $allDbsJsonSrc.StorageAccName + ".blob.core.windows.net/" + $allDbsJsonSrc.StorageContainer + "/"
            $bacpacFilenameSrc = $allDbsJsonSrc.Databases.$sdb.dbname + "-" + (Get-Date).ToString("yyyy-MM-dd-HH-mm") + ".bacpac"
            $BacpacUriSrc = $BaseStorageUriSrc + $bacpacFilenameSrc
            $storageContextSrc = New-AzureStorageContext -StorageAccountName $allDbsJsonSrc.StorageAccName -StorageAccountKey $allDbsJsonSrc.StorageKey
       
            # exporting db to bacpac
            $exportRequest = New-AzureRmSqlDatabaseExport -ResourceGroupName $allDbsJsonSrc.Databases.$sdb.resourcegroup $allDbsJsonSrc.Databases.$sdb.server `
                                -DatabaseName $allDbsJsonSrc.Databases.$sdb.dbname -StorageKeytype $allDbsJsonSrc.StorageKeytype -StorageKey $allDbsJsonSrc.StorageKey `
                                -StorageUri $BacpacUriSrc -AdministratorLogin $allDbsJsonSrc.Server_credentials.($allDbsJsonSrc.Databases.$sdb.server).username `
                                -AdministratorLoginPassword ($allDbsJsonSrc.Server_credentials.($allDbsJsonSrc.Databases.$sdb.server).password | ConvertTo-SecureString -AsPlainText -Force )

            Write-Host "Backup of" $allDbsJsonSrc.Databases.$sdb.dbname "is in progress" 
            $exportStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $exportRequest.OperationStatusLink
            while ($exportStatus.Status -ne 'Succeeded')
            {
                start-sleep -s 5
                $exportStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $exportRequest.OperationStatusLink
                Write-Host "Backup of" $allDbsJsonSrc.Databases.$sdb.dbname "is in progress" 
            }

            Select-AzureRmSubscription -SubscriptionID $allDbsJson.SubscriptionId
            $importRequest = New-AzureRmSqlDatabaseImport -ResourceGroupName $allDbsJson.Databases.$ddb.resourcegroup -ServerName $allDbsJson.Databases.$ddb.server `
                             -DatabaseName $allDbsJson.Databases.$ddb.dbname -StorageKeyType $allDbsJsonSrc.StorageKeytype -StorageKey $allDbsJsonSrc.StorageKey `
                             -AdministratorLogin $allDbsJson.Server_credentials.($allDbsJson.Databases.$ddb.server).username `
                             -AdministratorLoginPassword  ($allDbsJson.Server_credentials.($allDbsJson.Databases.$ddb.server).password | ConvertTo-SecureString -AsPlainText -Force )`
                             -StorageUri $BacpacUriSrc –Edition Standard –ServiceObjectiveName S0 -DatabaseMaxSizeBytes 200000000

            [int]$impStatusctr = 0
            $impStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
            while ($impStatus.Status -ne 'Succeeded')
            {
                Write-Host "Restoration of" $($allDbsJson.Databases.$ddb.dbname) "is in progress" 
                start-sleep -Milliseconds 300
                $impStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
            
            }
 
        }
        else
        {
            $databasecopy = New-AzureRmSqlDatabaseCopy -ResourceGroupName $allDbsJson.Databases.$sdb.resourcegroup -ServerName $allDbsJson.Databases.$sdb.server `
                                -DatabaseName $allDbsJson.Databases.$sdb.dbname -CopyResourceGroupName $allDbsJson.Databases.$ddb.resourcegroup `
                                -CopyServerName $allDbsJson.Databases.$ddb.server -CopyDatabaseName $allDbsJson.Databases.$ddb.dbname `
                                -ServiceObjectiveName "S0"
        }
    
    }
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