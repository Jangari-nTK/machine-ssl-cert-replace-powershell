# vCenter Server hostname
$VC_HOSTNAME = "vcsa.api.lab"

# vCenter Server IP address
$VC_IP_ADDR = "192.168.0.160"

# vCenter SSO credentials
$VC_USERNAME = "administrator@vsphere.local"
$VC_PASSWORD = "VMware1!"

# CSR spec
$CSR_INFO = ConvertTo-Json @{
    "spec" = @{
        "common_name" = "$VC_HOSTNAME"
        "country" = "JP"
        "email_address" = "admin@api.lab"
        "key_size" = 2048
        "locality" = "Shibuya-ku"
        "organization" = "My Lab"
        "organization_unit" = "API Unit"
        "state_or_province" = "Tokyo"
        "subject_alt_name" = @("$VC_IP_ADDR")
    }
}

# CA configuration string used by certreq.exe (CAHostName\CAName)
$CERTREQ_CONFIG = "ADCS.api.lab\api-ADCS-CA-1"

# CA certificate filepath
$CA_CERT = (Get-Item Env:HOMEPATH).value + "\cacert.cer"

# Certificate template
$CERT_TEMPLATE = "CertificateTemplate:WebServer"

# Whether skip SSL/TLS certificate verification.
$SKIP_SSL_VERIFICATION = $true


###############################################################################

if ($SKIP_SSL_VERIFICATION) {
    Write-Host "Skip SSL/TLS certificate verification"
    # Override ICertificatePolicy.CheckValidationResult method to skip SSL
    # certificate verification. This is not required if current Machine SSL
    # Certificate is already trusted.
    add-type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

$cred = New-Object System.Management.Automation.PSCredential(
          $VC_USERNAME,
          (ConvertTo-SecureString $VC_PASSWORD -AsPlainText -Force)
        )

try {
    Write-Host "Invoke 'Create Session' API..."
    $response = Invoke-WebRequest  -Method Post -Credential $cred `
                    -H @{ "vmware-use-header-authn" = "string"} `
                    -Uri "https://${VC_HOSTNAME}/rest/com/vmware/cis/session"
} catch [System.Net.WebException] {
    Write-Host $_.Exception
    $_.Exception.Response
    exit 1
}
Write-Host "Done."

$session_id = (ConvertFrom-Json $response.Content).value

$headers = @{
    "vmware-api-session-id" = ${session_id}
    "Content-Type" = "application/json"
}

try {
    Write-Host "Invoke 'Create vCenter TLS CSR' API..."
    $response = Invoke-WebRequest -Method Post -Headers $headers -Body $CSR_INFO `
        -Uri "https://${VC_HOSTNAME}/rest/vcenter/certificate-management/vcenter/tls-csr"
} catch [System.Net.WebException] {
    Write-Host $_.Exception
    $_.Exception.Response
    exit 1
}
Write-Host "Done."

$issue_date = Get-Date -Format "yyyyMMdd_HHmmss"
(ConvertFrom-Json $response.Content).value.csr > "${issue_date}.csr"

Write-Host "Submit certificate using certreq..."
certreq -submit -attrib ${CERT_TEMPLATE} `
    -config ${CERTREQ_CONFIG} `
    "${issue_date}.csr" `
    "${issue_date}.crt"
Write-Host "Done."

$issued_cert = (Get-Content "${issue_date}.crt" -Raw)
$root_cert = (Get-Content "${CA_CERT}" -Raw)
$replace_spec = (ConvertTo-Json @{
  "spec" = @{
    "cert" = "$issued_cert"
    "root_cert" = "$root_cert"
  }
}).Replace("\r\n","\n")

try {
    Write-Host "Invoke 'Set vCenter TLS' API..."
    $response = Invoke-WebRequest -Method Put -Headers $headers -Body $replace_spec `
        -Uri "https://${VC_HOSTNAME}/rest/vcenter/certificate-management/vcenter/tls"
} catch [System.Net.WebException] {
    Write-Host $_.Exception
    $_.Exception.Response
    exit 1
}
Write-Host "Done."

Write-Host "Certificate Replacement finished."
Write-Host "vCenter Server services will restart."