Param(
    [string]$KeyPath = "C:\Users\Usuario\Downloads\service-account.json",
    [int]$LimitDry = 200,
    [int]$LimitApply = 2000
)

# Opciones adicionales para rename script
[string]$MapFile = "./mappings.json",
[int]$Days = 30

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptDir\..\

Write-Host "Repositorio raíz: $(Get-Location)" -ForegroundColor Cyan

if (-not (Test-Path $KeyPath)) {
    Write-Error "Archivo de credenciales no encontrado: $KeyPath"
    exit 1
}

$raw = Get-Content $KeyPath -Raw
if ($raw -notmatch '"type"\s*:\s*"service_account"') {
    Write-Warning "El archivo indicado no parece ser una Service Account JSON (no contiene \"type\": \"service_account\")."
    $c = Read-Host "¿Continuar de todas formas? (s/n)"
    if ($c -ne 's') { Write-Host 'Abortado.'; exit 1 }
}

Write-Host "\n1) Ejecutando backup de documentos afectados (script: backup_affected_docs.js)" -ForegroundColor Yellow
& node ".\scripts\backup_affected_docs.js" --key $KeyPath --limit $LimitApply --out 'backup_aharhel_docs.json'
if ($LASTEXITCODE -ne 0) { Write-Error "El backup falló (exit $LASTEXITCODE). Revisa la salida."; exit 1 }

Write-Host "\nBackup completado. Archivo: backup_aharhel_docs.json" -ForegroundColor Green

Write-Host "\n2) Ejecutando dry-run de la migración (script: migrate_aharhel_gastos.js)" -ForegroundColor Yellow
& node ".\scripts\migrate_aharhel_gastos.js" --limit $LimitDry --key $KeyPath
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Dry-run terminó con código $LASTEXITCODE. Revisa la salida arriba." 
    $c = Read-Host "¿Continuar y revisar manualmente antes de aplicar? (s para seguir / cualquier otra para abortar)"
    if ($c -ne 's') { Write-Host 'Abortado.'; exit 1 }
}

Write-Host "\n2.b) Ejecutando dry-run de renombrado (script: rename_category_product.js)" -ForegroundColor Yellow
if (-not (Test-Path $MapFile)) {
    Write-Warning "No se encontró $MapFile. Puedes proporcionar un archivo de mappings con --MapFile o revisa la ruta.";
} else {
    & node ".\scripts\rename_category_product.js" --mapFile "$MapFile" --key "$KeyPath" --limit $LimitDry --days $Days
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Dry-run (rename) terminó con código $LASTEXITCODE. Revisa la salida arriba." 
        $c = Read-Host "¿Continuar y revisar manualmente antes de aplicar? (s para seguir / cualquier otra para abortar)"
        if ($c -ne 's') { Write-Host 'Abortado.'; exit 1 }
    }
}

$proceed = Read-Host "\n¿Deseas aplicar los cambios ahora? (s/n)"
if ($proceed -ne 's') { Write-Host 'No se aplicaron cambios. Ejecuta el script de nuevo con --apply cuando estés listo.'; exit 0 }

Write-Host "\n3) Aplicando migración (se hará backup automático por el script de Node)" -ForegroundColor Yellow
& node ".\scripts\migrate_aharhel_gastos.js" --apply --limit $LimitApply --key $KeyPath
if ($LASTEXITCODE -ne 0) { Write-Error "La aplicación falló (exit $LASTEXITCODE). Revisa la salida."; exit 1 }

if (Test-Path $MapFile) {
    Write-Host "\n3.b) Aplicando renombrado (script: rename_category_product.js)" -ForegroundColor Yellow
    & node ".\scripts\rename_category_product.js" --mapFile "$MapFile" --key "$KeyPath" --limit $LimitApply --days $Days --apply
    if ($LASTEXITCODE -ne 0) { Write-Error "La aplicación (rename) falló (exit $LASTEXITCODE). Revisa la salida."; exit 1 }
} else {
    Write-Host "\nOmitido: archivo de mappings no encontrado ($MapFile). No se aplicó renombrado." -ForegroundColor Yellow
}

Write-Host "\nMigración completada." -ForegroundColor Green
