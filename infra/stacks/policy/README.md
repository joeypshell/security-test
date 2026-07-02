# Policy Stack Lane

This folder is reserved for Azure Policy definitions, initiatives, assignments, and exemptions.

Policy should use its own deployment workflow and approval path because policy changes can affect many subscriptions at once. Do not mix policy deployment with Key Vault deployment just because both use Bicep.
