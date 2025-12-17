# ===============================
# Bootstrap if running via iex
# ===============================
if (-not $PSCommandPath) {
    Write-Host "Running via iex, bootstrapping to file..."

    $tmp = Join-Path $env:TEMP ([guid]::NewGuid().ToString() + ".ps1")
    $src = (Get-Variable MyInvocation -Scope 0).Value.Line

    Set-Content -Path $tmp -Value $src -Encoding UTF8
    powershell -NoProfile -ExecutionPolicy Bypass -File $tmp
    exit
}

# ===============================
# Self-elevating PowerShell script
# ===============================

function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "Requesting administrative privileges..."

    Start-Process -FilePath powershell `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
        -Verb RunAs
    exit
}

# ===============================
# 管理员逻辑
# ===============================

Write-Host "Running as administrator."

$rdpBase = "HKCU:\Software\Microsoft\Terminal Server Client"

Remove-ItemProperty -Path "$rdpBase\Default" -Name * -ErrorAction SilentlyContinue
Remove-Item -Path "$rdpBase\Servers" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -Path "$rdpBase\Servers" -Force | Out-Null

$rdpFile = Join-Path $env:USERPROFILE "Documents\Default.rdp"

if (Test-Path $rdpFile) {
    attrib -s -h $rdpFile 2>$null
    Remove-Item $rdpFile -Force
}

Write-Host "Done."
