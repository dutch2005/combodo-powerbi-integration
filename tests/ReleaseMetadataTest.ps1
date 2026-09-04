$ErrorActionPreference = 'Stop'

$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskWorkflow = Get-Content -Raw -LiteralPath (Join-Path $taskRoot '.github/workflows/php-compatibility.yml')
$taskManifest = [xml](Get-Content -Raw -LiteralPath (Join-Path $taskRoot 'extension.xml'))
$taskModule = Get-Content -Raw -LiteralPath (Join-Path $taskRoot 'module.combodo-powerbi-integration.php')
$taskBuild = Get-Content -Raw -LiteralPath (Join-Path $taskRoot 'scripts/build-release.ps1')

$taskRequiredPhp = @('7.0.8', '7.1', '7.2', '7.3', '7.4', '8.0', '8.1', '8.2', '8.3', '8.4', '8.5')
$taskMatrixMatch = [regex]::Match($taskWorkflow, '(?ms)^  php-matrix:.*?(?=^  release-package:)')
if (-not $taskMatrixMatch.Success) {
    throw 'Blocking PHP matrix job is missing.'
}
$taskMatrix = $taskMatrixMatch.Value
foreach ($taskVersion in $taskRequiredPhp) {
    if ($taskMatrix -notmatch ('(?m)^\s+- "' + [regex]::Escape($taskVersion) + '"\s*$')) {
        throw "Blocking Docker matrix is missing PHP $taskVersion."
    }
}
if ($taskWorkflow -notmatch '(?ms)php-nightly:.*?PHP 8\.6 nightly.*?continue-on-error:\s*true') {
    throw 'PHP 8.6 must remain a separate informational continue-on-error job.'
}
if ($taskMatrix -match '8\.6') {
    throw 'PHP 8.6 must not be part of the blocking Docker matrix.'
}
if ([string]$taskManifest.extension.version -ne '1.1.1') {
    throw 'extension.xml must declare version 1.1.1.'
}
if ($taskModule -notmatch "combodo-powerbi-integration/1\.1\.1") {
    throw 'module registration must declare version 1.1.1.'
}
if ($taskBuild -notmatch 'combodo-powerbi-integration-1\.1\.1') {
    throw 'Release packaging must use the 1.1.1 archive and directory names.'
}
Write-Output 'PASS: release metadata is synchronized for PHP 8.5 and extension 1.1.1.'
