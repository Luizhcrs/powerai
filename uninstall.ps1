# uninstall.ps1 - Desinstalador Universal do PowerAI para Windows (PS e CMD)
# Uso: irm https://raw.githubusercontent.com/Luizhcrs/nuno/main/uninstall.ps1 | iex

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [PowerAI] Desinstalador para Windows (PowerShell e CMD) " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Remover modulo PowerShell
Write-Host "[1/5] Removendo modulos do PowerShell..." -ForegroundColor Yellow
$modulePaths = @(
    (Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules\PowerAI"),
    (Join-Path $env:USERPROFILE "Documents\PowerShell\Modules\PowerAI"),
    (Join-Path ([Environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell\Modules\PowerAI"),
    (Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\Modules\PowerAI")
) | Select-Object -Unique

foreach ($mPath in $modulePaths) {
    if (Test-Path $mPath) {
        Remove-Item -Path $mPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "   [OK] Removido modulo: $mPath" -ForegroundColor Green
    }
}

# 2. Limpar $PROFILE do PowerShell
Write-Host "[2/5] Limpando perfis do PowerShell..." -ForegroundColor Yellow
$profileFiles = @(
    "C:\Users\$env:USERNAME\Documents\WindowsPowerShell\profile.ps1",
    "C:\Users\$env:USERNAME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
    "C:\Users\$env:USERNAME\Documents\PowerShell\profile.ps1",
    "C:\Users\$env:USERNAME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
)
if ($PROFILE) {
    $profileFiles += @(
        $PROFILE.CurrentUserAllHosts,
        $PROFILE.CurrentUserCurrentHost,
        $PROFILE.AllUsersAllHosts,
        $PROFILE.AllUsersCurrentHost
    )
}
$profileFiles = $profileFiles | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

foreach ($p in $profileFiles) {
    if (Test-Path $p) {
        $lines = Get-Content -Path $p -Encoding UTF8 -ErrorAction SilentlyContinue
        $filtered = $lines | Where-Object { $_ -notmatch 'PowerAI' -and $_ -notmatch '\.powerai' }
        if ($filtered.Count -eq 0 -or [string]::IsNullOrWhiteSpace(($filtered -join "").Trim())) {
            Remove-Item -Path $p -Force -ErrorAction SilentlyContinue
            Write-Host "   [OK] Perfil limpo (removido vazio): $p" -ForegroundColor Green
        } else {
            Set-Content -Path $p -Value $filtered -Encoding UTF8 -Force
            Write-Host "   [OK] Linha do PowerAI removida de: $p" -ForegroundColor Green
        }
    }
}

# 3. Remover atalho '?' do CMD (AutoRun no Registro)
Write-Host "[3/5] Removendo configuracao do CMD no Registro..." -ForegroundColor Yellow
try {
    $regKey = "HKCU:\Software\Microsoft\Command Processor"
    if (Test-Path $regKey) {
        $autoRunVal = (Get-ItemProperty -Path $regKey -Name "AutoRun" -ErrorAction SilentlyContinue).AutoRun
        if ($autoRunVal) {
            if ($autoRunVal -like "*cmd_autorun.cmd*" -or $autoRunVal -like "*powerai*") {
                Remove-ItemProperty -Path $regKey -Name "AutoRun" -Force -ErrorAction SilentlyContinue
                Write-Host "   [OK] Registro de AutoRun do CMD removido." -ForegroundColor Green
            }
        }
    }
} catch {
    reg.exe delete "HKCU\Software\Microsoft\Command Processor" /v AutoRun /f 2>$null | Out-Null
}

# 4. Remover PATH de Usuario
Write-Host "[4/5] Removendo PowerAI do PATH do Windows..." -ForegroundColor Yellow
$binDir = Join-Path $env:USERPROFILE ".powerai\bin"
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -like "*$binDir*") {
    $newPath = ($userPath.Split(';') | Where-Object { $_.TrimEnd('\') -ne $binDir.TrimEnd('\') -and -not [string]::IsNullOrWhiteSpace($_) }) -join ';'
    [System.Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "   [OK] PATH do Windows atualizado." -ForegroundColor Green
} else {
    Write-Host "   [OK] PATH ja esta limpo." -ForegroundColor Gray
}

# 5. Remover diretorio ~/.powerai
Write-Host "[5/5] Removendo arquivos de configuracao e binarios..." -ForegroundColor Yellow
$powerAiDir = Join-Path $env:USERPROFILE ".powerai"
if (Test-Path $powerAiDir) {
    Remove-Item -Path $powerAiDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   [OK] Pasta $powerAiDir removida." -ForegroundColor Green
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [SUCESSO] PowerAI foi completamente desinstalado!" -ForegroundColor Green
Write-Host " Abra um novo terminal para refletir todas as alteracoes." -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan
