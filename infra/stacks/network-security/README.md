# Network Security Stack Lane

This folder is reserved for NSG and WAF rule deployments.

NSG and WAF changes should use a separate deployment lane from Key Vault because their blast radius and validation requirements are different. Expected checks include rule collision detection, deny/allow review, and environment-specific approval.
