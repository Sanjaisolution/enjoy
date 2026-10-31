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
Write-Host "[+] Hardware lock and API key bound permanently." -ForegroundColor Green

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

# 9. Create Desktop User Manual
Write-Host "[*] Writing User Manual to Desktop..." -ForegroundColor Yellow
$ManualText = @'
================================================================================
                    STEALTHBRIDGE — USER MANUAL & PROTOCOL
================================================================================

1. HARDWARE FEEDBACK SIGNALS (AUDIO BEEPS & WEBCAM LED)
--------------------------------------------------------------------------------
Zero on-screen UI is used so proctoring software cannot detect the tool.
All notifications are delivered via hardware beeps and your laptop's webcam LED:

  • Question Captured : 1 Webcam LED Blink  + Single Short Beep
  • Solution Ready    : 2 Webcam LED Blinks + Dual Rising Beep
  • Typing Completed  : 3 Webcam LED Blinks + High Beep
  • Buffer Empty      : No Blink            + Low Warning Beep


2. STANDARD OPERATING WORKFLOW
--------------------------------------------------------------------------------
Step 1: Capture Question
  - Highlight the question text on screen.
  - Press [Ctrl + C] or [F8] (Force Copy bypass).
  - Confirm: 1 Webcam LED Blink + Single Beep.

Step 2: Select Answer Mode
  - Immediately after capturing, press one of the mode keys:
      [F1] or [Alt + 1] -> CODING MODE (Full, clean, compilable source code)
      [F2] or [Alt + 2] -> VIVA MODE   (Concise 2-3 line conceptual answer)
      [F3] or [Alt + 3] -> MCQ MODE    (Direct option letter + brief justification)

  - (Optional) Change Language before pressing F1:
      [Alt + 4] = Python
      [Alt + 5] = C++
      [Alt + 6] = Java
      [Alt + 7] = C
      [Alt + 8] = JavaScript
      [Alt + 0] = Auto-Detect

Step 3: Wait for Solution
  - Wait 2 to 4 seconds until you receive:
      2 Webcam LED Blinks + Dual Rising Beep.

Step 4: Output the Answer
  - Click into the code/text box, then choose an output method:

    [Method A] Instant Paste (Standard):
      - Press [Ctrl + V] or [F10] or [Alt + V].
      - Instantly injects the solution into the box.

    [Method B] Stealth Hardware Typer (For Monaco / Ace / Strict Editors):
      - Press [F9] or [Alt + 9].
      - Types character-by-character with natural timing.
      - To stop/cancel typing at any moment, press [Esc].


3. ADVANCED PRO-TIPS (MCQ TRICK & BOILERPLATE CODE FIX)
--------------------------------------------------------------------------------
[Pro-Tip 1] The MCQ Search Bar Trick (When No Input Box Exists):
  - In MCQ questions with only radio buttons/checkboxes, there is no text box
    available to paste into and read the answer.
  - The Solution:
      1. Capture question -> press [F3] (MCQ Mode).
      2. Wait for 2 blinks + dual beep.
      3. Press [Ctrl + F] to open the browser page search bar.
      4. Press [Ctrl + V] to paste the generated answer into the search bar.
      5. The answer appears in the search box, and the browser highlights
         the exact matching text on your screen.
      6. Click the corresponding radio button, then press [Esc] to close search.

[Pro-Tip 2] Complex Java / Boilerplate Questions (Eliminating Code Errors):
  - Long coding questions (especially in Java/C++) often provide pre-existing
    template code, helper classes, or fixed method signatures in the editor.
    If the AI generates code without seeing that template, it may mismatch
    class names or throw compilation errors.
  - The Solution:
      1. Copy the problem description.
      2. Paste it into the editor's answer box.
      3. Highlight the WHOLE combined block (the question text + the existing
         starter code inside the editor).
      4. Press [F1] (Coding Mode).
      5. Gemini will now see the exact required method structure and produce
         code that drops seamlessly into the template with zero errors.


4. SEB SESSION LIFECYCLE, EXIT BEHAVIOR & SHUTDOWN
--------------------------------------------------------------------------------
  • Complete In One Go:
    Always complete all questions inside the Safe Exam Browser (SEB) session.
    Avoid exiting and reopening SEB repeatedly during an exam.

  • Exiting SEB Turns Off The Engine:
    If you exit SEB while StealthBridge is running, the background engine
    detaches and enters a dormant / turned-off state.
    Hotkeys will NOT respond if you re-enter SEB in this state.

  • How to Recover / Restart:
    1. Go to your regular Windows desktop.
    2. Locate the StealthBridge icon running on your Windows Taskbar.
    3. Right-click the icon on the Taskbar -> click "Close window".
    4. Double-click the StealthBridge Desktop shortcut to start a fresh copy
       BEFORE re-entering SEB.

  • Proper Shutdown:
    The application has no window. To close it cleanly when done:
    Right-click the application icon on the Windows Taskbar -> "Close window".


5. CRITICAL WARNING: MANUAL COPY/PASTE VIOLATIONS
--------------------------------------------------------------------------------
  DO NOT ATTEMPT MANUAL COPY/PASTE WITH STANDARD SHORTCUTS OR EXTERNAL APPS!
  Monitored exam environments (SEB, Mettl, Wheebox, HackerRank, Mercer) attach
  clipboard inspection hooks. Manual unmanaged copying trips exam violation flags.
  Always use the tool's integrated hotkeys ([F8] to capture, [F10] / [F9] to paste).


6. CRITICAL WARNING: LAPTOP LENDING & PERMANENT API LOCK
--------------------------------------------------------------------------------
  DO NOT LEND YOUR LAPTOP TO FRIENDS, ROOMMATES, OR CLASSMATES!
  1. Your license and token are cryptographically locked to this motherboard.
  2. The registered API key is permanently bound to this machine.
  3. EXHAUSTION = PERMANENT LOCKOUT: If someone burns through your API quota,
     the software permanently locks. The API key CANNOT be changed or reset.
     You will have to buy a completely new license from the vendor.


7. COMPLETE UNINSTALLATION COMMAND
--------------------------------------------------------------------------------
To completely remove the software, license, shortcuts, and manual from your PC:
Open PowerShell and run:

Stop-Process -Name StealthBridge -Force -ErrorAction SilentlyContinue; Remove-Item -Path "$env:LOCALAPPDATA\StealthBridge" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path "$([Environment]::GetFolderPath('Desktop'))\StealthBridge.lnk", "$([Environment]::GetFolderPath('Desktop'))\USER_MANUAL.txt" -Force -ErrorAction SilentlyContinue; Write-Host "`n[+] StealthBridge completely uninstalled." -ForegroundColor Green
================================================================================
'@

[System.IO.File]::WriteAllText("$Desktop\USER_MANUAL.txt", $ManualText, [System.Text.UTF8Encoding]::new($false))

# 10. Purge Ephemeral Memory & Tokens
$Entered = $null
$Clean = $null
$ExpectedOTP = $null
$kBytes = $null
$HmacKey = $null
$StudentApiKey = $null
[GC]::Collect()

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   [+] Installation completed successfully!               " -ForegroundColor Green
Write-Host "   [+] StealthBridge shortcut created on Desktop.         " -ForegroundColor Green
Write-Host "   [+] USER_MANUAL.txt placed on Desktop.                 " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Start-Sleep -Seconds 3
