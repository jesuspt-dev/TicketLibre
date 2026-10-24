param([Parameter(Mandatory=$true)][string]$RepositoryUrl)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Instala Git para Windows y vuelve a ejecutar este script.' }
if ($RepositoryUrl -notmatch '^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?$') { throw 'Indica una URL HTTPS de repositorio GitHub.' }
$root = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0) {
    git init -b main
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo inicializar el repositorio.' }
    git remote add origin $RepositoryUrl
} else {
    if ([IO.Path]::GetFullPath($root.Trim()) -ne [IO.Path]::GetFullPath((Get-Location).Path)) { throw 'Esta carpeta está dentro de otro repositorio. Copia el proyecto a una carpeta independiente o a su clon dedicado.' }
    $remote = git remote get-url origin
    if ($LASTEXITCODE -ne 0 -or $remote.Trim() -ne $RepositoryUrl) { throw "El remoto actual no coincide. No se ha cambiado: $remote" }
}
Write-Host 'Repositorio de destino:'
git remote -v
# Remote must be empty on the first upload, or this must already be its clone.
git ls-remote --exit-code origin refs/heads/main 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    git fetch origin main
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar el remoto.' }
    git merge-base --is-ancestor origin/main HEAD
    if ($LASTEXITCODE -ne 0) { throw 'El remoto contiene cambios que esta carpeta no incorpora. Usa el clon existente. No se reemplazará el historial remoto.' }
}
git add -A
if ($LASTEXITCODE -ne 0) { throw 'Falló git add.' }
git diff --cached --quiet
if ($LASTEXITCODE -eq 1) { git commit -m 'TicketLibre 1.0.1 - native iPhone receipt manager'; if ($LASTEXITCODE -ne 0) { throw 'Falló el commit. Comprueba nombre y correo de Git.' } }
git push -u origin HEAD:main
if ($LASTEXITCODE -ne 0) { throw 'Falló el push. No se ha forzado ni reemplazado ningún historial.' }
Write-Host 'Archivos publicados. Abre Actions > Build iPhone IPA para ver la compilación.'
