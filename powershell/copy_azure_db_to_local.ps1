# This script copy an Azure SQL database to any local SQL server #
# <Warning> 
# It would delete the database on the destination server if it already exists with the same name #

$startTime=Get-Date
$PathVariables=$env:Path
IF (-not $PathVariables.Contains( "C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin"))
{
    $env:Path = $env:Path + ";C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin;" 
}

$sqlServerName = "10.x.x.x"
$AzureSqlServerName = "myazureserver.database.windows.net"
$AzureSqlDbName = "mydatabase"

$bacpacFilename =  $AzureSqlDbName + "-" + (Get-Date).ToString("yyyyMMddHHmm") + ".bacpac"
$bacpacFilePath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments) + "\" + $bacpacFilename

sqlpackage.exe /a:Export /ssn:$AzureSqlServerName /sdn:$AzureSqlDbName /su:$((Get-StoredCredential -Target $AzureSqlServerName).UserName) /sp:$((Get-StoredCredential -Target $AzureSqlServerName).GetNetworkCredential().Password) /tf:$bacpacFilePath

sqlcmd -S $sqlServerName -U $((Get-StoredCredential -Target $sqlServerName).UserName) -P $((Get-StoredCredential -Target $sqlServerName).GetNetworkCredential().Password) -Q "alter database [$AzureSqlDbName] set single_user with rollback immediate"
sqlcmd -S $sqlServerName -U $((Get-StoredCredential -Target $sqlServerName).UserName) -P $((Get-StoredCredential -Target $sqlServerName).GetNetworkCredential().Password) -Q "drop DATABASE [$AzureSqlDbName]"

sqlpackage.exe /a:Import /sf:$BacpacFilePath /tsn:$sqlServerName /tdn:$AzureSqlDbName /tu:$((Get-StoredCredential -Target $sqlServerName).UserName) /tp:$((Get-StoredCredential -Target $sqlServerName).GetNetworkCredential().Password)

$endTime=Get-Date
Write-Host "Execution time is " ($endTime - $startTime).TotalSeconds "seconds"-ForegroundColor Green