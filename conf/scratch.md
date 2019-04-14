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



