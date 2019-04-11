#!/usr/bin/env bash


create_vault_policy () {
    
    POLICY_EXISTS=`curl -s -X GET -I -H "X-Vault-Token: reallystrongpassword" -w "%{http_code}\n" -o /dev/null http://192.168.2.11:8200/v1/sys/policies/acl/${3}` 
    
    if [[ ${POLICY_EXISTS} != "200" ]]; then
        # Create new vault policy
        echo "Vault policy ${3} is being created"
            
            # if the policy filename contains namespace then we us ${5} as the namespace to be inserted into the policy
            if [[ ${4} == *"namespace"* ]]; then
                sed "s/path \"/path \"${5}\//g" ${4}  > /tmp/temppolicy.json
            else
                cp ${4} /tmp/temppolicy.json
            fi

            echo "Creating ${3} vault policy from the following file - "
            cat /tmp/temppolicy.json 
            
            curl \
            --header "X-Vault-Token: ${1}" \
            --request PUT \
            --data @/tmp/temppolicy.json \
            ${2}/v1/sys/policies/acl/${3}
            
            DEMO_TOKEN=`sudo VAULT_TOKEN=$1 VAULT_ADDR=$2 vault token create -policy=$3 -field=token`
            sudo echo -n ${DEMO_TOKEN} > /usr/local/bootstrap/.${3}.token
            sudo chmod ugo+r /usr/local/bootstrap/.${3}.token

            rm /tmp/temppolicy.json

    else
        echo "Vault policy ${3} already exists - no new policy created"
    fi
    

    echo 'Vault Policy Creation Complete'

}

create_vault_policies () {
    create_vault_policy ${VAULT_TOKEN} ${VAULT_ADDR} vaultAdmin /usr/local/bootstrap/conf/vault_root_admin_policy.json ROOT
    create_vault_policy ${VAULT_TOKEN} ${VAULT_ADDR} TeamAAdmin /usr/local/bootstrap/conf/vault_namespace_admin_policy.json TeamA
    create_vault_policy ${VAULT_TOKEN} ${VAULT_ADDR} TeamBAdmin /usr/local/bootstrap/conf/vault_namespace_admin_policy.json TeamB
    create_vault_policy ${VAULT_TOKEN} ${VAULT_ADDR} TeamCAdmin /usr/local/bootstrap/conf/vault_namespace_admin_policy.json TeamC
    create_vault_policy ${VAULT_TOKEN} ${VAULT_ADDR} TeamDAdmin /usr/local/bootstrap/conf/vault_namespace_admin_policy.json TeamD
    create_vault_policy ${VAULT_TOKEN} ${VAULT_ADDR} TeamAOperator /usr/local/bootstrap/conf/vault_namespace_operator_policy.json TeamA
    create_vault_policy ${VAULT_TOKEN} ${VAULT_ADDR} TeamBOperator /usr/local/bootstrap/conf/vault_namespace_operator_policy.json TeamB
    create_vault_policy ${VAULT_TOKEN} ${VAULT_ADDR} TeamCOperator /usr/local/bootstrap/conf/vault_namespace_operator_policy.json TeamC
    create_vault_policy ${VAULT_TOKEN} ${VAULT_ADDR} TeamDOperator /usr/local/bootstrap/conf/vault_namespace_operator_policy.json TeamD
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

    IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8}'`
    CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
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
    sudo unzip -o /usr/local/bootstrap/.hsm/vault-enterprise_1.1.0+prem_linux_amd64.zip
    sudo chmod +x vault
    popd
    
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


bootstrap_secret_data () {
    
    echo 'Set environmental bootstrapping data in VAULT'
    REDIS_MASTER_PASSWORD=`openssl rand -base64 32`
    APPROLEID=`cat /usr/local/bootstrap/.appRoleID`
    DB_VAULT_TOKEN=`cat /usr/local/bootstrap/.database-token`
    AGENTTOKEN=`cat /usr/local/bootstrap/.agenttoken_acl`
    WRAPPEDPROVISIONERTOKEN=`cat /usr/local/bootstrap/.wrapped-provisioner-token`
    BOOTSTRAPACL=`cat /usr/local/bootstrap/.bootstrap_acl`
    # Put Redis Password in Vault
    sudo VAULT_ADDR="http://${IP}:8200" vault login ${ADMIN_TOKEN}
    # FAILS???? sudo VAULT_TOKEN=${ADMIN_TOKEN} VAULT_ADDR="http://${IP}:8200" vault policy list
    sudo VAULT_TOKEN=${ADMIN_TOKEN} VAULT_ADDR="http://${IP}:8200" vault kv put kv/development/redispassword value=${REDIS_MASTER_PASSWORD}
    sudo VAULT_TOKEN=${ADMIN_TOKEN} VAULT_ADDR="http://${IP}:8200" vault kv put kv/development/consulagentacl value=${AGENTTOKEN}
    sudo VAULT_TOKEN=${ADMIN_TOKEN} VAULT_ADDR="http://${IP}:8200" vault kv put kv/development/vaultdbtoken value=${DB_VAULT_TOKEN}
    sudo VAULT_TOKEN=${ADMIN_TOKEN} VAULT_ADDR="http://${IP}:8200" vault kv put kv/development/approleid value=${APPROLEID}
    sudo VAULT_TOKEN=${ADMIN_TOKEN} VAULT_ADDR="http://${IP}:8200" vault kv put kv/development/wrappedprovisionertoken value=${WRAPPEDPROVISIONERTOKEN}
    sudo VAULT_TOKEN=${ADMIN_TOKEN} VAULT_ADDR="http://${IP}:8200" vault kv put kv/development/bootstraptoken value=${BOOTSTRAPACL}

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

        create_service vault "HashiCorp's Sercret Management Service" "/usr/local/bin/vault server -dev -dev-root-token-id="reallystrongpassword" -dev-listen-address=${IP}:8200 -config=/usr/local/bootstrap/conf/vault.d/vault.hcl"
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
create_vault_policies

exit 0
    



