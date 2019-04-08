# Vault Multi-Factor Authentication

This repository has been created to evaluate the integration of HashiCorp Vault with OpenLDAP and OKTA's MFA.

Prerequisites
- OpenLDAP installation script
- OpenLDAP Configuration
- Installation of OKTA LDAP Agent
- Configuration of OKTA with LDAP
- Vault LDAP Authentication Backend Configuartion
- Vault OKTA MFA configuration

## Use case configuration

Setup four teams A - D in LDAP and add a user in each team as follows:
    - Team A: Mary Poppins
    - Team B: Ronan Keating
    - Team C: Dylan Thomas
    - Team D: Dawn French

Within Vault create a namespace for each team.
A shared namespace should exist for Team A & Team B.

MFA must be configured for all users

A Sentinel policy should be configured to restrict the CIDR from which users can authenticate to Vault.
