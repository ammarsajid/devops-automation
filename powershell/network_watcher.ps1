$time_offset = 5
$tlx_time = (Get-Date).AddHours($time_offset)
$fromaddress = "someone@gmail.com" 
$smtpserver = "smtp.gmail.com"
$Username = "myuser@gmail.com"
$Password = "mygmailpassword"
$SMTPPort = "587"
$hostIP = '192.168.18.10'

$sourceDir = "C:\PingStorage\prod_ping_logs"
$Subject = "VPN ping results (9am to 7pm) - " + $tlx_time.ToString('yyyy/MM/dd')

if (-Not (Test-Path ($sourceDir + "\temp_dir_" + $tlx_time.ToString('yyyy_MM_dd')) -PathType Any))
{
    $tempDir = New-Item -ItemType directory -Path ($sourceDir + "\temp_dir_" + $tlx_time.ToString('yyyy_MM_dd'))
}

$filename = $tempDir.FullName + "\ping_result_" + $tlx_time.ToString('yyyy_MM_dd') + "_peak.txt"
if (-Not (Test-Path $filename -PathType Any))
{
    $null | Out-File $filename
}

$successCount = 0
$failedCount = 0
while((Get-Date).AddHours($time_offset).Hour -ge 9 -and (Get-Date).AddHours($time_offset).Hour -lt 19)
{
    $ping = new-object System.Net.NetworkInformation.Ping
    $reply = $ping.send($hostIP)
    if ($reply.Status -eq "Success")
    {
        $filewrite = (Get-Date).AddHours($time_offset).ToString() + " - Reply from " + $reply.Address + ": bytes=32 time=" + $reply.RoundtripTime + "ms"
        $successCount++
    }
    else
    {
        $filewrite = (Get-Date).AddHours($time_offset).ToString() + " - Request timed out. "
        $failedCount++
    }
    $filewrite >> $filename
    Start-Sleep -Milliseconds 750   
}

Add-Type -assembly "system.io.compression.filesystem"
$zipfilename = $sourceDir + "\ping_result_" + $tlx_time.ToString('yyyy_MM_dd') + "_peak.zip"
[io.compression.zipfile]::CreateFromDirectory($tempDir.FullName, $zipfilename)

$body = @"

Hello,

Please find the attached ping status of Production Database from Cloud VM.

Ping Statistics:
        Packets:   Success = $successCount,   Lost = $failedCount

"@

$message = new-object System.Net.Mail.MailMessage 
$message.From = $fromaddress 

# Recipients
$message.To.Add("team@gmail.com")

$message.IsBodyHtml = $false 
$message.Subject = $Subject 
$attach = new-object Net.Mail.Attachment($zipfilename) 
$message.Attachments.Add($attach) 
$message.body = $body 

$smtp = New-Object System.Net.Mail.SmtpClient($smtpserver, $SMTPPort);
$smtp.EnableSSL = $true
$smtp.Credentials = New-Object System.Net.NetworkCredential($Username, $Password);
$smtp.Send($message)
$attach.Dispose()
Remove-Item –path $tempDir –recurse -Force