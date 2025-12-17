
<#
  clean-rdp.ps1
  支持以下运行方式：
  1) 本地 -File 直接运行
  2) 远程管道运行：iwr "<URL>" | iex
  - 首次通过 iex 运行时，会将脚本落盘到 %TEMP%，再以 -File 方式重新启动
  - 如非管理员，会触发 UAC 提权并延续执行
#>

param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Rest
)

$BOOTSTRAP_FLAG = "--bootstrapped"

function Test-IsAdmin {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

# 检测是否已引导过（避免循环）
$IsBootstrapped = $false
foreach ($a in $Rest) {
    if ($a -eq $BOOTSTRAP_FLAG) { $IsBootstrapped = $true }
}

# 从当前上下文提取脚本文本（用于 iex 场景）
function Get-CurrentScriptText {
    $sb = $null
    try { $sb = $MyInvocation.MyCommand.ScriptBlock } catch {}
    if ($sb) { return $sb.ToString() }
    $def = $null
    try { $def = $MyInvocation.MyCommand.Definition } catch {}
    if ($def) { return [string]$def }
    $ln = $null
    try { $ln = $MyInvocation.Line } catch {}
    if ($ln) { return [string]$ln }
    return $null
}

# 如通过 iex 运行（通常没有 $PSCommandPath），先落盘引导一次
$shouldBootstrap = -not $IsBootstrapped -and ([string]::IsNullOrEmpty($PSCommandPath))
if ($shouldBootstrap) {
    Write-Host "Running via iex, bootstrapping to file..."
    $scriptText = Get-CurrentScriptText
    if (-not $scriptText) {
        Write-Error "无法获取脚本文本用于引导。"
        exit 1
    }
    $tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "clean-rdp_" + [System.Guid]::NewGuid().ToString("N") + ".ps1")
    Set-Content -Path $tmp -Value $scriptText -Encoding UTF8

    $argsList = @('-NoProfile','-ExecutionPolicy','Bypass','-File', $tmp, $BOOTSTRAP_FLAG)
    Start-Process -FilePath "powershell" -ArgumentList $argsList -Wait
    exit $LASTEXITCODE
}

# 计算脚本路径（以 -File 方式）
$ScriptPath = if ($PSCommandPath) { $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } else { $null }

# 非管理员则自提权
if (-not (Test-IsAdmin)) {
    Write-Host "Requesting administrator privileges..."
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass')
    if ($ScriptPath) {
        $argList += @('-File', $ScriptPath)
    } else {
        # 极端情况下没有路径，只能再用脚本文本临时引导一次
        $text = Get-CurrentScriptText
        if (-not $text) { Write-Error "无法找到脚本路径或脚本文本以提权重启。"; exit 1 }
        $tmp2 = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "clean-rdp_" + [System.Guid]::NewGuid().ToString("N") + ".ps1")
        Set-Content -Path $tmp2 -Value $text -Encoding UTF8
        $argList += @('-File', $tmp2)
    }
    # 保留引导标记，防止提权后再次进入引导分支
    $argList += $BOOTSTRAP_FLAG

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell'
    $psi.Arguments = ($argList -join ' ')
    $psi.Verb = 'runas'
    try {
        $p = [System.Diagnostics.Process]::Start($psi)
        $p.WaitForExit()
        exit $p.ExitCode
    } catch {
        Write-Error "用户取消或提权失败。$_"
        exit 1
    }
}

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
