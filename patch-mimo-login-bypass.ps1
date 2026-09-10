# patch-mimo-login-bypass.ps1
# 将 Xiaomi MiMo 安装目录 app.asar 的 START_AUTH_BYPASS 恒真，跳过启动登录门禁。
# 用法（管理员 PowerShell）：
#   powershell -ExecutionPolicy Bypass -File "D:\DS\patch-mimo-login-bypass.ps1"
#   powershell -ExecutionPolicy Bypass -File "D:\DS\patch-mimo-login-bypass.ps1" -Start
#   powershell -ExecutionPolicy Bypass -File "D:\DS\patch-mimo-login-bypass.ps1" -Asar "C:\Program Files\Xiaomi MiMo\resources\app.asar"

[CmdletBinding()]
param(
    [string]$Asar = "C:\Program Files\Xiaomi MiMo\resources\app.asar",
    [switch]$Start,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$Old = [System.Text.Encoding]::ASCII.GetBytes(
    'z=process.env.MIMO_START_AUTH_BYPASS==="1"&&process.defaultApp===!0&&!R'
)
$NewCore = [System.Text.Encoding]::ASCII.GetBytes('z=!0')
if ($NewCore.Length -gt $Old.Length) { throw "internal: new longer than old" }
$New = New-Object byte[] $Old.Length
[Array]::Copy($NewCore, $New, $NewCore.Length)
# remaining bytes stay 0x00 — NOT valid JS padding. Use spaces instead.
for ($i = $NewCore.Length; $i -lt $New.Length; $i++) { $New[$i] = 0x20 }  # space

function Find-BytePattern {
    param([byte[]]$Haystack, [byte[]]$Needle)
    $hits = New-Object System.Collections.Generic.List[int]
    $limit = $Haystack.Length - $Needle.Length
    for ($i = 0; $i -le $limit; $i++) {
        if ($Haystack[$i] -ne $Needle[0]) { continue }
        $ok = $true
        for ($j = 1; $j -lt $Needle.Length; $j++) {
            if ($Haystack[$i + $j] -ne $Needle[$j]) { $ok = $false; break }
        }
        if ($ok) { $hits.Add($i) }
    }
    return $hits
}

if (-not (Test-Path -LiteralPath $Asar)) {
    throw "asar not found: $Asar"
}

Write-Host "[*] target: $Asar"
$info = Get-Item -LiteralPath $Asar
Write-Host ("[*] size={0}  mtime={1}" -f $info.Length, $info.LastWriteTime)

# Stop running app (asar is locked while Electron is up)
$procs = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue
if ($procs) {
    Write-Host "[*] stopping Xiaomi MiMo ($($procs.Count) process(es))..."
    $procs | Stop-Process -Force
    Start-Sleep -Seconds 2
    $left = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue
    if ($left) {
        Start-Sleep -Seconds 2
        Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 1
    }
}

$bytes = [System.IO.File]::ReadAllBytes($Asar)
$oldHits = Find-BytePattern -Haystack $bytes -Needle $Old
$newHits = Find-BytePattern -Haystack $bytes -Needle $New

Write-Host "[*] old-pattern hits: $($oldHits.Count)"
Write-Host "[*] new-pattern hits: $($newHits.Count)"

if ($oldHits.Count -eq 0 -and $newHits.Count -ge 1) {
    Write-Host "[=] already patched. nothing to do."
    if ($Start) { Start-Process -FilePath "C:\Program Files\Xiaomi MiMo\Xiaomi MiMo.exe" }
    exit 0
}

if ($oldHits.Count -ne 1) {
    throw "expected exactly 1 old pattern, found $($oldHits.Count). update may have changed layout — do not force."
}

# backup once
$bak = "$Asar.bak"
if (-not (Test-Path -LiteralPath $bak) -or $Force) {
    Copy-Item -LiteralPath $Asar -Destination $bak -Force
    Write-Host "[*] backup -> $bak"
} else {
    Write-Host "[*] backup exists, keep: $bak"
}

$pos = $oldHits[0]
[Array]::Copy($New, 0, $bytes, $pos, $New.Length)
[System.IO.File]::WriteAllBytes($Asar, $bytes)

# verify
$v = [System.IO.File]::ReadAllBytes($Asar)
$oldAfter = Find-BytePattern -Haystack $v -Needle $Old
$newAfter = Find-BytePattern -Haystack $v -Needle $New
if ($oldAfter.Count -ne 0 -or $newAfter.Count -lt 1) {
    throw "verify failed: old=$($oldAfter.Count) new=$($newAfter.Count)"
}
if ($v.Length -ne $info.Length) {
    throw "size changed unexpectedly: $($v.Length) vs $($info.Length)"
}

Write-Host "[+] patched ok @ offset 0x$($pos.ToString('X'))"
Write-Host ("[+] size still {0}" -f $v.Length)

if ($Start) {
    Write-Host "[*] starting Xiaomi MiMo..."
    Start-Process -FilePath "C:\Program Files\Xiaomi MiMo\Xiaomi MiMo.exe"
}

Write-Host "[+] done. launch app and confirm login wall is gone."
Write-Host "    rollback: copy '$bak' over '$Asar'"
