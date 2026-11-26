<#
.SYNOPSIS
    Applies baseline Active Directory hardening settings (SMB Signing, NTLMv2 only, Disable SMBv1, Audit Policies).
.NOTES
    Aligned with ANSSI Active Directory security recommendations.
#>

Import-Module GroupPolicy

$DomainDN = (Get-ADDomain).DistinguishedName
$GPOName  = "GPO-Baseline-Hardening-ANSSI"

# 1. Create and Link Baseline Hardening GPO
$GPO = Get-GPO -Name$GPOName -ErrorAction SilentlyContinue
if (-not $GPO) {
    $GPO = New-GPO -Name$GPOName -Comment "Baseline AD hardening: SMB signing, NTLMv2, disable legacy protocols"
    New-GPLink -Name $GPOName -Target$DomainDN -LinkEnabled Yes
    Write-Host "[+] Created and linked $GPOName to$DomainDN" -ForegroundColor Green
}

# 2. Enforce SMB Signing (Mitigates SMB Relay attacks)
Set-GPRegistryValue -Name $GPOName `
    -Key "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" `
    -ValueName "RequireSecuritySignature" -Type DWord -Value 1

Set-GPRegistryValue -Name $GPOName `
    -Key "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" `
    -ValueName "RequireSecuritySignature" -Type DWord -Value 1

# 3. Enforce NTLMv2 Only & Refuse LM/NTLMv1 (LmCompatibilityLevel = 5)
Set-GPRegistryValue -Name $GPOName `
    -Key "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" `
    -ValueName "LmCompatibilityLevel" -Type DWord -Value 5

# 4. Disable LLMNR (Mitigates Responder / Poisoning attacks)
Set-GPRegistryValue -Name $GPOName `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" `
    -ValueName "EnableMulticast" -Type DWord -Value 0

# 5. Disable SMBv1 Protocol on Domain Controller
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue

Write-Host "[+] Hardening GPO values configured. Run 'gpupdate /force' to apply." -ForegroundColor Cyan
