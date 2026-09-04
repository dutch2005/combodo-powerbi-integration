$ErrorActionPreference = 'Stop'

$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskBuildScript = Join-Path $taskRoot 'scripts/build-release.ps1'
$taskArchive = Join-Path $taskRoot 'dist/combodo-powerbi-integration-1.1.0.zip'
$taskEolAttribute = git -C $taskRoot check-attr eol -- extension.xml

if (($taskEolAttribute -join "`n") -notmatch 'eol: lf') {
	throw 'Runtime text files must have a Git-enforced LF line ending.'
}

if (-not (Test-Path -LiteralPath $taskBuildScript -PathType Leaf)) {
	throw 'Release build script is missing.'
}

& $taskBuildScript
if (-not (Test-Path -LiteralPath $taskArchive -PathType Leaf)) {
	throw 'Release archive was not created.'
}
$taskFirstHash = (Get-FileHash -LiteralPath $taskArchive -Algorithm SHA256).Hash

& $taskBuildScript
$taskSecondHash = (Get-FileHash -LiteralPath $taskArchive -Algorithm SHA256).Hash
if ($taskFirstHash -ne $taskSecondHash) {
	throw 'Repeated builds must produce the same SHA-256 hash.'
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$taskZip = [System.IO.Compression.ZipFile]::OpenRead($taskArchive)
try {
	$taskEntries = @($taskZip.Entries | ForEach-Object { $_.FullName })
	$taskExpected = @(
		'combodo-powerbi-integration/data/en_us.data.combodo-powerbi-integration.xml',
		'combodo-powerbi-integration/datamodel.combodo-powerbi-integration.xml',
		'combodo-powerbi-integration/en.dict.combodo-powerbi-integration.php',
		'combodo-powerbi-integration/extension.xml',
		'combodo-powerbi-integration/license.txt',
		'combodo-powerbi-integration/module.combodo-powerbi-integration.php',
		'combodo-powerbi-integration/model.combodo-powerbi-integration.php'
	)
	$taskActual = @($taskEntries | Sort-Object)
	$taskExpected = @($taskExpected | Sort-Object)
	if (Compare-Object -ReferenceObject $taskExpected -DifferenceObject $taskActual) {
		throw 'Release archive entry set differs from the runtime allowlist.'
	}
} finally {
	$taskZip.Dispose()
}

$taskDist = Join-Path $taskRoot 'dist'
$taskTemporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('combodo-powerbi-package-test-' + [guid]::NewGuid().ToString('N'))
$taskSentinel = Join-Path $taskTemporaryRoot 'do-not-delete.txt'
$taskRejectedReparsePoint = $false
try {
	if (Test-Path -LiteralPath $taskDist) {
		Remove-Item -LiteralPath $taskDist -Recurse -Force
	}
	New-Item -ItemType Directory -Path $taskTemporaryRoot -Force | Out-Null
	Set-Content -LiteralPath $taskSentinel -Value 'sentinel' -NoNewline
	if ($IsWindows) {
		New-Item -ItemType Junction -Path $taskDist -Target $taskTemporaryRoot | Out-Null
	} else {
		New-Item -ItemType SymbolicLink -Path $taskDist -Target $taskTemporaryRoot | Out-Null
	}
	try {
		& $taskBuildScript
	} catch {
		$taskRejectedReparsePoint = $_.Exception.Message -match 'reparse|symbolic'
	}
	if (-not (Test-Path -LiteralPath $taskSentinel -PathType Leaf)) {
		throw 'Release build followed a reparse point and changed external data.'
	}
} finally {
	if (Test-Path -LiteralPath $taskDist) {
		Remove-Item -LiteralPath $taskDist -Force
	}
	if (Test-Path -LiteralPath $taskTemporaryRoot) {
		Remove-Item -LiteralPath $taskTemporaryRoot -Recurse -Force
	}
}
if (-not $taskRejectedReparsePoint) {
	throw 'Release build must reject a reparse-point dist directory.'
}

& $taskBuildScript
Write-Output "PASS: deterministic release archive $taskFirstHash"
