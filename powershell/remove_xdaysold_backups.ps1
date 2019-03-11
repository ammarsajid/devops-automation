workflow Remove-XDaysOld-Backups
{
    param(
 
    [Parameter(Mandatory = $true)]
    [String]$storageAccountName,

    [Parameter(Mandatory = $true)]
    [String]$storageAccountAccessKey,
 
    [Parameter(Mandatory = $true)]
    [String]$containerName,

    [Parameter(Mandatory = $true)]
    [Int32]$DaysOld
    )

    inlinescript
    {
        $context = New-AzureStorageContext -StorageAccountName $Using:storageAccountName -StorageAccountKey $Using:storageAccountAccessKey
        $blobs= Get-AzureStorageBlob -Container $Using:containerName -Blob *.bacpac -Context $context
        foreach ($blob in $blobs)
        {
            $modifieddate = $blob.LastModified
            if ($modifieddate -ne $null) 
            {
                $howold = ([DateTime]::Now - [DateTime]$modifieddate.LocalDateTime) 
                if ($howold.TotalDays -ge $Using:DaysOld)
                {
                        Remove-AzureStorageBlob -Blob $blob.Name -Container $Using:containerName -Context $context
                        Write-Output ("Removing Blob: {0} | last modified date: {1} " -f $blob.Name, $modifieddate)
                }
            }
        }

    }

}