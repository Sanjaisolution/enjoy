# ==============================================================================
# STEALTHBRIDGE 1-CLICK REMOTE DEPLOYER & NODE-LOCKER
# ==============================================================================
# 1. Config
$MASTER_KEY = "smd"
$EXE_URL = "https://github.com/Sanjaisolution/enjoy/releases/download/v1.0/StealthBridge.exe"

Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "         StealthBridge Provisioning & Security Lock       " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 2. Authenticate Seller (Password is hidden as you type)
$EnteredPass = Read-Host "Enter Seller Secret Password" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($EnteredPass)
$PlainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

if ($PlainPass -ne $MASTER_KEY) {
    Write-Host "`n[-] Authorization failed. Access denied." -ForegroundColor Red
    Start-Sleep -Seconds 2
    Exit
}

# 3. Prompt for Student's API Key
Write-Host "`n[+] Authorization verified." -ForegroundColor Green
$StudentApiKey = Read-Host "Enter Student Gemini API Key"
$StudentApiKey = $StudentApiKey.Trim()

if ([string]::IsNullOrWhiteSpace($StudentApiKey)) {
    Write-Host "[-] API Key cannot be empty. Aborting." -ForegroundColor Red
    Start-Sleep -Seconds 2
    Exit
}

# 4. Target Directory
$TargetDir = "$env:LOCALAPPDATA\StealthBridge"
if (!(Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

$TargetExe = "$TargetDir\StealthBridge.exe"

# 5. Download Executable from Server
Write-Host "`n[*] Downloading software package..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $EXE_URL -OutFile $TargetExe -UseBasicParsing
} catch {
    Write-Host "[-] Download failed. Check your download link." -ForegroundColor Red
    Exit
}

# 6. Extract Hardware Fingerprint (Motherboard UUID + CPU ID)
Write-Host "[*] Extracting hardware profile..." -ForegroundColor Yellow
$UUID = (Get-CimInstance Win32_ComputerSystemProduct).UUID
$CPUID = (Get-CimInstance Win32_Processor).ProcessorId

$RawHWID = "$UUID" + "::" + "$CPUID"
$Hasher = [System.Security.Cryptography.SHA256]::Create()
$HWID_Bytes = $Hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($RawHWID))
$HWID = [System.BitConverter]::ToString($HWID_Bytes).Replace("-", "").ToLower()

# 7. Compute Cryptographic Node-Lock Token (Binds HWID + API Key + Salt)
$SALT = "SB_2026_HWID_SECRET_SALT"
$HmacKey = [System.Text.Encoding]::UTF8.GetBytes("$MASTER_KEY" + "::" + "$SALT")
$HMAC = New-Object System.Security.Cryptography.HMACSHA256(,$HmacKey)
$PayloadStr = "$HWID" + "::" + "$StudentApiKey"
$Payload = [System.Text.Encoding]::UTF8.GetBytes($PayloadStr)
$SigBytes = $HMAC.ComputeHash($Payload)
$Signature = [System.BitConverter]::ToString($SigBytes).Replace("-", "").ToLower()

# 8. Write Locked License File
$License = @{
    hwid    = $HWID
    token   = $Signature
    api_key = $StudentApiKey
} | ConvertTo-Json

[System.IO.File]::WriteAllText("$TargetDir\license.dat", $License, [System.Text.UTF8Encoding]::new($false))
Write-Host "[+] Hardware lock and API key bound permanently." -ForegroundColor Green

# 9. Create Desktop Shortcut
Write-Host "[*] Creating Desktop shortcut..." -ForegroundColor Yellow
$WshShell = New-Object -ComObject WScript.Shell
$Desktop = [System.Environment]::GetFolderPath('Desktop')
$Shortcut = $WshShell.CreateShortcut("$Desktop\StealthBridge.lnk")
$Shortcut.TargetPath = $TargetExe
$Shortcut.WorkingDirectory = $TargetDir
$Shortcut.IconLocation = "$TargetExe,0"
$Shortcut.Description = "StealthBridge Engine"
$Shortcut.Save()

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   [+] Installation completed successfully!               " -ForegroundColor Green
Write-Host "   [+] StealthBridge icon created on the Desktop.         " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Start-Sleep -Seconds 3
