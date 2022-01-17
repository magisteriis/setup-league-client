<# Modified version of: https://github.com/MingweiSamuel/lcu-schema/blob/a309d795ddf0eba093cb6a6f54ffa9238e947f3a/update.ps1
MIT License

Copyright (c) 2019 Mingwei Samuel

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

#requires -PSEdition Core

$REGION_LOWER = $env:LOL_REGION.ToLower()
$REGION_UPPER = $env:LOL_REGION.ToUpper()

# Config.
$RCS_LOCKFILE = "$env:LOCALAPPDATA\Riot Games\Riot Client\Config\lockfile"
$RCS_ARGS = "--launch-product=league_of_legends --launch-patchline=live --region=$REGION_UPPER"

$LCU_DIR = "$env:RCS_DIR\League of Legends"
$LCU_LOCKFILE = "$LCU_DIR\lockfile"
$LCU_EXE = "$LCU_DIR\LeagueClient.exe"
$LCU_ARGS = "--region=$REGION_UPPER"

$INSTALLER_EXE = "$env:RUNNER_TEMP/install.$REGION_LOWER.exe"

$LOL_INSTALL_ID = 'league_of_legends.live'

function Stop-RiotProcesses {
    # Stop any existing processes.
    Stop-Process -Name 'RiotClientUx' -ErrorAction Ignore
    Stop-Process -Name 'LeagueClient' -ErrorAction Ignore
    Remove-Item $RCS_LOCKFILE -Force -ErrorAction Ignore
    Remove-Item $LCU_LOCKFILE -Force -ErrorAction Ignore
    Start-Sleep 5 # Wait for processes to settle.
}

function Invoke-RiotRequest {
    Param (
        [Parameter(Mandatory=$true)]  [String]$lockfile,
        [Parameter(Mandatory=$true)]  [String]$path,
        [Parameter(Mandatory=$false)] [String]$method = 'GET',
        [Parameter(Mandatory=$false)] $body = $null,
        [Parameter(Mandatory=$false)] [Int]$attempts = 100
    )

    While ($True) {
        Try {
            $lockContent = Get-Content $lockfile -Raw
            $lockContent = $lockContent.Split(':')
            $port = $lockContent[2];
            $pass = $lockContent[3];

            $pass = ConvertTo-SecureString $pass -AsPlainText -Force
            $cred = New-Object -TypeName PSCredential -ArgumentList 'riot', $pass

            $result = Invoke-RestMethod "https://127.0.0.1:$port$path" `
                -SkipCertificateCheck `
                -Method $method `
                -Authentication 'Basic' `
                -Credential $cred `
                -ContentType 'application/json' `
                -Body $($body | ConvertTo-Json)
            Return $result
        } Catch {
            $attempts--
            If ($attempts -le 0) {
                Write-Host "Failed to $method '$path'."
                Throw $_
            }
            Write-Host "Failed to $method '$path', retrying: $_"
            Start-Sleep 5
        }
    }
}

# Stop any existing processes.
Stop-RiotProcesses

& bash "$env:GITHUB_ACTION_PATH/Linux/Setup-Wine.sh"

# Install League if not installed.
If (-Not (Test-Path $LCU_EXE)) {
    Write-Host 'Installing LoL.'

    $attempts = 5
    While ($True) {
        Try {
            Invoke-WebRequest "https://lol.secure.dyn.riotcdn.net/channels/public/x/installer/current/live.$REGION_LOWER.exe" -OutFile $INSTALLER_EXE
            Break
        }
        Catch {
            $attempts--;
            If ($attempts -le 0) {
                Write-Host "Failed download LoL installer."
                Throw $_
            }
            Start-Sleep 5
        }
    }
    
    & bash "/usr/bin/wine-stable $INSTALLER_EXE --skip-to-install"

    # RCS starts, but install of LoL hangs, possibly due to .NET Framework 3.5 missing.
    # So we restart it and then it works.
    Invoke-RiotRequest $RCS_LOCKFILE '/patch/v1/installs'
    Stop-RiotProcesses

    Write-Host 'Restarting RCS'
    & bash "/usr/bin/wine-stable $env:RCS_EXE $RCS_ARGS"
    Start-Sleep 5

    $attempts = 15
    While ($True) {
        $status = Invoke-RiotRequest $RCS_LOCKFILE "/patch/v1/installs/$LOL_INSTALL_ID/status"
        If ('up_to_date' -Eq $status.patch.state) {
            Break
        }
        Write-Host "Installing LoL: $($status.patch.progress.progress)%"

        If ($attempts -Le 0) {
            Throw 'Failed to install LoL.'
        }
        $attempts--
        Start-Sleep 20
    }
    Write-Host 'LoL installed successfully.'
    Start-Sleep 1
    Stop-RiotProcesses
}
Else {
    Write-Host 'LoL already installed.'
}

# Start RCS.
Write-Host 'Starting RCS (via LCU).'
& bash "/usr/bin/wine-stable $LCU_EXE $LCU_ARGS"
Start-Sleep 5 # Wait for RCS to load so it doesn't overwrite system.yaml.

Start-Sleep 5

# Login to RCS to start the LCU.
Write-Host 'Logging into RCS, starts LCU.'
Invoke-RiotRequest $RCS_LOCKFILE '/rso-auth/v1/authorization/gas' 'POST' @{username=$env:LOL_USERNAME; password=$env:LOL_PASSWORD} | Out-Null

# Wait for LCU to update itself.
Start-Sleep 5
Invoke-RiotRequest $LCU_LOCKFILE '/lol-patch/v1/products/league_of_legends/state' # Burn first request.
Start-Sleep 10
$attempts = 40
While ($True) {
    $state = Invoke-RiotRequest $LCU_LOCKFILE '/lol-patch/v1/products/league_of_legends/state'
    Write-Host "LCU updating: $($state.action)" # Not that useful.
    If ('Idle' -Eq $state.action) {
        Break
    }

    If ($attempts -le 0) {
        Throw 'LCU failed to update.'
    }
    $attempts--
    Start-Sleep 20
}


$lockContent = Get-Content $LCU_LOCKFILE -Raw
$lockContent = $lockContent.Split(':')
$port = $lockContent[2];
$pass = $lockContent[3];
Write-Host "::set-output name=lcu-password::$pass"
Write-Host "::set-output name=lcu-port::$port"
Write-Host "::set-output name=lcu-directory::$LCU_DIR"

Write-Host 'Success!'
