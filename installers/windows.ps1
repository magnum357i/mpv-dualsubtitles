	function Remove-IfExists {

		param(

			[string] $p
		)

		if (Test-Path $p) {

			Remove-Item $p -Force -Recurse > $null
		}
	}

	function Create-IfNotExists {

		param(

			[string] $p
		)

		if (!(Test-Path $p)) {

			New-Item -ItemType Directory -Path $p > $null
		}
	}

	function Download-Repo {

		param(

			[string] $repo,
			[string] $archive,
			[string] $temp
		)

		$tempPath = "$env:TEMP\$temp"

		Remove-IfExists -p $tempPath

		if (Get-Command git -ErrorAction SilentlyContinue) {

			git clone --depth 1 $repo $tempPath
		}
		else {

			Write-Host "Downloading..."
			New-Item -ItemType Directory -Path $tempPath > $null
			Invoke-WebRequest -Uri $archive -OutFile "$tempPath\main.zip" > $null

			if (Test-Path "$tempPath\main.zip") {

				Write-Host "Extracting..."
				Expand-Archive "$tempPath\main.zip" -DestinationPath $tempPath > $null
				Move-Item "$tempPath\*-main\*" "$tempPath" -Force > $null
				Remove-Item "$tempPath\*-main" -Force > $null
				Remove-Item "$tempPath\main.zip" -Force > $null
			}
		}
	}

	function Install-Plugin {

		param(

			[string] $temp,
			[string] $name
		)

		if (Test-Path "$env:TEMP\$temp\scripts\$name\main.lua") {

			Remove-IfExists -p "$env:APPDATA\mpv\scripts\$name"
			Remove-IfExists -p "$env:APPDATA\mpv\script-opts\$name.conf"
			Create-IfNotExists -p "$env:APPDATA\mpv\scripts\$name"
			Create-IfNotExists -p "$env:APPDATA\mpv\script-opts"
			Move-Item "$env:TEMP\$temp\scripts\$name\*" "$env:APPDATA\mpv\scripts\$name" -Force > $null
			Move-Item "$env:TEMP\$temp\script-opts\$name.conf" "$env:APPDATA\mpv\script-opts" -Force > $null
			Remove-Item "$env:TEMP\$temp" -Recurse -Force > $null
		}
		else {

			Write-Host "Files not found"
			Exit 1
		}
	}

	function Install-FFmpeg {

		winget install --id Gyan.FFmpeg -e
	}

    if (!(Get-Command "ffmpeg" -ErrorAction SilentlyContinue)) {

		try {

			Write-Host "[FFMPEG]"
			Install-FFmpeg
		}
		catch {

			Write-Host "FFmpeg not installed: $($_.Exception.Message)"
			Exit 1
		}
    }

	$scriptDir = "dualsubtitles"
	$tempDir   = "gitmpvdualsubtitles"
	$gitLinks  = @{

		repo    = "https://github.com/magnum357i/mpv-dualsubtitles"
		archive = "https://github.com/magnum357i/mpv-dualsubtitles/archive/refs/heads/main.zip"
	}

	try {

		Write-Host "[PLUGIN]"
		Download-Repo -repo $gitLinks.repo -archive $gitLinks.archive -temp $tempDir
		Install-Plugin -temp $tempDir -name $scriptDir
	}
	catch {

		Write-Host "Plugin not installed: $($_.Exception.Message)"
		Exit 1
	}

	if ($LASTEXITCODE -ne 0) {

    	Exit 1
	}

	Write-Host "Done!"