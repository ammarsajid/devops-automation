param (
    [Parameter(Position=0)]
    [switch]$importbacpac
)

Function  Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "bacpac (*.bacpac)| *.bacpac"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.FileName 
    
}

try 
{
    $AzureSubscriptionId =     (Get-AzureRmSubscription | Out-GridView -Title 'Select an Azure Subscription' -OutputMode Single)
    Set-AzureRmContext -SubscriptionID $AzureSubscriptionId
}
catch 
{
    Login-AzureRmAccount
    $AzureSubscriptionId =     (Get-AzureRmSubscription | Out-GridView -Title 'Select an Azure Subscription' -OutputMode Single)
    Set-AzureRmContext -SubscriptionID $AzureSubscriptionId
}


   $resourceGroupNames = Get-AzureRmResourceGroup
   $sqlSrver = @() 

   foreach($resourceGroupName in $resourceGroupNames)
   {
        $sqlSrver += Get-AzureRmSqlserver -ResourceGroupName $resourceGroupName.ResourceGroupName    
   }
 
     $sqlServer =$sqlSrver | Out-GridView  -Title 'Select Azure SQL Server of database'  -OutputMode Single

    $sqlDB = Read-host "Write Name of Database: " 
  
    $sqlServerAdmin= $sqlServer.SqlAdministratorLogin
  
    $securePassword = Read-Host "Enter in the password for $sqlServerAdmin" -AsSecureString
    
    #user creation for database credentials

    $user_pass = Get-Credential

    $creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sqlServerAdmin, $securePassword

    #VARIABLES for app service
    
     $resourceGroupNamesSource = Get-AzureRmResourceGroup
     $AppPlanes = @()

     foreach($resourceGroupNameSource in $resourceGroupNamesSource)
     {
     $AppPlanes+= Get-AzureRmAppServicePlan -ResourceGroupName $resourceGroupNameSource.ResourceGroupName
     }

      $appplane  = $AppPlanes | Out-GridView  -Title 'Select your app plane'  -OutputMode Single

     $Appname =Read-host "write name of web-app ";
 
     #create web-app in selected app_plane & resource group

    New-AzureRmWebApp -ResourceGroupName $appplane.ResourceGroup -Name $Appname -AppServicePlan $appplane.ServerFarmWithRichSkuName -Location  $appplane.Location
  
    #Get publish profile
    $path=Get-Location
    $pathpublishprofile =$path.Path + "\publishprofile"
   $publishprofile = Get-AzureRmWebAppPublishingProfile -ResourceGroupName $appplane.ResourceGroup -Name $Appname -Format "Ftp" -OutputFile $pathpublishprofile

 
   if($PSBoundParameters.ContainsKey('importbacpac'))
   {
    $storageAcct = Get-AzureRmStorageAccount | Out-GridView -Title 'Select Storage Account' -OutputMode Single
    $storageAcctKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $storageAcct.ResourceGroupName -name $storageAcct.StorageAccountName)[0].value
    $storageContext = New-AzureStorageContext -StorageAccountName $storageAcct.StorageAccountName -StorageAccountKey $storageAcctKey
    $storageContainer = Get-AzureStorageContainer -Context $storageContext | select Name | Out-GridView  -Title 'Select Container..' -OutputMode Single
    $BaseStorageUri = "$($storageAcct.PrimaryEndpoints.Blob)$($storageContainer.Name)/"
    $paths = Get-Location
    $initialDirectory = $paths.Path
    $file = get-filename($initialDirectory)
    $basename = gi $file | select basename 
    $b = $basename[0]
    $bacpacFilename= $b.basename

    $BacpacUri2 = $BaseStorageUri + $bacpacFilename
     $BacpacUri = $BacpacUri2+".bacpac" 
    start-sleep -Milliseconds 400

    Set-AzureStorageBlobContent -File $file -Container $storageContainer.Name -Context $storageContext
 
  $importRequest  = New-AzureRmSqlDatabaseImport -ResourceGroupName $sqlServer.ResourceGroupName -ServerName $sqlServer.ServerName -DatabaseName $sqlDB -StorageKeyType "StorageAccessKey" -StorageKey $storageAcctKey -AdministratorLogin $creds.UserName -AdministratorLoginPassword $creds.Password -StorageUri $BacpacUri –Edition basic –ServiceObjectiveName basic -DatabaseMaxSizeBytes 20000000
   #import status  
        [int]$impStatusctr = 0
        $impStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
        while ($impStatus.Status -ne 'Succeeded')
        {
        Write-Progress -Activity "importing Database $($sqlDB)" -PercentComplete (($impStatusctr / 100) * 100)

        start-sleep -Milliseconds 300
        $impStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
            if ($impStatus.StatusMessage)
            {  
            $impStatus = $impStatus.StatusMessage.Split('=') 
            $impStatusctr=$impStatus[1].Trim('%')
            }
        }
  Write-Host " Creation of user on database and giving role";
    
    $user= $user_pass.UserName
    $pass = $user_pass.GetNetworkCredential().Password
    $serverinstace = $sqlServer.ServerName+".database.windows.net"
    $databasemaster = "master"
    $uid = $creds.UserName
    $pwd = $creds.GetNetworkCredential().Password
    $SqlQuerymaster = "CREATE LOGIN $user WITH password='$pass';CREATE USER $user FROM LOGIN $user;"
    $SqlQuery = "CREATE USER $user FROM LOGIN $user;EXEC sp_addrolemember 'db_owner', '$user'"

    Invoke-Sqlcmd -Username $uid -Password $pwd -ServerInstance $serverinstace -Database $databasemaster -Query $SqlQuerymaster
    Invoke-Sqlcmd -Username $uid -Password $pwd -ServerInstance $serverinstace -Database $sqlDB -Query $SqlQuery

    }
  
   else
   {
     #create new blank basic edition database

   
   New-AzureRmSqlDatabase -ResourceGroupName $sqlServer.ResourceGroupName -ServerName $sqlServer.ServerName -DatabaseName $sqlDB  –Edition basic 
    
    Write-Host " Creation of user on database and giving role";
    
    $user = $user_pass.UserName
    $pass = $user_pass.GetNetworkCredential().Password

    $serverinstace = $sqlServer.ServerName+".database.windows.net"
    $databasemaster = "master"
    $uid = $creds.UserName
    $pwd = $creds.GetNetworkCredential().Password
    $SqlQuerymaster = "CREATE LOGIN $user WITH password='$pass';CREATE USER $user FROM LOGIN $user;"
    $SqlQuery = "CREATE USER $user FROM LOGIN $user;EXEC sp_addrolemember 'db_owner', '$user'"

    Invoke-Sqlcmd -Username $uid -Password $pwd -ServerInstance $serverinstace -Database $databasemaster -Query $SqlQuerymaster
    Invoke-Sqlcmd -Username $uid -Password $pwd -ServerInstance $serverinstace -Database $sqlDB -Query $SqlQuery

}
        

   


    