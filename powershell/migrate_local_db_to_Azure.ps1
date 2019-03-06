$startTime=Get-Date
$PathVariables=$env:Path
IF (-not $PathVariables.Contains( "C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin"))
{
    $env:Path = $env:Path + ";C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin;" 
}

$AzureSqlServerName = "mytestsqlserver.database.windows.net"
$AzureSqlDbName = "mytestdatabase"
$sqlServerName = "10.x.x.x"

$bacpacFilename =  $AzureSqlDbName + "-ToAzure-" + (Get-Date).ToString("yyyyMMddHHmm") + ".bacpac"
$bacpacFilePath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments) + "\" + $bacpacFilename

sqlpackage.exe /a:Export /ssn:$sqlServerName /sdn:$AzureSqlDbName /su:$((Get-StoredCredential -Target $sqlServerName).UserName) /sp:$((Get-StoredCredential -Target $sqlServerName).GetNetworkCredential().Password) /tf:$bacpacFilePath 

sqlcmd -S $AzureSqlServerName -U $((Get-StoredCredential -Target $AzureSqlServerName).UserName) -P $((Get-StoredCredential -Target $AzureSqlServerName).GetNetworkCredential().Password) -Q "alter database [$AzureSqlDbName] set single_user with rollback immediate"
sqlcmd -S $AzureSqlServerName -U $((Get-StoredCredential -Target $AzureSqlServerName).UserName) -P $((Get-StoredCredential -Target $AzureSqlServerName).GetNetworkCredential().Password) -Q "drop DATABASE [$AzureSqlDbName]"
sqlpackage.exe /a:Import /sf:$bacpacFilePath /tsn:$AzureSqlServerName /tdn:$AzureSqlDbName /tu:$((Get-StoredCredential -Target $AzureSqlServerName).UserName) /tp:$((Get-StoredCredential -Target $AzureSqlServerName).GetNetworkCredential().Password)  /p:DatabaseEdition=Standard /p:DatabaseServiceObjective='S3'

$null | Out-File ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments) + "\scripts\last_RU_file_name.txt")
$bacpacFilePath | Out-File ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments) + "\scripts\last_RU_file_name.txt")

$endTime=Get-Date
Write-Host "Execution time is " ($endTime - $startTime).TotalSeconds "seconds"-ForegroundColor Green