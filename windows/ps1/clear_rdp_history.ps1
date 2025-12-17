# ===============================
# Self-elevating PowerShell script
# ===============================
# 1. 检测是否管理员
function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 2. 如果不是管理员，则自我提权
if (-not (Test-IsAdmin)) {
    Write-Host "Requesting administrative privileges..."

    $ps = (Get-Process -Id $PID).Path
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""

    Start-Process -FilePath $ps -ArgumentList $args -Verb RunAs
    exit
}

# ===============================
# 3. 管理员上下文：正式逻辑
# ===============================

Write-Host "Running as administrator."

# 删除 RDP 默认记录
$rdpBase = "HKCU:\Software\Microsoft\Terminal Server Client"

Remove-ItemProperty -Path "$rdpBase\Default" -Name * -ErrorAction SilentlyContinue
Remove-Item -Path "$rdpBase\Servers" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -Path "$rdpBase\Servers" -Force | Out-Null

# 删除 Default.rdp
$rdpFile = Join-Path $env:USERPROFILE "Documents\Default.rdp"

if (Test-Path $rdpFile) {
    attrib -s -h $rdpFile 2>$null
    Remove-Item $rdpFile -Force
}

Write-Host "Done."
