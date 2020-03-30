#!/usr/bin/env bash


create_vault_policy () {
    
    if [[ "${5}" != "" ]]; then
        POLICY_EXISTS=`curl -s -X GET -I -H "X-Vault-Token: reallystrongpassword" -H "X-Vault-Namespace: ${5}" -w "%{http_code}\n" -o /dev/null http://192.168.15.11:8200/v1/sys/policies/acl/${3}`
    else
        POLICY_EXISTS=`curl -s -X GET -I -H "X-Vault-Token: reallystrongpassword" -w "%{http_code}\n" -o /dev/null http://192.168.15.11:8200/v1/sys/policies/acl/${3}`
    fi
    
    
    if [[ ${POLICY_EXISTS} != "200" ]]; then
        # Create new vault policy
        echo "Vault policy ${3} is being created"
            # if the policy for the namespace is to live in the root namespace then we us ${5} as the namespace to be inserted into the policy
            if [[ "${6}" == *"LOCAL"* ]] && [[ "${5}" != "" ]]; then
                sed 's/path \\"/path \\"'${5}'\//g' ${4}  > /tmp/temppolicy.json
                             
                curl \
                    -H "X-Vault-Token: reallystrongpassword" \
                    -X PUT \
                    -d @/tmp/temppolicy.json \
                    ${2}/v1/sys/policies/acl/${3}
            else
                cp ${4} /tmp/temppolicy.json

                curl \
                    -H "X-Vault-Token: reallystrongpassword" \
                    -H "X-Vault-Namespace: ${5}" \
                    -X PUT \
                    -d @/tmp/temppolicy.json \
                    ${2}/v1/sys/policies/acl/${3}
            fi
            
            echo "Created ${3} vault policy from the following file - "
            cat /tmp/temppolicy.json
            rm /tmp/temppolicy.json

    else
        echo "Vault policy ${3} already exists - no new policy created"
    fi
    

    echo 'Vault Policy Creation Complete'

}

create_vault_policies_for_namespace () {
    create_vault_policy ${VAULT_TOKEN} ${VAULT_ADDR} vaultAdmin /usr/local/bootstrap/conf/vault_root_admin_policy.json "" "LOCAL"
    create_vault_policy ${VAULT_TOKEN} ${VAULT_ADDR} ${APP_TEAMA_NAMESPACE}_admin /usr/local/bootstrap/conf/vault_namespace_admin_policy.json ${APP_TEAMA_NAMESPACE} "REMOTE"
    create_vault_policy ${VAULT_TOKEN} ${VAULT_ADDR} ${APP_TEAMB_NAMESPACE}_admin /usr/local/bootstrap/conf/vault_namespace_admin_policy.json ${APP_TEAMB_NAMESPACE} "REMOTE"
    create_vault_policy ${VAULT_TOKEN} ${VAULT_ADDR} ${SHARED_NAMESPACE}_admin /usr/local/bootstrap/conf/vault_namespace_admin_policy.json ${SHARED_NAMESPACE} "LOCAL"
    create_vault_policy ${VAULT_TOKEN} ${VAULT_ADDR} ${SHARED_NAMESPACE}_operator /usr/local/bootstrap/conf/vault_namespace_operator_policy.json ${SHARED_NAMESPACE} "LOCAL"

}

assign_vault_ldap_group_to_policy () {
    curl \
        -X PUT \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -d '{"policies":"'${2}'"}' \
        ${VAULT_ADDR}/v1/auth/${LDAP_ENDPOINT}/groups/${1}
}


assign_vault_policies() {
    
    # Link policies directly to the external Groups that match the LDAP groups - these policies all live in the root namespace
    assign_policy_in_root_namespace_to_external_group External_LDAP_Group_TeamA "\"${SHARED_NAMESPACE}_operator\""
    assign_policy_in_root_namespace_to_external_group External_LDAP_Group_TeamB "\"${SHARED_NAMESPACE}_operator\""
    assign_policy_in_root_namespace_to_external_group External_LDAP_Group_TeamC "\"${SHARED_NAMESPACE}_admin\""
    assign_policy_in_root_namespace_to_external_group External_LDAP_Group_TeamD "\"${SHARED_NAMESPACE}_admin\",\"vaultAdmin\",\"${APP_TEAMA_NAMESPACE}_admin\",\"${APP_TEAMB_NAMESPACE}_admin\""
    
    # Link policies to an internal group in their respective namespaces - these policies will live in the particular namespace
    assign_policy_to_namespace_to_internal_group TeamA ${APP_TEAMA_NAMESPACE} ${APP_TEAMA_NAMESPACE}_admin
    
    # Rinse & Repeat for the second namespace with local policies
    assign_policy_to_namespace_to_internal_group TeamB ${APP_TEAMB_NAMESPACE} ${APP_TEAMB_NAMESPACE}_admin
    
}

assign_policy_to_namespace_to_internal_group () {
    # Read the external groupID to map as a member to the newly created internal group
    EXTERNAL_GROUP_ID=`curl \
                -X GET \
                -s \
                -H "X-Vault-Token: ${VAULT_TOKEN}" \
                ${VAULT_ADDR}/v1/identity/group/name/External_LDAP_Group_${1} | jq -r ".data.id"`

    curl \
        -X PUT \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "X-Vault-Namespace: ${2}/" \
        -d "{\"member_group_ids\":\"${EXTERNAL_GROUP_ID}\",\"name\":\"${1}\",\"policies\":\"${3}\"}" \
        ${VAULT_ADDR}/v1/identity/group    
}

create_external_ldap_group_identities() {
   LDAP_ACCESSOR=`curl \
        -s \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        ${VAULT_ADDR}/v1/sys/auth | jq -r ".[\"${LDAP_ENDPOINT}/\"].accessor"`

    for GROUP in $LDAP_GROUPS ;
        do
            NEW_GROUP_ID=`curl \
                -X PUT \
                -s \
                -H "X-Vault-Token: ${VAULT_TOKEN}" \
                -d "{\"name\":\"External_LDAP_Group_${GROUP}\",\"type\":\"external\"}" \
                ${VAULT_ADDR}/v1/identity/group | jq -r ".data.id"`

            curl -X PUT \
                -s \
                -H "X-Vault-Token: ${VAULT_TOKEN}" \
                -d "{\"canonical_id\":\"${NEW_GROUP_ID}\",\"mount_accessor\":\"${LDAP_ACCESSOR}\",\"name\":\"${GROUP}\"}" \
                ${VAULT_ADDR}/v1/identity/group-alias         
        
        done    
        

}

assign_policy_in_root_namespace_to_external_group () {

    GROUP_ID=`curl \
                -X GET \
                -s \
                -H "X-Vault-Token: ${VAULT_TOKEN}" \
                ${VAULT_ADDR}/v1/identity/group/name/${1} | jq -r ".data.id"`

    curl \
        -X PUT \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -d "{\"policies\":[${2}]}" \
        ${VAULT_ADDR}/v1/identity/group/id/${GROUP_ID}   
}

configure_vault_ldap () {

    # Check existing ldap configuration

    ENDPOINT_ENABLED=`curl \
        -I \
        -o /dev/null \
        -s \
        -w "%{http_code}\n" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        ${VAULT_ADDR}/v1/auth/${LDAP_ENDPOINT}/config`

    if [[ ${ENDPOINT_ENABLED} != "200" ]]; then
        echo "Enabling LDAP Authentication Backend /v1/auth/${LDAP_ENDPOINT}"
        
        # Enable new Vault LDAP Backend
        LDAPBACKENDCONFIG='{
        "type": "ldap",
        "description": "Login with OpenLDAP Server"
        }'

        curl \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -X POST \
            -d "${LDAPBACKENDCONFIG}" \
            ${VAULT_ADDR}/v1/sys/auth/${LDAP_ENDPOINT}

        # To test you LDAP config outside of Vault => ldapsearch -x -LLL -h localhost -D "cn=vaultuser,ou=people,dc=allthingscloud,dc=eu" -w vaultuser -b "ou=people,dc=allthingscloud,dc=eu" -s sub "(&(objectClass=inetOrgPerson)(uid=mpoppins))" memberOf
        
        export LDAPCONFIG='{"binddn":"cn=vaultuser,ou=people,dc=allthingscloud,dc=eu","bindpass":"vaultuser","groupattr":"memberOf","groupdn":"ou=people,dc=allthingscloud,dc=eu","groupfilter":"(&(objectClass=inetOrgPerson)(uid={{.Username}}))","insecure_tls":"true","starttls":"false","url":"ldap://192.168.15.11:389","userattr":"uid","userdn":"ou=people,dc=allthingscloud,dc=eu"}'

        curl \
            -X PUT \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -d ${LDAPCONFIG} \
            ${VAULT_ADDR}/v1/auth/${LDAP_ENDPOINT}/config


    else
        echo "LDAP Authentication Backend /v1/auth/${LDAP_ENDPOINT} is already enabled with the following configuration"

        # Check for config associated with new demo path
        curl \
            -X GET \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            ${VAULT_ADDR}/v1/auth/${LDAP_ENDPOINT}/config


    fi


    LDAP_VERIFICATION=`curl \
        -o /dev/null \
        -s \
        -w "%{http_code}\n" \
        -X PUT \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -d "{\"password\":\"${LDAP_TESTPASSWORD}\"}" \
        ${VAULT_ADDR}/v1/auth/${LDAP_ENDPOINT}/login/${LDAP_TESTUSER}`

    if [[ ${LDAP_VERIFICATION} != "200" ]]; then
        echo "LDAP User Vault Authentication Verification Failed"
    else
        echo "LDAP User Vault Authentication Verification Successful"
    fi

}

create_namespaces () {

    for NAMESPACE in $VAULT_NAMESPACES ;
        do
            NAMESPACE_EXISTS=`curl \
                -o /dev/null \
                -s \
                -w "%{http_code}\n" \
                -H "X-Vault-Token: ${VAULT_TOKEN}" \
                ${VAULT_ADDR}/v1/sys/namespaces/${NAMESPACE}`
            
            if [[ ${NAMESPACE_EXISTS} != "200" ]]; then
                echo "Creating new namespace ${NAMESPACE}"
                curl \
                    -H "X-Vault-Token: ${VAULT_TOKEN}" \
                    -X POST \
                    -s \
                    ${VAULT_ADDR}/v1/sys/namespaces/${NAMESPACE}

            else
                echo "Namespace ${NAMESPACE} already exists"
            fi

        done

}

create_service () {

  if [ ! -f /etc/systemd/system/${1}.service ]; then

    echo "Creating service definition /etc/systemd/system/${1}.service"
    
    create_service_user ${1}
    
    sudo tee /etc/systemd/system/${1}.service <<EOF
### BEGIN INIT INFO
# Provides:          ${1}
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: ${1} agent
# Description:       ${2}
### END INIT INFO

[Unit]
Description=${2}
Requires=network-online.target
After=network-online.target

[Service]
User=${1}
Group=${1}
PIDFile=/var/run/${1}/${1}.pid
PermissionsStartOnly=true
ExecStartPre=-/bin/mkdir -p /var/run/${1}
ExecStartPre=/bin/chown -R ${1}:${1} /var/run/${1}
ExecStart=${3}
ExecReload=/bin/kill -HUP ${MAINPID}
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
RestartSec=2s

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload

  else

    echo "Service definition /etc/systemd/system/${1}.service already exists!"
  
  fi

}

create_service_user () {
  
  if ! grep ${1} /etc/passwd >/dev/null 2>&1; then
    echo "Creating ${1} user to run the ${1} service"
    sudo useradd --system --home /etc/${1}.d --shell /bin/false ${1}
    sudo mkdir --parents /opt/${1} /usr/local/${1} /etc/${1}.d
    sudo chown --recursive ${1}:${1} /opt/${1} /etc/${1}.d /usr/local/${1}
    else
        echo "Service account ${1} already exists!"
  fi

}

setup_environment () {
    
    set -x
    echo 'Start Setup of Vault Environment'
    source /usr/local/bootstrap/var.env
    

    IFACE=`route -n | awk '$1 == "192.168.15.0" {print $8}'`
    CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.15" {print $2}'`
    IP=${CIDR%%/24}

    if [ -d /vagrant ]; then
        LOG="/vagrant/logs/vault_${HOSTNAME}.log"
    else
        LOG="vault.log"
    fi

    # setup vault directory for database filestore - don't do this in production
    sudo mkdir -p /mnt/vault/data
    sudo chmod 777 /mnt/vault/data
    
    # Install Enterprise Binary
    pushd /usr/local/bin
    sudo unzip -o /usr/local/bootstrap/.hsm/${VAULT_BINARY}
    sudo chmod +x vault
    popd
    
    # # Install OSS Binary
    # pushd /usr/local/bin
    # [ -f vault_1.1.1_linux_amd64.zip ] || {
    #     sudo wget -q https://releases.hashicorp.com/vault/1.1.1/vault_1.1.1_linux_amd64.zip
    # }
    # sudo unzip -o vault_1.1.1_linux_amd64.zip
    # sudo chmod +x vault
    # sudo rm vault_1.1.1_linux_amd64.zip
    # popd


    echo 'End Setup of Vault Environment Prerequisites'
}

revoke_root_token () {
    
    echo 'Start Vault Root Token Revocation'
    # revoke ROOT token now that admin token has been created
    sudo VAULT_TOKEN=${VAULT_TOKEN} VAULT_ADDR="http://${IP}:8200" vault token revoke ${VAULT_TOKEN}

    # Verify root token revoked
    sudo VAULT_TOKEN=${VAULT_TOKEN} VAULT_ADDR="http://${IP}:8200" vault status

    # Set new admin vault token & verify
    export VAULT_TOKEN=${ADMIN_TOKEN}
    sudo VAULT_TOKEN=${ADMIN_TOKEN} VAULT_ADDR="http://${IP}:8200" vault login ${ADMIN_TOKEN}
    sudo VAULT_TOKEN=${ADMIN_TOKEN} VAULT_ADDR="http://${IP}:8200" vault status
    echo 'Vault Root Token Revocation Complete'    
}

install_vault () {
    
    
    # verify it's either the TRAVIS server or the Vault server
    if [[ "${HOSTNAME}" =~ "allthingscloud" ]]; then
        echo 'Start Installation of Vault on Server'
        setup_environment
        
        # if service exists send controlled stop
        [ -f /etc/systemd/system/vault.service ] && sudo systemctl stop vault && sleep 5

        # let's kill past instance
        sudo killall vault &>/dev/null

        # delete old token if present
        [ -f /usr/local/bootstrap/.vault-token ] && sudo rm /usr/local/bootstrap/.vault-token

        # remove the old database
        [ -d /mnt/vault/data ] && sudo rm -rf /mnt/vault/data/*

        #start vault

        create_service vault "HashiCorp's Sercret Management Service" "/usr/local/bin/vault server -log-level=debug -dev -dev-root-token-id=reallystrongpassword -dev-listen-address=${IP}:8200 -config=/usr/local/bootstrap/conf/vault.d/vault.hcl"
        sudo systemctl start vault
        sudo systemctl status vault

        echo vault started
        sleep 15
        sudo systemctl status vault
        export VAULT_TOKEN=reallystrongpassword
        export VAULT_ADDR="http://${IP}:8200"
        vault status

        #copy token to known location
        echo "reallystrongpassword" > /usr/local/bootstrap/.vault-token
        sudo chmod ugo+r /usr/local/bootstrap/.vault-token
        echo 'Installation of Vault Finished'

    fi

    
}

install_vault
create_namespaces
configure_vault_ldap
create_vault_policies_for_namespace
create_external_ldap_group_identities
assign_vault_policies

exit 0
    



