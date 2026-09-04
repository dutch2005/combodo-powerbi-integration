$ErrorActionPreference = 'Stop'

$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskBuildScript = Join-Path $taskRoot 'scripts/build-release.ps1'
$taskArchive = Join-Path $taskRoot 'dist/combodo-powerbi-integration-1.1.1.zip'
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
$taskExpected = @(
	'combodo-powerbi-integration/data/en_us.data.combodo-powerbi-integration.xml',
	'combodo-powerbi-integration/datamodel.combodo-powerbi-integration.xml',
	'combodo-powerbi-integration/en.dict.combodo-powerbi-integration.php',
	'combodo-powerbi-integration/extension.xml',
	'combodo-powerbi-integration/license.txt',
	'combodo-powerbi-integration/module.combodo-powerbi-integration.php',
	'combodo-powerbi-integration/model.combodo-powerbi-integration.php'
)

function Assert-TaskArchive
{
	param([Parameter(Mandatory)][string]$Path)

	$taskZip = [System.IO.Compression.ZipFile]::OpenRead($Path)
	try {
		$taskEntries = @($taskZip.Entries | ForEach-Object { $_.FullName })
		$taskActual = @($taskEntries | Sort-Object)
		$taskSortedExpected = @($taskExpected | Sort-Object)
		if (Compare-Object -ReferenceObject $taskSortedExpected -DifferenceObject $taskActual) {
			throw 'Release archive entry set differs from the runtime allowlist.'
		}
		foreach ($taskEntry in $taskZip.Entries) {
			$taskReader = [System.IO.StreamReader]::new($taskEntry.Open(), [System.Text.Encoding]::UTF8)
			try {
				if ($taskReader.ReadToEnd().Contains("`r")) {
					throw "Release text entry must use canonical LF endings: $($taskEntry.FullName)"
				}
			} finally {
				$taskReader.Dispose()
			}
		}
	} finally {
		$taskZip.Dispose()
	}
}

Assert-TaskArchive -Path $taskArchive

$taskTempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$taskFixtureRoot = Join-Path $taskTempBase ('combodo-powerbi-fixture-' + [guid]::NewGuid().ToString('N'))
$taskExternalRoot = Join-Path $taskTempBase ('combodo-powerbi-external-' + [guid]::NewGuid().ToString('N'))
$taskFixtureDist = Join-Path $taskFixtureRoot 'dist'
$taskSentinel = Join-Path $taskExternalRoot 'do-not-delete.txt'
$taskRejectedReparsePoint = $false
$taskFixtureFiles = @(
	'scripts/build-release.ps1',
	'extension.xml',
	'module.combodo-powerbi-integration.php',
	'model.combodo-powerbi-integration.php',
	'datamodel.combodo-powerbi-integration.xml',
	'en.dict.combodo-powerbi-integration.php',
	'license.txt',
	'data/en_us.data.combodo-powerbi-integration.xml'
)

try {
	New-Item -ItemType Directory -Path $taskFixtureRoot, $taskExternalRoot -Force | Out-Null
	foreach ($taskRelativePath in $taskFixtureFiles) {
		$taskFixturePath = Join-Path $taskFixtureRoot $taskRelativePath
		New-Item -ItemType Directory -Path (Split-Path -Parent $taskFixturePath) -Force | Out-Null
		Copy-Item -LiteralPath (Join-Path $taskRoot $taskRelativePath) -Destination $taskFixturePath
	}
	Set-Content -LiteralPath $taskSentinel -Value 'sentinel' -NoNewline
	if ($IsWindows) {
		New-Item -ItemType Junction -Path $taskFixtureDist -Target $taskExternalRoot | Out-Null
	} else {
		New-Item -ItemType SymbolicLink -Path $taskFixtureDist -Target $taskExternalRoot | Out-Null
	}
	try {
		& (Join-Path $taskFixtureRoot 'scripts/build-release.ps1')
	} catch {
		$taskRejectedReparsePoint = $_.Exception.Message -match 'reparse|symbolic'
	}
	if (-not (Test-Path -LiteralPath $taskSentinel -PathType Leaf)) {
		throw 'Release build followed a reparse point and changed external data.'
	}
} finally {
	if (Test-Path -LiteralPath $taskFixtureDist) {
		Remove-Item -LiteralPath $taskFixtureDist -Force
	}
	foreach ($taskTempPath in @($taskFixtureRoot, $taskExternalRoot)) {
		$taskFullTempPath = [System.IO.Path]::GetFullPath($taskTempPath)
		if (-not $taskFullTempPath.StartsWith($taskTempBase, [System.StringComparison]::OrdinalIgnoreCase) -or
			(Split-Path -Leaf $taskFullTempPath) -notmatch '^combodo-powerbi-(fixture|external)-[a-f0-9]{32}$') {
			throw "Refusing to clean unexpected test path: $taskFullTempPath"
		}
		if (Test-Path -LiteralPath $taskFullTempPath) {
			Remove-Item -LiteralPath $taskFullTempPath -Recurse -Force
		}
	}
}
if (-not $taskRejectedReparsePoint) {
	throw 'Release build must reject a reparse-point dist directory.'
}

& $taskBuildScript
$taskFinalHash = (Get-FileHash -LiteralPath $taskArchive -Algorithm SHA256).Hash
if ($taskFirstHash -ne $taskFinalHash) {
	throw 'Build after the safety test must retain the deterministic SHA-256 hash.'
}
Assert-TaskArchive -Path $taskArchive
Write-Output "PASS: deterministic release archive $taskFinalHash"
