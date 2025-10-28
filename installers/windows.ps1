	$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

	if (!($isAdmin)) {

    	Write-Host "Please run this script as administrator."
    	Exit 1
	}

	$requiredCommands = @("tar", "curl")

	foreach ($cmd in $requiredCommands) {

    	if (!(Get-Command $cmd -ErrorAction SilentlyContinue)) {

        	Write-Host "$($cmd): command not found"
        	Exit 1
    	}
	}

	function Remove-IfExists($p) {

		if (Test-Path $p) {

			Remove-Item $p -Force -Recurse > $null
		}
	}

	function Create-IfNotExists($p) {

		if (!(Test-Path $p)) {

			New-Item -ItemType Directory -Path $p > $null
		}
	}

	function Download-Repo($r, $a, $d) {

		if (Get-Command git -ErrorAction SilentlyContinue) {

			git clone --depth 1 $r $d
		}
		else {

			Write-Host "Downloading..."
			New-Item -ItemType Directory -Path $d > $null
			curl -# -L $a -o "$d\main.zip" > $null

			if (Test-Path "$d\main.zip") {

				Write-Host "Extracting..."
				tar -xf "$d\main.zip" -C $d > $null
				Move-Item "$d\*-main\*" $d -Force > $null
				Remove-Item "$d\*-main" -Force > $null
				Remove-Item "$d\main.zip" -Force > $null
			}
		}
	}

	try {
		$ffmpeg = @{

			path = "C:\FFmpeg"
			url  = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-full.7z"
		}

		Write-Host "[FFMPEG]"
		Remove-IfExists -p $ffmpeg.path
		Write-Host "Downloading..."
		New-Item -ItemType Directory -Path $ffmpeg.path > $null
		curl -# -L $ffmpeg.url -o "$($ffmpeg.path)\ffmpeg.7z" > $null

		if (Test-Path "$($ffmpeg.path)\ffmpeg.7z") {

			Write-Host "Extracting..."
			tar -xf "$($ffmpeg.path)\ffmpeg.7z" -C $ffmpeg.path > $null
			Move-Item "$($ffmpeg.path)\*build\bin\*" $ffmpeg.path -Force > $null
			Remove-Item "$($ffmpeg.path)\*build" -Recurse -Force > $null
			Remove-Item "$($ffmpeg.path)\ffmpeg.7z" -Force > $null

			if (Test-Path "$($ffmpeg.path)\ffmpeg.exe") {

				$envPath = [Environment]::GetEnvironmentVariable("Path", "Machine")

				if ($envPath -notmatch [Regex]::Escape($ffmpeg.path)) {

					Write-Host "Addding to PATH..."
    				[Environment]::SetEnvironmentVariable("Path", "$envPath;$($ffmpeg.path)", "Machine")
				}
			}
		}
		else {

			Write-Host "Failed to download"
			Exit 1
		}
	}
	catch {

		Write-Host "FFmpeg not installed: $($_.Exception.Message)"
		Exit 1
	}

	Write-Host "Done!"

	try {

		$scriptName = "dualsubtitles"
		$tempDir    = "gitmpvdualsubtitles"
		$gitLinks   = @{

			repo    = "https://github.com/magnum357i/mpv-dualsubtitles"
			archive = "https://github.com/magnum357i/mpv-dualsubtitles/archive/refs/heads/main.zip"
		}

		Write-Host "[PLUGIN]"
		Remove-IfExists -p "$env:TEMP\$tempDir"
		Download-Repo -r $gitLinks.repo -a $gitLinks.archive -d "$env:TEMP\$tempDir"

		if (Test-Path "$env:TEMP\$tempDir\scripts\$scriptName\main.lua") {

			Create-IfNotExists -p "$env:APPDATA\mpv\scripts"
			Create-IfNotExists -p "$env:APPDATA\mpv\script-opts"
			Remove-IfExists -p "$env:APPDATA\mpv\scripts\$scriptName"
			Move-Item -Path "$env:TEMP\$tempDir\scripts\$scriptName" -Destination "$env:APPDATA\mpv\scripts\$scriptName" -Force > $null
			Move-Item -Path "$env:TEMP\$tempDir\script-opts\dualsubtitles.conf" -Destination "$env:APPDATA\mpv\script-opts" -Force > $null
			Remove-Item "$env:TEMP\$tempDir" -Recurse -Force > $null
		}
		else {

			Write-Host "Failed to download"
			Exit 1
		}
	}
	catch {

		Write-Host "Plugin not installed: $($_.Exception.Message)"
		Exit 1
	}

	Write-Host "Done!"
	Write-Host "Finished!"
	Exit