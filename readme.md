# Vault LDAP Integration into Root Namespace - Configuring Additional Namespaces

This repository has been created to evaluate the integration of HashiCorp Vault Namespaces with OpenLDAP (and eventually OKTA's MFA).

## Use case configuration

Setup 4 teams TeamA - TeamD in LDAP and add a user in each team as follows:

- Team A: Mary Poppins - uid: mpoppins, password: passworda
- Team B: Ronan Keating - uid: rkeating, password: passwordb
- Team C: Dylan Thomas - uid: dthomas, password: passwordc
- Team D: Dawn French - uid: dfrench, password: passwordd

Requirements

- Users from TeamA will have admin access to the facebook Namespace
- Users from TeamB will have admin access to the twitter Namespace
- Users from TeamA and TeamB will have operator access to the shared Namespace
- Users from TeamC will have admin access to the shared Namespace
- Users from TeamD will have FULL VAULT ADMIN ACCESS
- LDAP is to be configured to attach to the root namespace and identities and policies used to map access to the various users

## Installation of this setup

- Prerequisites: Vagrant and Virtualbox should be installed on the host system
- Clone the repository to the host system from [github](git@github.com:allthingsclowd/vault_ldap_namespaces.git)
- Create a .hsm directory in the root of this newly cloned repository
- Copy the Vault Enterprise zipfile into the .hsm directory
- Source the var.env file
- Vagrant up
- Now Vault and LDAP should be available and integrated on the vagrant box - 192.168.2.11

``` bash
mkdir LDAP_DEMO
cd LDAP_DEMO
git clone git@github.com:allthingsclowd/vault_ldap_namespaces.git .
mkdir .hsm
cp <location of vault ent binary zip file> .hsm/
source var.env
vagrant up
vagrant ssh
```

[Useful LDAP Explorer for the MacOS](https://directory.apache.org/studio/download/download-macosx.html)
![image](https://user-images.githubusercontent.com/9472095/56169273-8b39bb00-5fd5-11e9-8fa5-e7a0e93cb081.png)

Lightweight Directory Access Protocol (LDAP) Directory Information Tree (DIT) can be seen in the slapd.ldif file.
![Vault LDAP Demo LDIF (1)](https://user-images.githubusercontent.com/9472095/56167790-0ba9ed00-5fd1-11e9-9669-b455c0ba44d0.png)

Check LDAP setup by running the following command on the vagrant box:

``` bash
ldapsearch -x -LLL -h localhost -D "cn=vaultuser,ou=people,dc=allthingscloud,dc=eu" -w vaultuser -b "ou=people,dc=allthingscloud,dc=eu" -s sub "(&(objectClass=inetOrgPerson)(uid=*))" memberOf
```
Output:
``` bash
dn: cn=Mary Poppins,ou=people,dc=allthingscloud,dc=eu
memberOf: cn=TeamA,ou=groups,dc=allthingscloud,dc=eu

dn: cn=Ronan Keating,ou=people,dc=allthingscloud,dc=eu
memberOf: cn=TeamB,ou=groups,dc=allthingscloud,dc=eu

dn: cn=Dylan Thomas,ou=people,dc=allthingscloud,dc=eu
memberOf: cn=TeamC,ou=groups,dc=allthingscloud,dc=eu

dn: cn=Dawn French,ou=people,dc=allthingscloud,dc=eu
memberOf: cn=TeamD,ou=groups,dc=allthingscloud,dc=eu

dn: cn=vaultuser,ou=people,dc=allthingscloud,dc=eu
memberOf: cn=vault,ou=groups,dc=allthingscloud,dc=eu

dn: cn=oktauser,ou=people,dc=allthingscloud,dc=eu
```
If the LDAP query does not return memberOf that contains the correct groups then verify that the filter is configured correctly - e.g. `(&(objectClass=inetOrgPerson)(uid=*))`

Vault's LDAP setup can be verified as follows on the vagrant box
##(Note: LDAP path has been set to a non standard mydemoldapserver)##

``` bash
source var.env
vault login -method=ldap -path=mydemoldapserver username=mpoppins
```

Output:

``` bash
Password (will be hidden): passworda
WARNING! The VAULT_TOKEN environment variable is set! This takes precedence
over the value set by this command. To use the value set by this command,
unset the VAULT_TOKEN environment variable or set it to the token displayed
below.

Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                    Value
---                    -----
token                  s.P0SKQFmbMLBlNeqLaPPHL9ci
token_accessor         XHh14VYhfMwroutTE2FLpbG6
token_duration         768h
token_renewable        true
token_policies         ["default"]
identity_policies      ["facebook_admin" "shared_operator"]
policies               ["default" "facebook_admin" "shared_operator"]
token_meta_username    mpoppins
```

Review the token details: 

``` bash
vault token lookup s.P0SKQFmbMLBlNeqLaPPHL9ci
```

Output:

``` bash
Key                            Value
---                            -----
accessor                       XHh14VYhfMwroutTE2FLpbG6
creation_time                  1555366376
creation_ttl                   768h
display_name                   mydemoldapserver-mpoppins
entity_id                      11bd523d-26a8-6f0e-d1a4-0ea4113a1c7e
expire_time                    2019-05-17T22:12:56.292121251Z
explicit_max_ttl               0s
external_namespace_policies    map[]
id                             s.P0SKQFmbMLBlNeqLaPPHL9ci
identity_policies              [facebook_admin shared_operator]
issue_time                     2019-04-15T22:12:56.292120972Z
meta                           map[username:mpoppins]
num_uses                       0
orphan                         true
path                           auth/mydemoldapserver/login/mpoppins
policies                       [default]
renewable                      true
ttl                            767h58m49s
type                           service
```

