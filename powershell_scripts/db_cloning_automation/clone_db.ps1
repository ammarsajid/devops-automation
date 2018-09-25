
param(
[Parameter(Mandatory=$True)]
[string]$sdb,
[Parameter(Mandatory=$True)]
[string]$ddb
)


$tenantId = "ef2ae82d-4e13-4e07-a871-c04fda3c6867"
$subscriptionId = "112667f3-b281-4ede-a2f3-537bbe759911"

#$curDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$curDir = "D:\Techlogix\GitLab\Cloudops-09-25-18\cloudops\powershell_scripts\db_cloning_automation"
$dbFilePath = $curDir + "\andatabases.json"

$allDbsJson = ConvertFrom-Json "$(get-content $dbFilePath)"

Login-AzureRmAccount -TenantId $tenantId
Select-AzureRmSubscription -SubscriptionID $subscriptionId

# Copy source database to the target server 
$databasecopy = New-AzureRmSqlDatabaseCopy -ResourceGroupName $allDbsJson.$sdb.resourcegroup -ServerName $allDbsJson.$sdb.server -DatabaseName $allDbsJson.$sdb.dbname `
     -CopyResourceGroupName $allDbsJson.$ddb.resourcegroup -CopyServerName $allDbsJson.$ddb.server -CopyDatabaseName $allDbsJson.$ddb.dbname
