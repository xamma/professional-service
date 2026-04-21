# IaaS cross AZ Layer 7 Loadbalancer

## Overview

A classic highly-available architecture: provisioning multiple VMs across different Availability Zones (AZs) and putting them behind a STACKIT L7 Load Balancer. This example also includes a Web Application Firewall (WAF) configuration to secure the backend workloads against malicious traffic.

## ⚠️ Important Note: [WAF Implementation](06-waf.tf)

Currently, the official STACKIT Terraform provider does not natively support Web Application Firewall (WAF) resources.

To bridge this gap and fully automate the deployment, this example utilizes a `restapi` provider as a workaround. This allows Terraform to interact directly with the STACKIT WAF REST API (`/v1alpha/projects/...`) to create and attach the Core Rule Sets and custom SecLang rules until native support is released.

## Testing the WAF

This deployment includes rules written in SecLang. These rules are specifically designed to safely verify that the WAF is successfully deployed, actively intercepting traffic, and applying your configurations.

Once `terraform apply` completes successfully, extract the public IP of your Load Balancer from the Terraform outputs:

```bash
# Export the Load Balancer IP to an environment variable
export ALB_IP=$(terraform output -raw alb_external_address)
```

Now, use curl to trigger the custom rules. Because the WAF is configured to block these specific signatures, both of the following commands should return an HTTP 403 Forbidden status code.

Test 1: Trigger via Query Parameter

```Bash
curl -k -I -X GET "https://${ALB_IP}/?waf_test=trigger"
```

Test 2: Trigger via Custom HTTP Header

```Bash
curl -k -I -H "X-WAF-Test: trigger" "https://${ALB_IP}/"
```
