workflow AZURE_SQLSERVER_BACKUP_ALL_DBs
{
	inlineScript {
		$connectionName = "AzureRunAsConnection"
		try
		{
    		# Get the connection "AzureRunAsConnection "
    		$servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         
		
    		"Logging in to Azure..."
    		Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
		}
		catch {                                 
    		if (!$servicePrincipalConnection)
    		{
        		$ErrorMessage = "Connection $connectionName not found."
        		throw $ErrorMessage
    		} else{
        		Write-Error -Message $_.Exception
        		throw $_.Exception
    		}
		}
		
		# Database server to export
		$ResourceGroupName = "TESTRS"
        $ServerName = "mytestsqlserver"
        $Servercredential = Get-AutomationPSCredential -Name 'mytestsqlservercredentials'
        
        Select-AzureRmSubscription -SubscriptionID "cadxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx9"
        $Databases = Get-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $ServerName | where {$_.DatabaseName -ne 'master'}
        
        # Storage account info for the BACPAC
        $BaseStorageUri = "https://myteststorageaccount.blob.core.windows.net/an-stg-backups/" + (Get-Date).ToString("yyyy-MM-dd") + "/"
        $StorageKeytype = "StorageAccessKey"
        $StorageKey = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=="

        $backupReport = @()
		for($i=0; $i -lt $Databases.Count; )
        {
            $exportRequests = @()
            for($j=0; $j -lt 5; $j++)
            {
                if($Databases[$i + $j] -eq $null ){break}
                $bacpacFilename = $Databases[$i + $j].DatabaseName + (Get-Date).ToString("yyyy-MM-dd-HH-mm") + ".bacpac"
                $BacpacUri = $BaseStorageUri + $bacpacFilename
                $exportRequests += New-AzureRmSqlDatabaseExport -ResourceGroupName $ResourceGroupName -ServerName $ServerName `
                                   -DatabaseName $Databases[$i + $j].DatabaseName -StorageKeytype $StorageKeytype -StorageKey $StorageKey `
                                   -StorageUri $BacpacUri -AdministratorLogin $Servercredential.UserName `
                                   -AdministratorLoginPassword $Servercredential.Password
                
            }
            
            foreach($exportRequest in $exportRequests)
            {
                $exportStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $exportRequest.OperationStatusLink
                while ($exportStatus.Status -eq 'InProgress')
                {
                    start-sleep -s 5
                    $exportStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $exportRequest.OperationStatusLink
                }
                $backupReport += $exportStatus.Status
            }
            $i = $i + 5
        }
        Write-Output –InputObject $backupReport
	}
}