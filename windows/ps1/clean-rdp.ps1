# ===============================
# Bootstrap if running via iex
# ===============================

# Use a bootstrap flag to avoid infinite loops on environments where
# $PSCommandPath may not be populated as expected.
$__bootstrapFlag = '--bootstrapped'
$__isBootstrapped = $false
if ($args -and ($args -contains $__bootstrapFlag)) { $__isBootstrapped = $true }

if (-not $PSCommandPath -and -not $__isBootstrapped) {
    Write-Host "Running via iex, bootstrapping to file..."

    $tmp = Join-Path $env:TEMP ([guid]::NewGuid().ToString() + ".ps1")
    # When executed via `iwr ... | iex`, PSCommandPath is empty and the code
    # runs from a ScriptBlock. Grab the current script text robustly.
    $inv = Get-Variable MyInvocation -Scope 0 -ValueOnly
    $src = $null
    if ($inv.MyCommand.ScriptBlock) {
        $src = $inv.MyCommand.ScriptBlock.ToString()
    }
    if (-not $src) {
        $src = $inv.MyCommand.Definition
    }
    if (-not $src) {
        $src = $inv.Line
    }

    Set-Content -Path $tmp -Value $src -Encoding UTF8
    powershell -NoProfile -ExecutionPolicy Bypass -File $tmp $__bootstrapFlag
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

    # Preserve bootstrap flag so the elevated process won't attempt to
    # bootstrap again even if some environments still don't set PSCommandPath.
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$PSCommandPath")
    if ($__isBootstrapped) { $argList += $__bootstrapFlag }

    Start-Process -FilePath powershell `
        -ArgumentList ($argList -join ' ') `
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
