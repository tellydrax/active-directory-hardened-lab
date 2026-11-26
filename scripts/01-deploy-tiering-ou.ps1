<#
.SYNOPSIS
    Deploys an ANSSI-aligned Tiered Organizational Unit (OU) structure and security groups.
.NOTES
    Run as Domain Admin on the Domain Controller (e.g., corp.local).
#>

Import-Module ActiveDirectory

$DomainDN = (Get-ADDomain).DistinguishedName

# 1. Create Top-Level Tier & Archive OUs
$RootOUs = @(
    @{ Name = "Tier0-Infrastructure"; Desc = "Domain Controllers, PKI, and Tier 0 Admin Accounts" },
    @{ Name = "Tier1-Servers";        Desc = "Application, File, and Member Servers" },
    @{ Name = "Tier2-Workstations";   Desc = "Corporate Endpoints and Standard Users" },
    @{ Name = "Quarantine-Archive";   Desc = "Disabled and Inactive Accounts (ANSSI R46)" }
)

foreach ($ou in$RootOUs) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$($ou.Name)'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou.Name -Path$DomainDN -Description $ou.Desc -ProtectedFromAccidentalDeletion$true
        Write-Host "[+] Created OU: $($ou.Name)" -ForegroundColor Green
    }
}

# 2. Create Sub-OUs for Accounts, Groups, and Devices
$SubOUs = @(
    @{ Name = "Admin-Accounts"; Parent = "OU=Tier0-Infrastructure,$DomainDN" },
    @{ Name = "Member-Servers"; Parent = "OU=Tier1-Servers,$DomainDN" },
    @{ Name = "Service-Accounts"; Parent = "OU=Tier1-Servers,$DomainDN" },
    @{ Name = "Users";          Parent = "OU=Tier2-Workstations,$DomainDN" },
    @{ Name = "Computers";      Parent = "OU=Tier2-Workstations,$DomainDN" }
)

foreach ($sub in$SubOUs) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$($sub.Name)'" -SearchBase $sub.Parent -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $sub.Name -Path $sub.Parent -ProtectedFromAccidentalDeletion$true
        Write-Host "[+] Created Sub-OU: $($sub.Name)" -ForegroundColor Cyan
    }
}

# 3. Create Tiered Administration Security Groups
$Groups = @(
    @{ Name = "GRP-Tier0-Admins"; Path = "OU=Tier0-Infrastructure,$DomainDN"; Desc = "Restricted to Domain Controllers only" },
    @{ Name = "GRP-Tier1-Admins"; Path = "OU=Tier1-Servers,$DomainDN";        Desc = "Server administrators" },
    @{ Name = "GRP-Tier2-Helpdesk"; Path = "OU=Tier2-Workstations,$DomainDN"; Desc = "Workstation support technicians" }
)

foreach ($grp in$Groups) {
    if (-not (Get-ADGroup -Filter "Name -eq '$($grp.Name)'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $grp.Name -GroupScope Global -GroupCategory Security -Path $grp.Path -Description$grp.Desc
        Write-Host "[+] Created Security Group: $($grp.Name)" -ForegroundColor Yellow
    }
}
