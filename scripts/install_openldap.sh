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

install_openldap () {
  VAR=$(expect -c '
  spawn sudo apt-get install -y slapd ldap-utils
  expect "Administrator password:"
  send "bananas\r"
  expect "Confirm password:"
  send "bananas\r"
  expect eof
  ')

  echo "$VAR"
}

ETC_HOSTS=/etc/hosts

# DEFAULT IP FOR HOSTNAME
IP="192.168.3.10"

# Hostname to add/remove.
HOSTNAME="allthingscloud.eu"

addhost $HOSTNAME
sudo apt-get install -y expect
install_openldap
sudo slapcat
sudo ldapadd -x -D cn=admin,dc=eu -w bananas -f /usr/local/bootstrap/conf/slapd.ldif
ldapsearch -x -LLL -h localhost -D "cn=Dawn French,ou=people,dc=allthingscloud,dc=eu" -w passwordd -b "cn=Ronan Keating,ou=people,dc=allthingscloud,dc=eu" -s sub "(objectClass=inetOrgPerson)" carlicense
