
$ErrorActionPreference = "Stop"

$pluginName = "dualsubtitles"
$tempDir    = "gitmpv$pluginName"
$repoLink   = "https://github.com/magnum357i/mpv-dualsubtitles"

function Path-RemoveIfExists {

	param([string] $p)

	if (Test-Path $p) { Remove-Item $p -Force -Recurse > $null }
}

function Path-CreateDirIfNotExists {

	param([string] $p)

	if (!(Test-Path $p)) { New-Item -ItemType Directory -Path $p > $null }
}

function Download-Repo {

	param([string] $url, [string] $temp)

	$tempPath = "$env:TEMP\$temp"

	Path-RemoveIfExists -p $tempPath

	if (Get-Command git -ErrorAction SilentlyContinue) {

		Write-Host "Cloning..."
		git clone --depth 1 --quiet $url $tempPath 2>&1
	}
	else {

		Write-Host "Downloading..."
		New-Item -ItemType Directory -Path $tempPath > $null
		Invoke-WebRequest -Uri "$url/archive/refs/heads/main.zip" -OutFile "$tempPath\main.zip" > $null

		if (Test-Path "$tempPath\main.zip") {

			Write-Host "Extracting..."
			Expand-Archive "$tempPath\main.zip" -DestinationPath $tempPath > $null
			Move-Item "$tempPath\*-main\*" $tempPath -Force > $null
			Remove-Item "$tempPath\*-main" -Force > $null
			Remove-Item "$tempPath\main.zip" -Force > $null
		}
		else {

			throw "Files not downloaded"
		}
	}
}

function Install-Plugin {

	param([string] $temp, [string] $name)

	if (Test-Path "$env:TEMP\$temp\scripts\$name\main.lua") {

		Write-Host "Installing..."
		Path-CreateDirIfNotExists -p "$env:APPDATA\mpv\scripts"
		Path-CreateDirIfNotExists -p "$env:APPDATA\mpv\script-opts"
		Path-RemoveIfExists -p "$env:APPDATA\mpv\scripts\$name"
		if (!(Test-Path "$env:APPDATA\mpv\script-opts\$name.conf")) { Move-Item "$env:TEMP\$temp\script-opts\$name.conf" "$env:APPDATA\mpv\script-opts" -Force > $null }
		Move-Item "$env:TEMP\$temp\scripts\$name" "$env:APPDATA\mpv\scripts" -Force > $null
		Remove-Item "$env:TEMP\$temp" -Recurse -Force > $null
	}
	else {

		throw "Files not found"
	}
}

function Install-FFmpeg {

	$wingetMessage = winget install --id Gyan.FFmpeg -e 2>&1 | Out-String
	$wingetMessage = $wingetMessage -replace "(?m)^[^a-zA-Z]*", ""

	if ($LASTEXITCODE -ne 0) {

		throw $wingetMessage
	}
}

Write-Host "[DEPENDENCIES]"
Write-Host "Checking..."

if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {

	Write-Host "FFmpeg is OK!" -ForegroundColor Green
}
else {

	try {

		Install-FFmpeg
	}
	catch {

		Write-Host "FFmpeg installation failed:" -ForegroundColor Red
		Write-Host $($_.Exception.Message) -ForegroundColor Red
		Exit 1
	}

	Write-Host "FFmpeg is ready! (restart shell)" -ForegroundColor Green
}

Write-Host "[PLUGIN]"

try {

	Download-Repo -url $repoLink -temp $tempDir
	Install-Plugin -temp $tempDir -name $pluginName
}
catch {

	Write-Host "Plugin installation failed:" -ForegroundColor Red
	Write-Host $($_.Exception.Message) -ForegroundColor Red
	Exit 1
}

Write-Host "Plugin is ready!" -ForegroundColor Green