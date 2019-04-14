# Vault Namespaces with LDAP

This repository has been created to evaluate the integration of HashiCorp Vault Namespaces with OpenLDAP (and eventually OKTA's MFA).

## Use case configuration

Setup four teams TeamA - TeamD in LDAP and add a user in each team as follows:
    - Team A: Mary Poppins - uid: mpoppins, password: passworda
    - Team B: Ronan Keating - uid: rkeating, password: passwordb
    - Team C: Dylan Thomas - uid: dthomas, password: passwordc
    - Team D: Dawn French - uid: dfrench, password: passwordd

LDAP DIT can be seen here - slapd.ldif

Requirements

- Users from TeamA will have admin access to the TeamA facebook application Namespace
- Users from TeamB will have admin access to the TeamB twitter application Namespace
- Users from TeamA and TeamB will have operator access to the Shared Namespace
- Users from TeamC will have admin access to the Shared Namespace
- Users from TeamD will have FULL VAULT ADMIN ACCESS
- LDAP is to be configured to attach to the root namespace and identities and policies used to map access to the various users


[Useful LDAP Explorer for the MacOS](https://directory.apache.org/studio/download/download-macosx.html)


