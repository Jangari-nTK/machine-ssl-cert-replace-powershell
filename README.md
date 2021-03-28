# Replace Machine SSL Certificate using PowerShell

## Overview

This script performs the following tasks.

- Obtain a CSR from vCenter Server
- Submit a request to Microsoft CA
- Replace Machine SSL Certificate.

## References

- [Create Session | CIS | vSphere CIS REST APIs](https://developer.vmware.com/docs/vsphere-automation/v7.0U1/cis/rest/com/vmware/cis/session/post/)
- [Create vCenter TLS CSR | vSphere vCenter REST APIs](https://developer.vmware.com/docs/vsphere-automation/v7.0U1/vcenter/rest/vcenter/certificate-management/vcenter/tls-csr/post/)
- [certreq | Microsoft Docs](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/certreq_1)
- [Set vCenter TLS | Certificate Management | vSphere vCenter REST APIs](https://developer.vmware.com/docs/vsphere-automation/v7.0U1/vcenter/rest/vcenter/certificate-management/vcenter/tls/put/)