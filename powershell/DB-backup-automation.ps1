param (
   
    [Parameter(Position=1)]
    [switch]$new,

    [Parameter(Position=2)]
    [switch]$existing

)
   

try 
{
    $AzureSubscriptionIdSource =     (Get-AzureRmSubscription | Out-GridView -Title 'Select an Azure source Subscription' -OutputMode Single)
    Set-AzureRmContext -SubscriptionID $AzureSubscriptionIdSource
}
catch 
{
    Login-AzureRmAccount
    $AzureSubscriptionIdSource =     (Get-AzureRmSubscription | Out-GridView -Title 'Select an Azure source Subscription' -OutputMode Single)
    Set-AzureRmContext -SubscriptionID $AzureSubscriptionIdSource
}

$resourcegroupnames= Get-AzureRmResourceGroup
$sqlServerSource = @()
$sqlDBSource = @()

   foreach($resourcegroupname in $resourcegroupnames)
   {
      $resourcegroup = $resourcegroupname.ResourceGroupName
      $sqlServerSource = Get-AzureRmSqlserver -ResourceGroupName $resourcegroup
     foreach($serversource in $sqlServerSource)
      {
        $sqlDBSource +=Get-AzureRmSqlDatabase -ResourceGroupName $resourcegroup -ServerName $serversource.ServerName | where {$_.DatabaseName -ne 'master'}
      } 
   }
   $sqldatabasesrc =$sqlDBSource | Out-GridView  -Title 'Select a source DB to export' -OutputMode Single
   $sqlserverscr = Get-AzureRmSqlserver -ServerName $sqldatabasesrc.ServerName -ResourceGroupName $sqldatabasesrc.ResourceGroupName
   $sqlServerAdminSource = $sqlserverscr.SqlAdministratorLogin
   $securePasswordSource = Read-Host "Enter in the password for $sqlServerAdminSource" -AsSecureString

   $credsSource = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sqlServerAdminSource, $securePasswordSource
 
  # Generate a unique filename for the BACPAC of source
    $sqldatabasesrcname = $sqldatabasesrc.databasename
    $bacpacFilenameSource =  $sqldatabasesrcname + (Get-Date).ToString("yyyyMMddHHmm") + ".bacpac"

  # Storage account source info for the BACPAC
    $storageAcctSource = Get-AzureRmStorageAccount | Out-GridView -Title 'Select a Source Storage Account' -OutputMode Single
    $storageAcctKeySource = (Get-AzureRmStorageAccountKey -ResourceGroupName $storageAcctSource.ResourceGroupName -name $storageAcctSource.StorageAccountName)[0].value
    $storageContextSource = New-AzureStorageContext -StorageAccountName $storageAcctSource.StorageAccountName -StorageAccountKey $storageAcctKeySource
    $storageContainerSource = Get-AzureStorageContainer -Context $storageContextSource | select Name | Out-GridView  -Title 'Select a source Container..' -OutputMode Single

    $BaseStorageUriSource = "$($storageAcctSource.PrimaryEndpoints.Blob)$($storageContainerSource.Name)/"

    $BacpacUriSource = $BaseStorageUriSource + $bacpacFilenameSource

     if($PSBoundParameters.ContainsKey('new'))
 {
  # Select All Variables for new creating database

      try 
    {
    $AzureSubscriptionIdNew =     (Get-AzureRmSubscription | Out-GridView -Title 'Select a Azure Subscription' -OutputMode Single)
    Set-AzureRmContext -SubscriptionID $AzureSubscriptionIdNew
    }
    catch 
    {
    Login-AzureRmAccount
    $AzureSubscriptionIdNew =     (Get-AzureRmSubscription | Out-GridView -Title 'Select a Azure Subscription' -OutputMode Single)
    Set-AzureRmContext -SubscriptionID $AzureSubscriptionIdNew
} 
  
   $resourcegroupdes= Get-AzureRmResourceGroup
   $sqlServerSource = @()
   
   foreach($resourcegroupname in $resourcegroupdes)
   {
      $resourcegroup = $resourcegroupname.ResourceGroupName
      $sqlServerSource += Get-AzureRmSqlserver -ResourceGroupName $resourcegroup
    
   }

    $sqlServerNew =$sqlServerSource| Out-GridView  -Title 'Select your New Azure SQL Server'  -OutputMode Single

    $serverinstace = $sqlServerNew.ServerName+".database.windows.net"

    $sqlDBNew = Read-Host "Enter the name of new database " 
   
    $sqlServerAdminNew = $sqlServerNew.SqlAdministratorLogin

    $securePasswordNew = Read-Host "Enter in the password for $sqlServerAdminNew" -AsSecureString

    $credsNew = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sqlServerAdminNew, $securePasswordNew

    $storageAcctNew = Get-AzureRmStorageAccount | Out-GridView -Title 'Select a New Storage Account' -OutputMode Single
    $storageAcctKeyNew = (Get-AzureRmStorageAccountKey -ResourceGroupName $storageAcctNew.ResourceGroupName -name $storageAcctNew.StorageAccountName)[0].value
    $storageContextNew = New-AzureStorageContext -StorageAccountName $storageAcctNew.StorageAccountName -StorageAccountKey $storageAcctKeyNew
    $storageContainerNew = Get-AzureStorageContainer -Context $storageContextNew | select Name | Out-GridView  -Title 'Select a New Container..' -OutputMode Single
    $BaseStorageUriNew = "$($storageAcctNew.PrimaryEndpoints.Blob)$($storageContainerNew.Name)/"


    #user creation ger credentails
     $user_pass = Get-Credential


     #***************command to backup source***************
    
    Set-AzureRmContext -SubscriptionID $AzureSubscriptionIdSource
        
    $exportRequestSource = New-AzureRmSqlDatabaseExport -ResourceGroupName  $sqldatabasesrc.ResourceGroupName -ServerName $sqldatabasesrc.ServerName `
       -DatabaseName $sqldatabasesrc.DatabaseName -StorageKeytype 'StorageAccessKey' -StorageKey $storageAcctKeySource  -StorageUri $BacpacUriSource `
       -AdministratorLogin $credsSource.UserName -AdministratorLoginPassword $credsSource.Password

        [int]$expStatusctr = 0
        $expStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $exportRequestSource.OperationStatusLink

        while ($expStatus.Status -ne 'Succeeded')
        {
        Write-Progress -Activity "Exporting Database $($sqldatabasesrc.DatabaseName)" -PercentComplete (($expStatusctr / 100) * 100)

        start-sleep -Milliseconds 300
        $expStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $exportRequestSource.OperationStatusLink
            if ($expStatus.StatusMessage)
            {  
            $expStatus = $expStatus.StatusMessage.Split('=') 
            $expStatusctr=$expStatus[1].Trim('%')
            }
        }
    Write-Host "Source Export complete! $BacpacUriSource" -ForegroundColor Green
    
     #Do the copy  of only new created bcpacfile
     $BlobCopy = Start-CopyAzureStorageBlob -Context $storageContextSource -SrcContainer $storageContainerSource.name -SrcBlob  $bacpacFilenameSource -DestContext $storageContextNew -DestContainer $storageContainerNew.name -DestBlob $bacpacFilenameSource -Force   
  
     #Check Status of container changing 
     $CopyState = $BlobCopy | Get-AzureStorageBlobCopyState
     $Message = $CopyState.Source.AbsolutePath + " " + $CopyState.Status + " {0:N2}%" -f (($CopyState.BytesCopied/$CopyState.TotalBytes)*100) 
     Write-Host $Message -ForegroundColor Yellow


   #import new database from .bacpac file of source    
    #get Uri of storage bacpac file
    $bacpacurinew = $BaseStorageUriNew + $bacpacFilenameSource
     
     Set-AzureRmContext -SubscriptionID $AzureSubscriptionIdNew
   
  $importRequest = New-AzureRmSqlDatabaseImport -ResourceGroupName $sqlServerNew.ResourceGroupName -ServerName $sqlServerNew.ServerName -DatabaseName $sqlDBNew -StorageKeyType "StorageAccessKey" -StorageKey $storageAcctKeyNew -AdministratorLogin $credsNew.UserName -AdministratorLoginPassword $credsNew.Password -StorageUri $bacpacurinew –Edition basic –ServiceObjectiveName basic -DatabaseMaxSizeBytes 20000000

   
   #import status  
        [int]$impStatusctr = 0
        $impStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
        while ($impStatus.Status -ne 'Succeeded')
        {
        Write-Progress -Activity "importing Database $($sqlDBNew)" -PercentComplete (($impStatusctr / 100) * 100)

        start-sleep -Milliseconds 300
        $impStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
            if ($impStatus.StatusMessage)
            {  
            $impStatus = $impStatus.StatusMessage.Split('=') 
            $impStatusctr=$impStatus[1].Trim('%')
            }
        }

     #user Creation

    Write-Host " Creation of user on database and giving role";
    $user = $user_pass.UserName
    $pass = $user_pass.GetNetworkCredential().Password

    $serverinstace = $sqlServerNew.ServerName+".database.windows.net"
    $databasemaster = "master"
    $database =$sqlDBNew
    $uid = $credsNew.UserName
    $pwd =$credsNew.GetNetworkCredential().Password
    $SqlQuerymaster = "CREATE LOGIN $user WITH password='$pass';CREATE USER $user FROM LOGIN $user;"
    $SqlQuery = "CREATE USER $user FROM LOGIN $user;EXEC sp_addrolemember 'db_owner', '$user'"

    Invoke-Sqlcmd -Username $uid -Password $pwd -ServerInstance $serverinstace -Database $databasemaster -Query $SqlQuerymaster
    Invoke-Sqlcmd -Username $uid -Password $pwd -ServerInstance $serverinstace -Database $database -Query $SqlQuery
 }

 
     if($PSBoundParameters.ContainsKey('existing'))
 {
  # Select All Variables for destination subscription
   try 
{
    $AzureSubscriptionIdDest =     (Get-AzureRmSubscription | Out-GridView -Title 'Select a destination Azure Subscription' -OutputMode Single)
    Set-AzureRmContext -SubscriptionID $AzureSubscriptionIdDest
}
catch 
{
    Login-AzureRmAccount
    $AzureSubscriptionIdDest =     (Get-AzureRmSubscription | Out-GridView -Title 'Select a destination Azure Subscription' -OutputMode Single)
    Set-AzureRmContext -SubscriptionID $AzureSubscriptionIdDest
}

$resourcegroupdestnames= Get-AzureRmResourceGroup
$sqlServerdest = @()
$sqlDBdest = @()

   foreach($resourcegroupdestname in $resourcegroupdestnames)
   {
      $resourcegroup = $resourcegroupdestname.ResourceGroupName
      $sqlServerdest = Get-AzureRmSqlserver -ResourceGroupName $resourcegroup
     foreach($serverdest in $sqlServerdest)
      {
        $sqlDBdest +=Get-AzureRmSqlDatabase -ResourceGroupName $resourcegroup -ServerName $serverdest.ServerName | where {$_.DatabaseName -ne 'master'}
      } 
   }
   $sqldatabasedst =$sqlDBdest | Out-GridView  -Title 'Select a destination DB to export' -OutputMode Single
   $sqlServerdst = Get-AzureRmSqlserver -ServerName $sqldatabasedst.ServerName -ResourceGroupName $sqldatabasedst.ResourceGroupName
   $sqlServerAdminDest = $sqlServerdst.SqlAdministratorLogin
   $securePasswordDest = Read-Host "Enter in the password for $sqlServerAdminDest" -AsSecureString
    
    $credsDest = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sqlServerAdminDest, $securePasswordDest

    # Generate a unique filename for the destination BACPAC
    $destdatabasename = $sqldatabasedst.databasename
    $bacpacFilenameDest =  $destdatabasename + (Get-Date).ToString("yyyyMMddHHmm") + ".bacpac"

     # Storage account Destination info for the BACPAC
    $storageAcctDest = Get-AzureRmStorageAccount | Out-GridView -Title 'Select a destination Storage Account' -OutputMode Single
    $storageAcctKeyDest = (Get-AzureRmStorageAccountKey -ResourceGroupName $storageAcctDest.ResourceGroupName -name $storageAcctDest.StorageAccountName)[0].value
    $storageContextDest = New-AzureStorageContext -StorageAccountName $storageAcctDest.StorageAccountName -StorageAccountKey $storageAcctKeyDest
    $storageContainerDest = Get-AzureStorageContainer -Context $storageContextDest | select Name | Out-GridView  -Title 'Select a destination Container..' -OutputMode Single
    $BaseStorageUriDest = "$($storageAcctDest.PrimaryEndpoints.Blob)$($storageContainerDest.Name)/"
    
    $BacpacUriDest = $BaseStorageUriDest + $bacpacFilenameDest


    #user creation for database 
    $user_pass = Get-Credential

      #***************command to backup source***************
    
    Set-AzureRmContext -SubscriptionID $AzureSubscriptionIdSource
        
    $exportRequestSource = New-AzureRmSqlDatabaseExport -ResourceGroupName  $sqldatabasesrc.ResourceGroupName -ServerName $sqldatabasesrc.ServerName `
       -DatabaseName $sqldatabasesrc.DatabaseName -StorageKeytype 'StorageAccessKey' -StorageKey $storageAcctKeySource  -StorageUri $BacpacUriSource `
       -AdministratorLogin $credsSource.UserName -AdministratorLoginPassword $credsSource.Password

        [int]$expStatusctr = 0
        $expStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $exportRequestSource.OperationStatusLink

        while ($expStatus.Status -ne 'Succeeded')
        {
        Write-Progress -Activity "Exporting Database $($sqldatabasesrc.DatabaseName)" -PercentComplete (($expStatusctr / 100) * 100)

        start-sleep -Milliseconds 300
        $expStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $exportRequestSource.OperationStatusLink
            if ($expStatus.StatusMessage)
            {  
            $expStatus = $expStatus.StatusMessage.Split('=') 
            $expStatusctr=$expStatus[1].Trim('%')
            }
        }
    Write-Host "Source Export complete! $BacpacUriSource" -ForegroundColor Green

       #***************command to backup Destination*********************

    Set-AzureRmContext -SubscriptionID $AzureSubscriptionIdDest

    $exportRequestDest = New-AzureRmSqlDatabaseExport -ResourceGroupName $sqldatabasedst.ResourceGroupName -ServerName $sqldatabasedst.ServerName `
       -DatabaseName $sqldatabasedst.DatabaseName -StorageKeytype 'StorageAccessKey' -StorageKey $storageAcctKeyDest  -StorageUri $BacpacUriDest `
       -AdministratorLogin $credsDest.UserName -AdministratorLoginPassword $credsDest.Password
    
        [int]$expStatusctr = 0
        $expStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $exportRequestDest.OperationStatusLink

        while ($expStatus.Status -ne 'Succeeded')
        {
        Write-Progress -Activity "Exporting Database $($sqldatabasedst.DatabaseName)" -PercentComplete (($expStatusctr / 100) * 100)

        start-sleep -Milliseconds 200
        $expStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $exportRequestDest.OperationStatusLink
            if ($expStatus.StatusMessage)
            {  
            $expStatus = $expStatus.StatusMessage.Split('=') 
            $expStatusctr=$expStatus[1].Trim('%')
            }
        }
    Write-Host "Destination Export complete! $BacpacUriDest" -ForegroundColor Green
 #moving containers from one subscription to another subcription
     
     $BlobCopy = Start-CopyAzureStorageBlob -Context $storageContextSource -SrcContainer $storageContainerSource.name -SrcBlob  $bacpacFilenameSource -DestContext $storageContextDest -DestContainer $storageContainerDest.name -DestBlob $bacpacFilenameSource -Force    
     $CopyState = $BlobCopy | Get-AzureStorageBlobCopyState
     $Message = $CopyState.Source.AbsolutePath + " " + $CopyState.Status + " {0:N2}%" -f (($CopyState.BytesCopied/$CopyState.TotalBytes)*100) 
     Write-Host $Message -ForegroundColor Yellow
   
 #Delete database that has been exported from destination

    Remove-AzureRmSqlDatabase -ResourceGroupName $sqldatabasedst.ResourceGroupName -ServerName $sqldatabasedst.ServerName -DatabaseName $sqldatabasedst.databasename -Force
    Write-Host "Deleted database" $sqldatabasedst.databasename -ForegroundColor Yellow

 #import new database from blob storage 
         $bacpacurinew = $BaseStorageUriDest + $bacpacFilenameSource
      $importRequest = New-AzureRmSqlDatabaseImport -ResourceGroupName $sqldatabasedst.ResourceGroupName -ServerName $sqldatabasedst.ServerName -DatabaseName $sqldatabasedst.databasename -StorageKeyType "StorageAccessKey" -StorageKey $storageAcctKeyDest -AdministratorLogin $credsDest.UserName -AdministratorLoginPassword $credsDest.Password -StorageUri $bacpacurinew –Edition basic –ServiceObjectiveName basic -DatabaseMaxSizeBytes 20000000
        [int]$impStatusctr = 0
        $impStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink

        while ($impStatus.Status -ne 'Succeeded')
        {
        Write-Progress -Activity "importing Database $($sqldatabasedst.DatabaseName)" -PercentComplete (($impStatusctr / 100) * 100)

        start-sleep -Milliseconds 200
        $impStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
            if ($impStatus.StatusMessage)
            {  
            $impStatus = $impStatus.StatusMessage.Split('=') 
            $impStatusctr=$impStatus[1].Trim('%')
            }
        }

    Write-Host " Creation of user on database and giving role";

    $user = $user_pass.UserName
    $pass = $user_pass.GetNetworkCredential().Password

    $serverinstace = $sqldatabasedst.ServerName+".database.windows.net"
    $databasemaster = "master"
    $database = $sqldatabasedst.DatabaseName
    $uid = $credsDest.UserName
    $pwd = $credsDest.GetNetworkCredential().Password
    $SqlQuerymaster = "CREATE LOGIN $user WITH password='$pass';CREATE USER $user FROM LOGIN $user;"
    $SqlQuery = "CREATE USER $user FROM LOGIN $user;EXEC sp_addrolemember 'db_owner', '$user'"

    Invoke-Sqlcmd -Username $uid -Password $pwd -ServerInstance $serverinstace -Database $databasemaster -Query $SqlQuerymaster
    Invoke-Sqlcmd -Username $uid -Password $pwd -ServerInstance $serverinstace -Database $database -Query $SqlQuery

}
