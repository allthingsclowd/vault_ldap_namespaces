# Rough work

vault login -method=ldap -path=mydemoldapserver username=dfrench

ldapsearch -x -LLL -h localhost -D "cn=vaultuser,ou=people,dc=allthingscloud,dc=eu" -w vaultuser -b "ou=people,dc=allthingscloud,dc=eu" -s sub "(&(objectClass=inetOrgPerson)(uid=mpoppins))" memberOf

``` bash
dn: cn=Mary Poppins,ou=people,dc=allthingscloud,dc=eu
memberOf: cn=TeamA,ou=groups,dc=allthingscloud,dc=eu

vagrant@allthingscloud:~$
```

vault write -output-curl-string auth/mydemoldapserver/groups/TeamA policies=facebook_admin,test,bananas


sudo /vagrant/scripts/install_vault.sh



curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --header "X-Vault-Namespace: shared" \
    http://192.168.2.11:8200/v1/secret/transit/test


----------------------------------------



#HASHICORP VAULT TRANSIT KEYS with ENCRYPTION and DECRYPTION example

```

Policy to create, update a transit key and encrypt/decrypt data

name: shared_transit_create
``` hcl
path "shared/transit/*" {

  capabilities = [ "create", "update" ]

}
```

Policy to read, delete a transit key and ONLY decrypt data

name: shared_transit_read_delete

``` hcl
path "shared/transit/*" {

  capabilities = [ "read", "delete" ]

}

path "shared/transit/decrypt/*" {

  capabilities = [ "create", "update" ]

}
```

Login as user with key creation permissions

``` bash
vault login -method=ldap -path=mydemoldapserver username=mpoppins

Password (will be hidden): 
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                    Value
---                    -----
token                  s.YwcFJkGgagPsAo4hWtP1PgZm
token_accessor         53035a3ZM6Y5blkqEH9C2dUu
token_duration         768h
token_renewable        true
token_policies         ["default"]
identity_policies      ["shared_operator" "shared_transit_create"]
policies               ["default" "shared_operator" "shared_transit_create"]
token_meta_username    mpoppins

export VAULT_TOKEN=s.YwcFJkGgagPsAo4hWtP1PgZm
```

Create a transit key

``` bash
ENCRYPTIONKEYCONFIG='{
  "type": "rsa-2048"
}'

curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --header "X-Vault-Namespace: shared" \
    --request POST \
    -d "${ENCRYPTIONKEYCONFIG}" \
    http://192.168.2.11:8200/v1/transit/keys/gjldemokey
```

Enable key deletion

``` bash
ENABLEDELETION='{
  "deletion_allowed": true
}'

curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --header "X-Vault-Namespace: shared" \
    --request POST \
    -d "${ENABLEDELETION}" \
    http://192.168.2.11:8200/v1/transit/keys/gjldemokey/config
```

Read the new transit key > Expecting a failure for this user

``` bash
curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --header "X-Vault-Namespace: shared" \
    http://192.168.2.11:8200/v1/transit/keys/gjldemokey

{"errors":["1 error occurred:\n\t* permission denied\n\n"]}
```

Delete the new transit key > Expecting a failure for this user

``` bash
curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --header "X-Vault-Namespace: shared" \
    --request DELETE \
    http://192.168.2.11:8200/v1/transit/keys/gjldemokey

{"errors":["1 error occurred:\n\t* permission denied\n\n"]}
```
Encrypt some data - "Hello World"

Convert to base64

``` bash
DATA2ENCRYPT=`echo "Hello World" | base64`
```

Now encrypt the data

``` bash
ENCRYPTIONPACKAGE='{
  "plaintext": "'${DATA2ENCRYPT}'"
}'

ENCRYPTEDDATA=`curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --header "X-Vault-Namespace: shared" \
    --request POST \
    -d "${ENCRYPTIONPACKAGE}" \
    http://192.168.2.11:8200/v1/transit/encrypt/gjldemokey | jq -r ".data.ciphertext"`
```

Now let's swap over to the account with the read and delete capabilities

``` bash
vault login -method=ldap -path=mydemoldapserver username=rkeating
Password (will be hidden): 
WARNING! The VAULT_TOKEN environment variable is set! This takes precedence
over the value set by this command. To use the value set by this command,
unset the VAULT_TOKEN environment variable or set it to the token displayed
below.

Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                    Value
---                    -----
token                  s.fH0RiGEULZ2EdOTNMSRqdoQ9
token_accessor         wV9UT8QHTEbRECaNnPGM0LaO
token_duration         768h
token_renewable        true
token_policies         ["default"]
identity_policies      ["shared_operator" "shared_transit_read_delete"]
policies               ["default" "shared_operator" "shared_transit_read_delete"]
token_meta_username    rkeating

export VAULT_TOKEN=s.fH0RiGEULZ2EdOTNMSRqdoQ9
```

Once again we'll ensure this user cannot create a new key

``` bash
ENCRYPTIONKEYCONFIG='{
  "type": "ecdsa-p256"
}'

curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --header "X-Vault-Namespace: shared" \
    --request POST \
    -d "${ENCRYPTIONKEYCONFIG}" \
    http://192.168.2.11:8200/v1/transit/keys/gjldemokeytwo

{"errors":["1 error occurred:\n\t* permission denied\n\n"]}
```

Now let's read the transit key with this account - this should succeed

``` bash
curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --header "X-Vault-Namespace: shared" \
    http://192.168.2.11:8200/v1/transit/keys/gjldemokey

{"request_id":"0c09a4aa-e183-61f6-c302-8d35018c9b27","lease_id":"","renewable":false,"lease_duration":0,"data":{"allow_plaintext_backup":false,"deletion_allowed":true,"derived":false,"exportable":false,"keys":{"1":{"creation_time":"2019-05-15T19:37:29.081422045Z","name":"P-256","public_key":"-----BEGIN PUBLIC KEY-----\nMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEUNFzN/Z13n9gIqHlQC5fSMySa8p6\nyT93s5OYRRLHRHXluB66yuS2xDt6hwv9xpVHTTmIRogoJvLt2vof3utaVg==\n-----END PUBLIC KEY-----\n"}},"latest_version":1,"min_available_version":0,"min_decryption_version":1,"min_encryption_version":0,"name":"gjldemokey","supports_decryption":false,"supports_derivation":false,"supports_encryption":false,"supports_signing":true,"type":"ecdsa-p256"},"wrap_info":null,"warnings":null,"auth":null}
```

We're ready to decrypt out test data held in the environment variable ${ENCRYPTEDDATA}

``` bash
DECRYPTIONPACKAGE='{
  "ciphertext": "'${ENCRYPTEDDATA}'"
}'

DECRYPTEDDATA=`curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --header "X-Vault-Namespace: shared" \
    --request POST \
    -d "${DECRYPTIONPACKAGE}" \
    http://192.168.2.11:8200/v1/transit/decrypt/gjldemokey | jq -r ".data.plaintext"`
```

Now all we need to do is unencode the base64 encoded package

``` bash
echo ${DECRYPTEDDATA} | base64 -D
```

Finally delete the transit key

``` bash
curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --header "X-Vault-Namespace: shared" \
    --request DELETE \
    http://192.168.2.11:8200/v1/transit/keys/gjldemokey
```

Success!!!!