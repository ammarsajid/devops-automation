workflow AN-STG-DB-BACKUP
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
		$ResourceGroupName = "AN-PREPROD"
        $ServerName = "an-stg"
        $Servercredential = Get-AutomationPSCredential -Name 'anstgcredentials'
        
        Select-AzureRmSubscription -SubscriptionID "cac601c4-4a4f-4aa3-939e-2923e23b1cd6"
        $Databases = Get-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $ServerName | where {$_.DatabaseName -ne 'master'}
        
        # Storage account info for the BACPAC
        $BaseStorageUri = "https://ancloudops.blob.core.windows.net/an-stg-backups/" + (Get-Date).ToString("yyyy-MM-dd") + "/"
        $StorageKeytype = "StorageAccessKey"
        $StorageKey = "VHt9S600ZjY4qfUb0iWyC6Rswf6uVDSsoIIicY4n5GDyiIjJ/rE4GRV9meAZvk9L97IqzNfQr2m1u51beCP2wQ=="

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