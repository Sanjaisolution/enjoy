# ==============================================================================
# STEALTHBRIDGE 1-CLICK REMOTE DEPLOYER & CHALLENGE-RESPONSE ACTIVATOR
# ==============================================================================
$EXE_URL = "https://github.com/Sanjaisolution/enjoy/releases/download/v1.0/StealthBridge.exe"

Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "         StealthBridge Provisioning & Activation          " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Extract Hardware Profile (Motherboard UUID + CPU Processor ID)
Write-Host "`n[*] Inspecting hardware environment..." -ForegroundColor Yellow
$UUID = (Get-CimInstance Win32_ComputerSystemProduct).UUID
$CPUID = (Get-CimInstance Win32_Processor).ProcessorId

$RawHWID = "$UUID" + "::" + "$CPUID"
$Hasher = [System.Security.Cryptography.SHA256]::Create()
$HWID_Bytes = $Hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($RawHWID))
$HWID = [System.BitConverter]::ToString($HWID_Bytes).Replace("-", "").ToLower()
$MachineCode = ($HWID.Substring(0, 4) + "-" + $HWID.Substring(4, 4)).ToUpper()

# 2. Challenge Display
Write-Host "`n[*] Machine Code : " -NoNewline -ForegroundColor Yellow
Write-Host "$MachineCode" -ForegroundColor Green
Write-Host "`n[!] Call the vendor with this Machine Code to receive your 6-digit OTP.`n" -ForegroundColor Gray

# 3. Cryptographic Challenge-Response Verification
$obf = [byte[]](0x0F, 0x1E, 0x03, 0x13, 0x08, 0x0C, 0x03, 0x0F, 0x1D, 0x10, 0x08, 0x03, 0x6E, 0x6C, 0x6E, 0x6A, 0x03, 0x0F, 0x19, 0x1F, 0x09, 0x0E, 0x19)
$kBytes = [byte[]]($obf | ForEach-Object { $_ -bxor 0x5C })
$msgBytes = [System.Text.Encoding]::UTF8.GetBytes($MachineCode)
$hmac = New-Object System.Security.Cryptography.HMACSHA256(,$kBytes)
$digest = $hmac.ComputeHash($msgBytes)
$val = [System.BitConverter]::ToUInt32($digest, 0)
$ExpectedOTP = (($val % 900000) + 100000).ToString()

$Authorized = $false
$Attempts = 0
$MaxAttempts = 3

while ($Attempts -lt $MaxAttempts) {
    $Entered = Read-Host "Enter 6-Digit Activation OTP"
    $Clean = $Entered.Trim().Replace(" ", "").Replace("-", "")
    if ($Clean -eq $ExpectedOTP) {
        $Authorized = $true
        break
    }
    $Attempts++
    $Remaining = $MaxAttempts - $Attempts
    if ($Remaining -gt 0) {
        Write-Host "[-] Invalid OTP for Machine Code $MachineCode. Attempts remaining: $Remaining`n" -ForegroundColor Red
    }
}

if (-not $Authorized) {
    Write-Host "`n[-] Activation failed. Hardware unauthorized.`n" -ForegroundColor Red
    Start-Sleep -Seconds 3
    Exit
}

Write-Host "`n[+] Hardware activation verified." -ForegroundColor Green

# 4. Prompt for Student's API Key
$StudentApiKey = Read-Host "Enter Student Gemini API Key"
$StudentApiKey = $StudentApiKey.Trim()

if ([string]::IsNullOrWhiteSpace($StudentApiKey)) {
    Write-Host "[-] API Key cannot be empty. Aborting." -ForegroundColor Red
    Start-Sleep -Seconds 2
    Exit
}

# 5. Target Directory Setup
$TargetDir = "$env:LOCALAPPDATA\StealthBridge"
if (!(Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

$TargetExe = "$TargetDir\StealthBridge.exe"

# 6. Download Executable Package
Write-Host "`n[*] Downloading software package..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $EXE_URL -OutFile $TargetExe -UseBasicParsing
} catch {
    Write-Host "[-] Download failed. Check network or release link." -ForegroundColor Red
    Exit
}

# 7. Compute Permanent Node-Lock Token
$tokenObf = [byte[]](0x49, 0x57, 0x5E, 0x00, 0x00, 0x69, 0x78, 0x65, 0x08, 0x0A, 0x08, 0x0C, 0x65, 0x72, 0x6D, 0x73, 0x7E, 0x65, 0x69, 0x7F, 0x79, 0x68, 0x7F, 0x6E, 0x65, 0x69, 0x7B, 0x76, 0x6E)
$HmacKey = [byte[]]($tokenObf | ForEach-Object { $_ -bxor 0x3A })
$HMAC = New-Object System.Security.Cryptography.HMACSHA256(,$HmacKey)
$PayloadStr = "$HWID" + "::" + "$StudentApiKey"
$Payload = [System.Text.Encoding]::UTF8.GetBytes($PayloadStr)
$SigBytes = $HMAC.ComputeHash($Payload)
$Signature = [System.BitConverter]::ToString($SigBytes).Replace("-", "").ToLower()

$License = @{
    hwid    = $HWID
    token   = $Signature
    api_key = $StudentApiKey
} | ConvertTo-Json

[System.IO.File]::WriteAllText("$TargetDir\license.dat", $License, [System.Text.UTF8Encoding]::new($false))
Write-Host "[+] Hardware lock and API key  bound permanently." -ForegroundColor Green

# 8. Create Desktop Shortcut
Write-Host "[*] Creating Desktop shortcut..." -ForegroundColor Yellow
$WshShell = New-Object -ComObject WScript.Shell
$Desktop = [System.Environment]::GetFolderPath('Desktop')
$Shortcut = $WshShell.CreateShortcut("$Desktop\StealthBridge.lnk")
$Shortcut.TargetPath = $TargetExe
$Shortcut.WorkingDirectory = $TargetDir
$Shortcut.IconLocation = "$TargetExe,0"
$Shortcut.Description = "StealthBridge Engine"
$Shortcut.Save()

# 9. Purge Ephemeral Memory & Tokens
$Entered = $null
$Clean = $null
$ExpectedOTP = $null
$kBytes = $null
$HmacKey = $null
$StudentApiKey = $null
[GC]::Collect()

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   [+] Installation completed successfully!               " -ForegroundColor Green
Write-Host "   [+] StealthBridge icon created on Desktop.             " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Start-Sleep -Seconds 3
