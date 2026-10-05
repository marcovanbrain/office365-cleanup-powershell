#requires -RunAsAdministrator

<#

    Remove-Office365.ps1

    Remove componentes do Microsoft 365 / Microsoft Office
    e configurações residuais do Windows.

    IMPORTANTE:

    - Execute como Administrador.
    - Salve seus documentos antes.
    - O script fecha aplicativos Office.
    - NÃO remove OneDrive, documentos pessoais ou sua conta Microsoft.
    - Reinicie o Windows ao final.

#>


# Permite a execução de scripts somente durante esta sessão do PowerShell.
# Não altera permanentemente a política de execução do Windows.
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

$ErrorActionPreference = "SilentlyContinue"


# ------------------------------------------------------------
# Função para exibir etapas do processo
# ------------------------------------------------------------

function Write-Step($Message) {

    Write-Host "`n==================================================" -ForegroundColor DarkGray
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor DarkGray
}


# ------------------------------------------------------------
# Verificar privilégios de administrador
# ------------------------------------------------------------

Write-Step "Verificando privilégios de administrador"

$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

if (-not $principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {

    Write-Host "ERRO: execute este script como Administrador." -ForegroundColor Red
    exit 1
}


# ------------------------------------------------------------
# 1. Fechar aplicativos do Office
# ------------------------------------------------------------

Write-Step "Fechando aplicativos do Office"

$officeProcesses = @(
    "WINWORD",
    "EXCEL",
    "POWERPNT",
    "OUTLOOK",
    "ONENOTE",
    "MSACCESS",
    "MSPUB",
    "VISIO",
    "WINPROJ",
    "LYNC",
    "Teams",
    "OfficeClickToRun"
)

foreach ($process in $officeProcesses) {

    Get-Process -Name $process -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

Start-Sleep -Seconds 3


# ------------------------------------------------------------
# 2. Parar serviços do Click-to-Run
# ------------------------------------------------------------

Write-Step "Parando serviços do Microsoft Office"

$services = @(
    "ClickToRunSvc",
    "OfficeSvc",
    "osppsvc"
)

foreach ($service in $services) {

    Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
}


# ------------------------------------------------------------
# 3. Identificar e remover Office Click-to-Run
# ------------------------------------------------------------

Write-Step "Procurando instalação Click-to-Run"

$clickToRunConfig = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"

$productIds = @()

if (Test-Path $clickToRunConfig) {

    $config = Get-ItemProperty $clickToRunConfig

    if ($config.ProductReleaseIds) {

        $productIds = $config.ProductReleaseIds -split ","
    }

    $officeClickToRunPaths = @(
        "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe",
        "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
    )

    $clickToRunExe = $officeClickToRunPaths |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1

    if ($clickToRunExe -and $productIds.Count -gt 0) {

        foreach ($productId in $productIds) {

            $productId = $productId.Trim()

            if ($productId) {

                Write-Host "Removendo produto: $productId" -ForegroundColor Yellow

                Start-Process `
                    -FilePath $clickToRunExe `
                    -ArgumentList "scenario=install scenariosubtype=ARP productstoremove=$productId displaylevel=False forceappshutdown=True" `
                    -Wait `
                    -NoNewWindow
            }
        }
    }
    elseif ($clickToRunExe) {

        Write-Host "Click-to-Run encontrado, mas ProductReleaseIds não foi identificado." -ForegroundColor Yellow
    }
}
else {

    Write-Host "Configuração Click-to-Run não encontrada." -ForegroundColor Gray
}

Start-Sleep -Seconds 5


# ------------------------------------------------------------
# 4. Remover entradas MSI antigas do Office
# ------------------------------------------------------------

Write-Step "Procurando instalações MSI antigas do Office"

$uninstallRoots = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$officeEntries = foreach ($root in $uninstallRoots) {

    Get-ItemProperty $root |
        Where-Object {

            $_.DisplayName -and
            (
                $_.DisplayName -match "Microsoft 365" -or
                $_.DisplayName -match "Microsoft Office" -or
                $_.DisplayName -match "Office 365" -or
                $_.DisplayName -match "Microsoft Visio" -or
                $_.DisplayName -match "Microsoft Project"
            )
        }
}

foreach ($entry in $officeEntries) {

    if ($entry.UninstallString) {

        Write-Host "Desinstalando: $($entry.DisplayName)" -ForegroundColor Yellow

        $uninstall = $entry.UninstallString.Trim()

        if ($uninstall -match 'MsiExec\.exe') {

            if ($uninstall -notmatch '/quiet') {

                $uninstall += " /quiet /norestart"
            }

            Start-Process `
                -FilePath "cmd.exe" `
                -ArgumentList "/c $uninstall" `
                -Wait `
                -NoNewWindow
        }
        else {

            Start-Process `
                -FilePath "cmd.exe" `
                -ArgumentList "/c `"$uninstall`" /quiet /norestart" `
                -Wait `
                -NoNewWindow
        }
    }
}


# ------------------------------------------------------------
# 5. Remover tarefas agendadas relacionadas ao Office
# ------------------------------------------------------------

Write-Step "Removendo tarefas agendadas do Office"

Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object {

        $_.TaskName -match "Office" -or
        $_.TaskPath -match "Office"

    } |
    ForEach-Object {

        Write-Host "Removendo tarefa: $($_.TaskName)" -ForegroundColor Yellow

        Unregister-ScheduledTask `
            -TaskName $_.TaskName `
            -TaskPath $_.TaskPath `
            -Confirm:$false `
            -ErrorAction SilentlyContinue
    }


# ------------------------------------------------------------
# 6. Remover serviços Click-to-Run restantes
# ------------------------------------------------------------

Write-Step "Removendo serviço Click-to-Run"

$clickService = Get-Service -Name "ClickToRunSvc" -ErrorAction SilentlyContinue

if ($clickService) {

    Stop-Service -Name "ClickToRunSvc" -Force -ErrorAction SilentlyContinue

    $servicePath = "$env:SystemRoot\System32\sc.exe"

    Start-Process `
        -FilePath $servicePath `
        -ArgumentList "delete ClickToRunSvc" `
        -Wait `
        -NoNewWindow
}


# ------------------------------------------------------------
# 7. Remover diretórios residuais do Office
# ------------------------------------------------------------

Write-Step "Removendo arquivos residuais do Office"

$directories = @(
    "$env:ProgramFiles\Microsoft Office",
    "$env:ProgramFiles\Microsoft Office 15",
    "$env:ProgramFiles\Microsoft Office 16",
    "$env:ProgramFiles\Microsoft Office\root",
    "${env:ProgramFiles(x86)}\Microsoft Office",
    "${env:ProgramFiles(x86)}\Microsoft Office 15",
    "${env:ProgramFiles(x86)}\Microsoft Office 16",
    "${env:ProgramFiles(x86)}\Microsoft Office\root",
    "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun",
    "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun",
    "$env:ProgramData\Microsoft\Office",
    "$env:LOCALAPPDATA\Microsoft\Office",
    "$env:APPDATA\Microsoft\Office"
)

foreach ($directory in $directories) {

    if (Test-Path $directory) {

        Write-Host "Removendo: $directory" -ForegroundColor Yellow

        Remove-Item `
            -Path $directory `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}


# ------------------------------------------------------------
# 8. Backup das políticas antes de removê-las
# ------------------------------------------------------------

Write-Step "Fazendo backup das políticas do Office"

$backupDir = "$env:USERPROFILE\Desktop\Office_Cleanup_Backup"

New-Item -ItemType Directory `
    -Path $backupDir `
    -Force `
    | Out-Null

$registryKeys = @(
    "HKLM\SOFTWARE\Policies\Microsoft\Office",
    "HKLM\SOFTWARE\Microsoft\Office",
    "HKCU\Software\Microsoft\Office"
)

foreach ($key in $registryKeys) {

    $safeName = ($key -replace '[\\:]','_') + ".reg"

    $backupFile = Join-Path $backupDir $safeName

    reg.exe export "$key" "$backupFile" /y 2>$null | Out-Null
}


# ------------------------------------------------------------
# 9. Remover políticas e configurações residuais do Office
# ------------------------------------------------------------

Write-Step "Removendo políticas e configurações residuais do Office"

$policyPaths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Office",
    "HKLM:\SOFTWARE\WOW6432Node\Policies\Microsoft\Office",
    "HKCU:\SOFTWARE\Policies\Microsoft\Office"
)

foreach ($path in $policyPaths) {

    if (Test-Path $path) {

        Write-Host "Removendo política: $path" -ForegroundColor Yellow

        Remove-Item `
            -Path $path `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}


# ------------------------------------------------------------
# 10. Remover chaves Click-to-Run
# ------------------------------------------------------------

Write-Step "Removendo configurações Click-to-Run"

$clickToRunKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun"
)

foreach ($key in $clickToRunKeys) {

    if (Test-Path $key) {

        Write-Host "Removendo: $key" -ForegroundColor Yellow

        Remove-Item `
            -Path $key `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}


# ------------------------------------------------------------
# 11. Limpar arquivos temporários relacionados ao Office
# ------------------------------------------------------------

Write-Step "Limpando arquivos temporários"

$tempPatterns = @(
    "$env:TEMP\Office\*",
    "$env:TEMP\Microsoft Office\*",
    "$env:LOCALAPPDATA\Temp\Office\*",
    "$env:LOCALAPPDATA\Temp\Microsoft Office\*"
)

foreach ($pattern in $tempPatterns) {

    Remove-Item `
        -Path $pattern `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
}


# ------------------------------------------------------------
# 12. Verificação final
# ------------------------------------------------------------

Write-Step "Verificação final"

$remaining = @()

if (Test-Path "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun") {

    $remaining += "Click-to-Run (Registro)"
}

if (Test-Path "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun") {

    $remaining += "Click-to-Run (arquivos)"
}

if (Get-Service -Name "ClickToRunSvc" -ErrorAction SilentlyContinue) {

    $remaining += "ClickToRunSvc (serviço)"
}

if ($remaining.Count -eq 0) {

    Write-Host "`nLimpeza do Microsoft Office concluída." -ForegroundColor Green
}
else {

    Write-Host "`nAinda foram encontrados alguns componentes:" -ForegroundColor Yellow

    foreach ($item in $remaining) {

        Write-Host " - $item"
    }
}


# ------------------------------------------------------------
# Finalização
# ------------------------------------------------------------

Write-Host "`nBackup das configurações criado em:" -ForegroundColor Cyan
Write-Host $backupDir -ForegroundColor White

Write-Host "`nIMPORTANTE: reinicie o Windows antes de instalar o Microsoft 365 novamente." -ForegroundColor Green


$answer = Read-Host "`nDeseja reiniciar o computador agora? (S/N)"

if ($answer -match "^[Ss]$") {

    Restart-Computer -Force
}