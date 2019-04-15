# Vault Namespaces with LDAP

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

LDAP DIT can be seen in slapd.ldif

Check LDAP setup by running the following command on the vagrant box:

``` bash
ldapsearch -x -LLL -h localhost -D "cn=vaultuser,ou=people,dc=allthingscloud,dc=eu" -w vaultuser -b "ou=people,dc=allthingscloud,dc=eu" -s sub "(&(objectClass=inetOrgPerson)(uid=mpoppins))" memberOf
```

Check Vault LDAP setup as follows on the vagrant box (Note: LDAP path has been set to a non standard mydemoldapserver):

``` bash
source var.env
vault login -method=ldap -path=mydemoldapserver username=dfrench
```
Output:

``` bash
Password (will be hidden): passwordd
WARNING! The VAULT_TOKEN environment variable is set! This takes precedence
over the value set by this command. To use the value set by this command,
unset the VAULT_TOKEN environment variable or set it to the token displayed
below.

Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                    Value
---                    -----
token                  s.I9eyhwCVlyw0jyeZEVb7C9tS
token_accessor         1QpkpxyOvLH3CnvloT3FHU11
token_duration         768h
token_renewable        true
token_policies         ["default" "vaultadmin"]
identity_policies      []
policies               ["default" "vaultadmin"]
token_meta_username    dfrench
```

Check the assigned policies - 

``` bash
vault token lookup s.I9eyhwCVlyw0jyeZEVb7C9tS
```

Output:

``` bash
Key                            Value
---                            -----
accessor                       1QpkpxyOvLH3CnvloT3FHU11
creation_time                  1555258470
creation_ttl                   768h
display_name                   mydemoldapserver-dfrench
entity_id                      883aa416-3ba4-ab14-6e6d-d34f4c001e01
expire_time                    2019-05-16T16:14:30.872451102Z
explicit_max_ttl               0s
external_namespace_policies    map[oGKtV:[facebook_admin] 1ILtu:[twitter_admin] 6SWkG:[shared_admin]]
id                             s.I9eyhwCVlyw0jyeZEVb7C9tS
identity_policies              <nil>
issue_time                     2019-04-14T16:14:30.872450878Z
meta                           map[username:dfrench]
num_uses                       0
orphan                         true
path                           auth/mydemoldapserver/login/dfrench
policies                       [default vaultadmin]
renewable                      true
ttl                            767h59m32s
type                           service
```

# What's not working?

Although all LDAP users can successfully authenticate against LDAP, and external namespace policies do appear to be getting applied, namespace users can not navigate correctly or consume the Vault UI.

For example: 

The facebook_admin policy deployed in the root namespace but with pathing to `facebook/...` looks like this:

``` hcl
# Manage namespaces
path "facebook/sys/namespaces/*" {
   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage policies
path "facebook/sys/policies/acl/*" {
   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List policies
path "facebook/sys/policies/acl" {
   capabilities = ["list"]
}

# Enable and manage secrets engines
path "facebook/sys/mounts/*" {
   capabilities = ["create", "read", "update", "delete", "list"]
}

# List available secret engines
path "facebook/sys/mounts" {
  capabilities = [ "read" ]
}

# Create and manage entities and groups
path "facebook/identity/*" {
   capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage tokens
path "facebook/auth/token/*" {
   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
```

I'm guessing that I need to modify the default policy to facilitate non-root namespace users access to their policies which are in the root namespace?

Current default policy is as follows:

``` hcl

# Allow tokens to look up their own properties
path "auth/token/lookup-self" {
    capabilities = ["read"]
}

# Allow tokens to renew themselves
path "auth/token/renew-self" {
    capabilities = ["update"]
}

# Allow tokens to revoke themselves
path "auth/token/revoke-self" {
    capabilities = ["update"]
}

# Allow a token to look up its own capabilities on a path
path "sys/capabilities-self" {
    capabilities = ["update"]
}

# Allow a token to look up its own entity by id or name
path "identity/entity/id/{{identity.entity.id}}" {
  capabilities = ["read"]
}
path "identity/entity/name/{{identity.entity.name}}" {
  capabilities = ["read"]
}


# Allow a token to look up its resultant ACL from all policies. This is useful
# for UIs. It is an internal path because the format may change at any time
# based on how the internal ACL features and capabilities change.
path "sys/internal/ui/resultant-acl" {
    capabilities = ["read"]
}

# Allow a token to renew a lease via lease_id in the request body; old path for
# old clients, new path for newer
path "sys/renew" {
    capabilities = ["update"]
}
path "sys/leases/renew" {
    capabilities = ["update"]
}

# Allow looking up lease properties. This requires knowing the lease ID ahead
# of time and does not divulge any sensitive information.
path "sys/leases/lookup" {
    capabilities = ["update"]
}

# Allow a token to manage its own cubbyhole
path "cubbyhole/*" {
    capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow a token to wrap arbitrary values in a response-wrapping token
path "sys/wrapping/wrap" {
    capabilities = ["update"]
}

# Allow a token to look up the creation time and TTL of a given
# response-wrapping token
path "sys/wrapping/lookup" {
    capabilities = ["update"]
}

# Allow a token to unwrap a response-wrapping token. This is a convenience to
# avoid client token swapping since this is also part of the response wrapping
# policy.
path "sys/wrapping/unwrap" {
    capabilities = ["update"]
}

# Allow general purpose tools
path "sys/tools/hash" {
    capabilities = ["update"]
}
path "sys/tools/hash/*" {
    capabilities = ["update"]
}
path "sys/tools/random" {
    capabilities = ["update"]
}
path "sys/tools/random/*" {
    capabilities = ["update"]
}

# Allow checking the status of a Control Group request if the user has the
# accessor
path "sys/control-group/request" {
    capabilities = ["update"]
}

```

I've used the following guide - [`Additional Discussion Section`](https://learn.hashicorp.com/vault/operations/namespaces#additional-discussion) to create the basis for this deployment
