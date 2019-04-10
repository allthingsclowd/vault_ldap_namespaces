

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

export LDAPCONFIG='{"binddn":"cn=vaultuser,ou=people,dc=allthingscloud,dc=eu","bindpass":"vaultuser","groupattr":"cn","groupdn":"ou=groups,dc=allthingscloud,dc=eu","groupfilter":"(memberOf=cn=vault,ou=groups,dc=allthingscloud,dc=eu)","insecure_tls":"true","starttls":"false","upndomain":"allthingscloud.eu","url":"ldap://192.168.2.11:389","userattr":"uid","userdn":"ou=people,dc=allthingscloud,dc=eu"}'


curl \
    -X PUT\
    --trace-ascii /dev/stdout \
    -H "X-Vault-Token: ${VAULT_TOKEN}" \
    -d ${myvar} \
     http://192.168.2.11:8200/v1/auth/mydemoldapserver/config

# Or via the CLI

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

