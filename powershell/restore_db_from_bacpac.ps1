$startTime=Get-Date
$PathVariables=$env:Path
IF (-not $PathVariables.Contains( "C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin"))
{
    $env:Path = $env:Path + ";C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin;" 
}

$sqlServerName = "mytestsqlserver.database.windows.net"
$sqlDbName = "mytestdatabase"
$bacpacFilePath = "C:\Users\Administrator\Documents\mytestdatabase-201808281010.bacpac"

sqlcmd -S $sqlServerName -U $((Get-StoredCredential -Target $sqlServerName).UserName) -P $((Get-StoredCredential -Target $sqlServerName).GetNetworkCredential().Password) -Q "alter database [$sqlDbName] set single_user with rollback immediate"
sqlcmd -S $sqlServerName -U $((Get-StoredCredential -Target $sqlServerName).UserName) -P $((Get-StoredCredential -Target $sqlServerName).GetNetworkCredential().Password) -Q "drop DATABASE [$sqlDbName]"

sqlpackage.exe /a:Import /sf:$bacpacFilePath /tsn:$sqlServerName /tdn:$sqlDbName /tu:$((Get-StoredCredential -Target $sqlServerName).UserName) /tp:$((Get-StoredCredential -Target $sqlServerName).GetNetworkCredential().Password)

$endTime=Get-Date
Write-Host "Execution time is " ($endTime - $startTime).TotalSeconds "seconds"-ForegroundColor Green