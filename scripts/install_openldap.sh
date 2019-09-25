#!/bin/bash

installnoninteractive(){
  sudo bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -q -y $*"
}

addhost() {
    HOSTNAME=$1
    HOSTS_LINE="$IP\t$HOSTNAME"
    if [ -n "$(grep $HOSTNAME /etc/hosts)" ]
        then
            echo "$HOSTNAME already exists : $(grep $HOSTNAME $ETC_HOSTS)"
        else
            echo "Adding $HOSTNAME to your $ETC_HOSTS";
            sudo -- sh -c -e "echo '$HOSTS_LINE' >> /etc/hosts";

            if [ -n "$(grep $HOSTNAME /etc/hosts)" ]
                then
                    echo "$HOSTNAME was added succesfully \n $(grep $HOSTNAME /etc/hosts)";
                else
                    echo "Failed to Add $HOSTNAME, Try again!";
            fi
    fi
}

reset_crc_file_stamp() {
    # Tidy CRCs after manual editing
    sudo grep -v '^#' $1 > /tmp/cleaned.ldif
    NEWCRC=`sudo crc32 /tmp/cleaned.ldif`
    sudo sed -i '/# CRC32/c\# CRC32 '${NEWCRC} $1

}

install_and_configure_openldap () {

    echo "Starting OpenLDAP installation"
    sudo apt-get update
    # Idempotent hack
    ldapsearch -x -LLL -h localhost -D cn=admin,dc=eu -w ${LDAPPASSWORD} -b "ou=groups,dc=allthingscloud,dc=eu"
    LDAP_CONFIGURED=$?
    if [[ ${LDAP_CONFIGURED} -ne 0 ]]; then
        echo "Installing base packages"
        installnoninteractive slapd ldap-utils libarchive-zip-perl

        # Reset passwords to enable DIT configuration following silent installation
        echo "Setting up default passwords"
        HASHEDPASSWORD=`sudo slappasswd -s ${LDAPPASSWORD}`
        sudo sed -i '/olcRootPW/c\olcRootPW: '${HASHEDPASSWORD}  /etc/ldap/slapd.d/cn\=config/olcDatabase={1}mdb.ldif
        sudo echo 'olcRootDN: cn=admin,cn=config' >> /etc/ldap/slapd.d/cn\=config/olcDatabase={0}config.ldif
        sudo echo 'olcRootPW: '${HASHEDPASSWORD} >> /etc/ldap/slapd.d/cn\=config/olcDatabase={0}config.ldif

        # Reset CRC Timestamp
        reset_crc_file_stamp /etc/ldap/slapd.d/cn\=config/olcDatabase={1}mdb.ldif
        reset_crc_file_stamp /etc/ldap/slapd.d/cn\=config/olcDatabase={0}config.ldif

        # Restart LDAP Server Service
        sudo systemctl restart slapd.service

        # Enbale LDAP logging
        sudo ldapmodify -w ${LDAPPASSWORD} -D cn=admin,cn=config -f /usr/local/bootstrap/conf/ldap/enableLDAPlogs.ldif

        # Enable memberOf overlay - easily and efficiently do queries that enables you to see which users are part of which groups 
        echo "Enabling LDAP memberOf Overlay"
        sudo ldapadd -w ${LDAPPASSWORD} -D cn=admin,cn=config -f /usr/local/bootstrap/conf/ldap/memberOfmodule.ldif
        sudo ldapadd -w ${LDAPPASSWORD} -D cn=admin,cn=config -f /usr/local/bootstrap/conf/ldap/memberOfconfig.ldif
        sudo ldapmodify -w ${LDAPPASSWORD} -D cn=admin,cn=config -f /usr/local/bootstrap/conf/ldap/refintmodule.ldif
        sudo ldapadd -w ${LDAPPASSWORD} -D cn=admin,cn=config -f /usr/local/bootstrap/conf/ldap/refintconfig.ldif

        # Configure LDAP users and groups
        echo "Loading new details into LDAP server - users & groups"
        sudo ldapadd -x -D cn=admin,dc=eu -w ${LDAPPASSWORD} -f /usr/local/bootstrap/conf/ldap/slapd.ldif

        # Review the LDIF
        echo "Dumping the DIT to screen"
        sudo slapcat

        # Verify Access
        echo "Sample Queries"
        ldapsearch -x -LLL -h localhost -D "cn=Dawn French,ou=people,dc=allthingscloud,dc=eu" -w passwordd -b "cn=Ronan Keating,ou=people,dc=allthingscloud,dc=eu" -s sub "(objectClass=inetOrgPerson)" carlicense
        ldapsearch -x -LLL -h localhost -D "cn=Dawn French,ou=people,dc=allthingscloud,dc=eu" -w passwordd -b "cn=vault,ou=groups,dc=allthingscloud,dc=eu"
        ldapsearch -x -LLL -h localhost -D "cn=Dawn French,ou=people,dc=allthingscloud,dc=eu" -w passwordd -b "ou=people,dc=allthingscloud,dc=eu" memberOf
        ldapsearch -x -LLL -h localhost -D "cn=vaultuser,ou=people,dc=allthingscloud,dc=eu" -w vaultuser -b "dc=allthingscloud,dc=eu" memberOf

    else

        echo "Nothing to do OpenLDAP already installed and configured!"

    fi

    # Check LDAP server is listening on port 389
    nc localhost 389 -v -z

}

setup_environment() {
    
    set -x
    ETC_HOSTS=/etc/hosts

    # Default IP for hostname
    IP="192.168.15.11"

    # Hostname to add/remove.
    HOSTNAME="allthingscloud.eu"

    addhost $HOSTNAME

    export LDAPPASSWORD=bananas

}

setup_environment
install_and_configure_openldap

