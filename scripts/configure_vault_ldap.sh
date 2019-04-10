

export VAULT_ADDR=http://192.168.2.11:8200
export VAULT_TOKEN=reallystrongpassword

# Check existing ldap configuration

curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    ${VAULT_ADDR}/v1/auth/ldap/config

# When backend is not enabled
# {"errors":["no handler for route 'auth/ldap/config'"]}

# Enable a demo ldap auth backend on /auth/mydemoldap

LDAPBACKENDCONFIG='{
  "type": "ldap",
  "description": "Login with OpenLDAP Server"
}'

curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request POST \
    --data "${LDAPBACKENDCONFIG}" \
    ${VAULT_ADDR}/v1/sys/auth/mydemoldapserver

# If all went well above there's no output response :(

# Check for config associated with new demo path
curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    ${VAULT_ADDR}/v1/auth/mydemoldapserver/config

# This now returns -
# {
#   "request_id": "e6649b1f-bef0-61f6-0866-9d07ac41dded",
#   "lease_id": "",
#   "renewable": false,
#   "lease_duration": 0,
#   "data": {
#     "binddn": "",
#     "case_sensitive_names": false,
#     "certificate": "",
#     "deny_null_bind": true,
#     "discoverdn": false,
#     "groupattr": "cn",
#     "groupdn": "",
#     "groupfilter": "(|(memberUid={{.Username}})(member={{.UserDN}})(uniqueMember={{.UserDN}}))",
#     "insecure_tls": false,
#     "starttls": false,
#     "tls_max_version": "tls12",
#     "tls_min_version": "tls12",
#     "upndomain": "",
#     "url": "ldap://127.0.0.1",
#     "use_token_groups": false,
#     "userattr": "cn",
#     "userdn": ""
#   },
#   "wrap_info": null,
#   "warnings": null,
#   "auth": null
# }

# To undo all this great work simply issue the following command

curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request DELETE \
    ${VAULT_ADDR}/v1/sys/auth/mydemoldapserver

# Okay so know let's configure our LDAP server for real

LDAPCONFIG="'{
  \"binddn\": \\\"cn=vaultuser,ou=users,dc=allthingscloud,dc=eu\\\",
  \"bindpass\": \\\"vaultuser\\\",
  \"deny_null_bind\": \\\"true\\\",
  \"discoverdn\": \\\"false\\\",
  \"groupattr\": \\\"cn\\\",
  \"groupdn\": \\\"ou=groups,dc=allthingscloud,dc=eu\\\",
  \"groupfilter\": \\\"(memberOf=cn=vault,ou=groups,dc=allthingscloud,dc=eu)\\\",
  \"insecure_tls\": \\\"true\\\",
  \"starttls\": \\\"false\\\",
  \"tls_max_version\": \\\"tls12\\\",
  \"tls_min_version\": \\\"tls12\\\",
  \"url\": \\\"ldap://192.168.2.11\\\",
  \"userattr\": \\\"uid\\\",
  \"userdn\": \\\"ou=users,dc=allthingscloud,dc=eu\\\"
}'"

curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request POST \
    --data ${LDAPCONFIG} \
    ${VAULT_ADDR}/v1/sys/auth/mydemoldapserver/config

# Keep getting this error - 
# {"errors":["backend type must be specified as a string"]}

# will try the cli to see if that masks my error

vault write auth/mydemoldapserver/config \
    url="ldap://192.168.2.11:389" \
    userdn="ou=people,dc=allthingscloud,dc=eu" \
    groupdn="ou=groups,dc=allthingscloud,dc=eu" \
    groupfilter="(&(objectClass=inetOrgPerson)(uid=*)(|(memberOf=cn=TeamA,ou=groups,dc=allthingscloud,dc=eu)(memberOf=cn=TeamB,ou=groups,dc=allthingscloud,dc=eu)(memberOf=cn=TeamC,ou=groups,dc=allthingscloud,dc=eu)(memberOf=cn=vault,ou=groups,dc=allthingscloud,dc=eu)))" \
    groupattr="cn" \
    upndomain="allthingscloud.eu" \
    insecure_tls=true \
    starttls=false \
    userattr="uid" \
    binddn="cn=vaultuser,ou=people,dc=allthingscloud,dc=eu" \
    bindpass="vaultuser"

vault login -method=ldap -path=mydemoldapserver/ username=mpoppins




ldapsearch -x -LLL -h localhost -D "cn=Dawn French,ou=people,dc=allthingscloud,dc=eu" -w passwordd -b "ou=people,dc=allthingscloud,dc=eu" memberOf


(&
    (objectClass=inetOrgPerson)
    (uid=*)
    (|
        (memberOf=cn=TeamA,ou=groups,dc=allthingscloud,dc=eu)
        (memberOf=cn=TeamB,ou=groups,dc=allthingscloud,dc=eu)
        (memberOf=cn=TeamC,ou=groups,dc=allthingscloud,dc=eu)
        (memberOf=cn=vault,ou=groups,dc=allthingscloud,dc=eu)
    )
)

(&(objectClass=inetOrgPerson)(uid=*)(|(memberOf=cn=TeamA,ou=groups,dc=allthingscloud,dc=eu)(memberOf=cn=TeamB,ou=groups,dc=allthingscloud,dc=eu)(memberOf=cn=TeamC,ou=groups,dc=allthingscloud,dc=eu)(memberOf=cn=vault,ou=groups,dc=allthingscloud,dc=eu)))

vault write auth/mydemoldapserver/config \
    url="ldap://192.168.2.11:389" \
    userdn="ou=people,dc=allthingscloud,dc=eu" \
    groupdn="ou=groups,dc=allthingscloud,dc=eu" \
    groupfilter="(memberOf=cn=vault,ou=groups,dc=allthingscloud,dc=eu)" \
    groupattr="cn" \
    upndomain="allthingscloud.eu" \
    insecure_tls=true \
    starttls=false \
    userattr="uid" \
    binddn="cn=vaultuser,ou=people,dc=allthingscloud,dc=eu" \
    bindpass="vaultuser"

vault login -method=ldap -path=mydemoldapserver/ username=mpoppins

LDAPCONFIG="'{
  \"binddn\": \\\"cn=vaultuser,ou=users,dc=allthingscloud,dc=eu\\\",
  \"bindpass\": \\\"vaultuser\\\",
  \"deny_null_bind\": \\\"true\\\",
  \"discoverdn\": \\\"false\\\",
  \"groupattr\": \\\"cn\\\",
  \"groupdn\": \\\"ou=groups,dc=allthingscloud,dc=eu\\\",
  \"groupfilter\": \\\"(memberOf=cn=vault,ou=groups,dc=allthingscloud,dc=eu)\\\",
  \"insecure_tls\": \\\"true\\\",
  \"starttls\": \\\"false\\\",
  \"tls_max_version\": \\\"tls12\\\",
  \"tls_min_version\": \\\"tls12\\\",
  \"url\": \\\"ldap://192.168.2.11\\\",
  \"userattr\": \\\"uid\\\",
  \"userdn\": \\\"ou=users,dc=allthingscloud,dc=eu\\\"
}'"

curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request POST \
    --data ${LDAPCONFIG} \
    ${VAULT_ADDR}/v1/sys/auth/mydemoldapserver/config

LDAPCONFIG="'{
  "binddn": \"cn=vaultuser,ou=users,dc=allthingscloud,dc=eu\",
  "bindpass": \"vaultuser\",
  "deny_null_bind": \"true\",
  "discoverdn": \"false\",
  "groupattr": \"cn\",
  "groupdn": \"ou=groups,dc=allthingscloud,dc=eu\",
  "groupfilter": \"(memberOf=cn=vault,ou=groups,dc=allthingscloud,dc=eu)\",
  "insecure_tls": \"true\",
  "starttls": \"false\",
  "tls_max_version": \"tls12\",
  "tls_min_version": \"tls12\",
  "url": \"ldap://192.168.2.11\",
  "userattr": \"uid\",
  "userdn": \"ou=users,dc=allthingscloud,dc=eu\"
}'"

curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request POST \
    --data ${LDAPCONFIG} \
    ${VAULT_ADDR}/v1/sys/auth/mydemoldapserver/config


LDAPCONFIG='{
  "binddn": "cn=vaultuser,ou=users,dc=allthingscloud,dc=eu",
  "bindpass": "vaultuser",
  "deny_null_bind": "true",
  "discoverdn": "false",
  "groupattr": "cn",
  "groupdn": "ou=groups,dc=allthingscloud,dc=eu",
  "groupfilter": "(memberOf=cn=vault,ou=groups,dc=allthingscloud,dc=eu)",
  "insecure_tls": "true",
  "starttls": "false",
  "tls_max_version": "tls12",
  "tls_min_version": "tls12",
  "url": "ldap://192.168.2.11",
  "userattr": "uid",
  "userdn": "ou=users,dc=allthingscloud,dc=eu"
}'

curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request POST \
    --data "${LDAPCONFIG}" \
    ${VAULT_ADDR}/v1/sys/auth/mydemoldapserver/config

vault write -output-curl-string auth/mydemoldapserver/config \
    url="ldap://192.168.2.11:389" \
    userdn="ou=people,dc=allthingscloud,dc=eu" \
    groupdn="ou=groups,dc=allthingscloud,dc=eu" \
    groupfilter="(memberOf=cn=vault,ou=groups,dc=allthingscloud,dc=eu)" \
    groupattr="cn" \
    upndomain="allthingscloud.eu" \
    insecure_tls=true \
    starttls=false \
    userattr="uid" \
    binddn="cn=vaultuser,ou=people,dc=allthingscloud,dc=eu" \
    bindpass="vaultuser"

vault login -method=ldap -path=mydemoldapserver/ username=mpoppins

LDAPCONFIG=' 
  "binddn": "cn=vaultuser,ou=users,dc=allthingscloud,dc=eu",
  "bindpass": "vaultuser",
  "deny_null_bind": "true",
  "discoverdn": "false",
  "groupattr": "cn",
  "groupdn": "ou=groups,dc=allthingscloud,dc=eu",
  "groupfilter": "(memberOf=cn=vault,ou=groups,dc=allthingscloud,dc=eu)",
  "insecure_tls": "true",
  "starttls": "false",
  "tls_max_version": "tls12",
  "tls_min_version": "tls12",
  "url": "ldap://192.168.2.11",
  "userattr": "uid",
  "userdn": "ou=users,dc=allthingscloud,dc=eu"
'
curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request POST \
    --data "'${LDAPCONFIG}'" \
    ${VAULT_ADDR}/v1/sys/auth/mydemoldapserver/config

curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    ${VAULT_ADDR}/v1/sys/auth/mydemoldapserver/config


LDAPCONFIG="{\
\"url\": \"ldap://192.168.2.11\",\
\"userdn\": \"ou=users,dc=allthingscloud,dc=eu\",\
\"groupdn\": \"ou=groups,dc=allthingscloud,dc=eu\",\
\"groupfilter\": \"(memberOf=cn=vault,ou=groups,dc=allthingscloud,dc=eu)\",\
\"groupattr\": \"cn\",\
\"upndomain\": \"allthingscloud.eu\",\
\"insecure_tls\": true,\
\"starttls\": false,\
\"userattr\": \"uid\",\
\"binddn\": \"cn=vaultuser,ou=users,dc=allthingscloud,dc=eu\",\
\"bindpass\": \"vaultuser\"\
}"

curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request PUT \
    -d "${LDAPCONFIG}" \
    --trace-ascii /dev/stdout \
    ${VAULT_ADDR}/v1/sys/auth/mydemoldapserver/config


curl \
    -X PUT\
    --trace-ascii /dev/stdout \
    -H "X-Vault-Token: ${VAULT_TOKEN}" \
    -d '{"binddn":"cn=vaultuser,ou=people,dc=allthingscloud,dc=eu","bindpass":"vaultuser","groupattr":"cn","groupdn":"ou=groups,dc=allthingscloud,dc=eu","groupfilter":"(memberOf=cn=vault,ou=groups,dc=allthingscloud,dc=eu)","insecure_tls":"true","starttls":"false","upndomain":"allthingscloud.eu","url":"ldap://192.168.2.11:389","userattr":"uid","userdn":"ou=people,dc=allthingscloud,dc=eu"}'\
     http://192.168.2.11:8200/v1/auth/mydemoldapserver/config


curl \
    -X PUT\
    --trace-ascii /dev/stdout \
    -H "X-Vault-Token: ${VAULT_TOKEN}" \
    -d ${myvar} \
     http://192.168.2.11:8200/v1/auth/mydemoldapserver/config