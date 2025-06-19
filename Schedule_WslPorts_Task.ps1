$a = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File `"C:\Dev\EnderNet\Bridge_WslPorts.ps1`" -WindowStyle Hidden -ExecutionPolicy Bypass"
$t = New-ScheduledTaskTrigger -AtLogon
$s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$p = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
Register-ScheduledTask -TaskName "WSL2PortsBridge" -Action $a -Trigger $t -Settings $s -Principal $p