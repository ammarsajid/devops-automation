$databasename = "kashf-prod"
$servername = "tmxmf-kashf"
$resourcegroupname = "TMX-KASHF-QA"

#Login-AzureRmAccount
Select-AzureRmSubscription -SubscriptionID "3c3b8913-a968-4f0c-8d13-d386611bda0b"

$ResourceId = "/subscriptions/$($(Get-AzureRMContext).Subscription.Id)/resourceGroups/$resourcegroupname/providers/Microsoft.Sql/servers/$servername/databases/$databasename"
$TimeGrain = [TimeSpan]::Parse("00:01:00")

$endTime = [System.DateTime] (get-date)
$startTime = [System.DateTime] (get-date).AddDays(-32)

$metric1 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "cpu_percent"
$metric2 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "physical_data_read_percent"
$metric3 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "log_write_percent"
$metric4 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "dtu_consumption_percent"
$metric5 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "storage"
$metric6 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "connection_successful"
$metric7 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "blocked_by_firewall"
$metric8 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "deadlock"
$metric9 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "storage_percent"
$metric10 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "xtp_storage_percent"
$metric11 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "workers_percent"
$metric12 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "sessions_percent"
$metric13 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "dtu_limit"
$metric14 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "dtu_used"

$metrics = @()
#0..($metric1.Count - 1) | ForEach-Object {$metrics += @("$($metric1.Data[$_].TimeStamp)")}

$metrics = for ( $i = 0; $i -lt $metric1.Data.Count; $i++)
{
    New-Object -TypeName PSObject -Property @{
    TimeStamp = $metric1.Data[$i].TimeStamp
    CpuPercentage = $metric1.Data[$i].Average
    PhysicalDataReadPercent = $metric2.Data[$i].Average
    LogWritePercent = $metric3.Data[$i].Average
    DtuConsumptionPercent = $metric4.Data[$i].Average
    Storage = $metric5.Data[$i].Maximum
    ConnectionSuccessful = $metric6.Data[$i].Total
    BlockedByFirewall = $metric7.Data[$i].Total
    Deadlock = $metric8.Data[$i].Total
    StoragePercent = $metric9.Data[$i].Maximum
    XtpStoragePercent = $metric10.Data[$i].Average
    SorkersPercent = $metric11.Data[$i].Average
    SessionsPercent = $metric12.Data[$i].Average
    DtuLimit = $metric13.Data[$i].Average
    DtuUsed = $metric14.Data[$i].Average

    }
}
$metrics | Export-Csv -Path "F:\Techlogix\Automation\kash_prod_db_utilization20190218.csv"


#$available_metrics = Get-AzureRmMetricDefinition -ResourceId $ResourceId
$metrics | select -First 10
