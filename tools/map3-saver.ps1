$ErrorActionPreference = "Continue"
$log = "D:\Project\GameRecomp\AdvanceWars2BlackHoleRisingRecomp\logs\saver3.log"
function Log($m) { Add-Content -Path $log -Value ("{0} {1}" -f (Get-Date -Format HH:mm:ss), $m) }
Log "saver3 start"
Start-Sleep -Seconds 2400
for ($i = 0; $i -lt 25; $i++) {
  $p = Get-Process -Name "AdvanceWars2*" -ErrorAction SilentlyContinue
  if (-not $p) { Log "game gone"; break }
  $state = "D:\Project\GameRecomp\AdvanceWars2BlackHoleRisingRecomp\logs\map3.state"
  if (Test-Path $state) { Log "state exists"; break }
  Log ("poll cpu=" + ($p.CPU -join ","))
  try {
    $c = New-Object Net.Sockets.TcpClient
    $c.Connect("127.0.0.1", 19844)
    $c.ReceiveTimeout = 20000
    $s = $c.GetStream()
    $w = New-Object IO.StreamWriter($s); $w.NewLine = "`n"; $w.AutoFlush=$true
    $w.WriteLine('{"cmd":"savestate_save","path":"D:\\Project\\GameRecomp\\AdvanceWars2BlackHoleRisingRecomp\\logs\\map3.state"}')
    $r = (New-Object IO.StreamReader($s)).ReadLine()
    $c.Close()
    Log "save -> $r"
    if ($r -match "ok.:true") { break }
  } catch { Log "save err $_" }
  Start-Sleep -Seconds 120
}
Log "saver3 done"
