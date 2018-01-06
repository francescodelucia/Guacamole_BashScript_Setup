#!/bin/bash

################################
## Guacamole Installer Script ##
################################

# Variabili

guac_version=0.9.8
mysql_version=5.1.35
 
mysql_username=root
mysql_password=toor
 
ssl_country=EU
ssl_state=IT
ssl_city=Rome
ssl_org=IT
ssl_certname=myGuacamole.it

hostname = 192.168.10.85
 
# Aggiornamento Sistema
sudo apt-get update -y
 
# Upgrade Sistema
sudo apt-get upgrade -y
 
# Installazione Tomcat 7
sudo apt-get install -y tomcat7
 
# Installazione Pacchetti e dipendenze
sudo apt-get install -y make libcairo2-dev libjpeg62-turbo-dev libpng12-dev libossp-uuid-dev libpango-1.0-0 libpango1.0-dev libssh2-1-dev libpng12-dev freerdp-x11 libssh2-1 libvncserver-dev libfreerdp-dev libvorbis-dev libssl1.0.0 gcc libssh-dev libpulse-dev tomcat7-admin tomcat7-docs libtelnet-dev libossp-uuid-dev
 
# Download Guacamole Client
sudo wget http://sourceforge.net/projects/guacamole/files/current/binary/guacamole-$guac_version.war
 
# Download Guacamole Server
sudo wget http://sourceforge.net/projects/guacamole/files/current/source/guacamole-server-$guac_version.tar.gz
 
# Scompatta i files sorgenti di Guacamole Server
sudo tar -xzf guacamole-server-$guac_version.tar.gz
 
cd guacamole-server-$guac_version/
 
# Configurazione sorgenti Guacamole Server
sudo ./configure --with-init-dir=/etc/init.d
 
# Make
sudo make
 
# Make Install
sudo make install
 
# 
sudo update-rc.d guacd defaults
 
#
sudo ldconfig
 
# Create guacamole configuration directory
sudo mkdir /etc/guacamole
 
# Create guacamole.properties configuration file
sudo cat <<EOF1 > /etc/guacamole/guacamole.properties
# Hostname and port of guacamole proxy
guacd-hostname: localhost
guacd-port:     4822
 
 
# Auth provider class (authenticates user/pass combination, needed if using the provided login screen)
#auth-provider: net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider
#basic-user-mapping: /etc/guacamole/user-mapping.xml
 
# Auth provider class
auth-provider: net.sourceforge.guacamole.net.auth.mysql.MySQLAuthenticationProvider
 
# MySQL properties
mysql-hostname: localhost
mysql-port: 3306
mysql-database: guacamole
mysql-username: guacamole
mysql-password: $mysql_password
 
lib-directory: /var/lib/guacamole/classpath
EOF1
 
# Creazione cartella per ospitare il link alle propriet͊
sudo mkdir /usr/share/tomcat7/.guacamole
 
# Creazione di un symbolic link al file delle propriet࠰er Tomcat7
sudo  ln -s /etc/guacamole/guacamole.properties /usr/share/tomcat7/.guacamole

# Salgo di cartella per copiare il file guacamole.war 
cd ..
 
# Copio il file guacamole war in Tomcat 7 nella cartella webapps
sudo cp guacamole-$guac_version.war /var/lib/tomcat7/webapps/guacamole.war
 
# Avvio del servizio Guacamole (guacd)
sudo service guacd start
 
# Restart Tomcat 7
sudo service tomcat7 restart

########################################
# MySQL Installazione e Configurazione #
########################################
 
# Download Guacamole MySQL Authentication Module
sudo wget http://sourceforge.net/projects/guacamole/files/current/extensions/guacamole-auth-jdbc-$guac_version.tar.gz
 
# Untar di Guacamole MySQL Authentication Module
sudo tar -xzf guacamole-auth-jdbc-$guac_version.tar.gz
 
# Creazione della cartella per i files d'autenticazione mysql Guacamole
sudo mkdir -p /var/lib/guacamole/classpath
 
# Copio i files del modulo di autenticazione Guacamole MySQL Authentication nella cartella creata
sudo cp guacamole-auth-jdbc-$guac_version/mysql/guacamole-auth-jdbc-mysql-$guac_version.jar /var/lib/guacamole/classpath/
 
# Download di MySQL Connector-J
sudo wget http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-$mysql_version.tar.gz
 
# Untar di MySQL Connector-J
sudo tar -xzf mysql-connector-java-$mysql_version.tar.gz
 
# Copia del file MySQL Connector-J jar in guacamole classpath diretory
sudo cp mysql-connector-java-$mysql_version/mysql-connector-java-$mysql_version-bin.jar /var/lib/guacamole/classpath/
 
# Imposto mysql root password per automatizzare l'installazione
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $mysql_password"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $mysql_password"
 
# Installazione MySQL
sudo apt-get install -y mysql-server
 
# Imposto lo script di configurazione di MYSQL
sudo cat <<EOF2 > guacamolemysql.sql

# MySQL Guacamole Script
CREATE DATABASE guacamole;
CREATE USER 'guacamole'@'localhost' IDENTIFIED BY '$mysql_password';
GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole.* TO 'guacamole'@'localhost';
FLUSH PRIVILEGES;
quit
EOF2
 
# Creazione Guacamole database ed utente
sudo mysql -u root --password=$mysql_password < guacamolemysql.sql
 
# Cambio cartella a mysql-auth 
cd guacamole-auth-jdbc-$guac_version/mysql
 
# Avvio script database per creare schema ed utenti
sudo cat schema/*.sql | mysql -u root --password=$mysql_password guacamole

##########################################
# NGINX Installation and configuration #
##########################################
 
# Installazione Nginx
sudo apt-get install -y nginx
 
# Creo una cartella per salvare chiave e certificato
sudo mkdir /etc/nginx/ssl
 
# Creazione del certificato SSL self-signed
sudo openssl req -x509 -subj '/C=EU/ST=IT/L=Rome/O=IT/CN=$hostname' -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt -extensions v3_ca
 
# Aggiungo i settaggi del proxy al file di configurazione di nginx (/etc/nginx/sites-enabled/default)
# Riferimento: Borrowed configuration di Eric Oud Ammerveled http://sourceforge.net/p/guacamole/discussion/1110834/thread/6961d682/#aca9
 
sudo cat << EOF3 > /etc/nginx/sites-enabled/default
# SERVER IN ASCOLTO SULLA PORTA 443 (SSL) pre rendere sicuro il traffico Guacamole e proxare le richieste a Tomcat7 esposto solo localmente
server {
    listen 443 ssl;
    server_name  $hostname;
    
    # configurazione SSL
    ssl on;
    ssl_certificate      /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key  /etc/nginx/ssl/nginx.key;
    ssl_session_cache shared:SSL:10m;
    ssl_ciphers 'AES256+EECDH:AES256+EDH:!aNULL';
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_prefer_server_ciphers on;
#   ssl_dhparam /etc/ssl/certs/dhparam.pem;
    
    #tuning performante (testare meglio)
    tcp_nodelay    on;
    tcp_nopush     off;
    sendfile       on;
    client_body_buffer_size 10K;
    client_header_buffer_size 1k;
    client_max_body_size 8m;
    large_client_header_buffers 2 1k;
    client_body_timeout 12;
    client_header_timeout 12;
    keepalive_timeout 15;
    send_timeout 10;
    
    # ATTENZIONE: se vogliamo attiviamolo in fase di test
    access_log off;
    
    # ATTENZIONE NON ATTIVARE MAI il proxy_buffering!; impatta troppo sulla qualita  connessione
    proxy_buffering off;
    proxy_redirect  off;
   
    # Abilitazione dei websockets prime 3 linee
    # Controllare in fase di test /var/log/tomcat8/catalina.out,  guacamole mostra un messaggio di fallback se i websockets non funzionano.
    proxy_http_version 1.1;
	# ATTENZIONE !!!: Qui mi perdo $http_upgrae perche viene considerata dallo script una variabile, devo controllare come scriverla perche non sia parsata
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    
    # Reverse proxy per puntare al tomcat interno e precisamente alla guacamole app.
    proxy_cookie_path /guacamole/ /;
    location / {
            # I am running the Tomcat7 and Guacamole on the local server
            proxy_pass http://localhost:8080/guacamole/;
            break;
    }
}
EOF3
 
# Restart nginx
sudo service nginx restart
 
# Restart tomcat7
sudo service tomcat7 restart
 
# Restart guacd
sudo service guacd restart
 



################################################
#         Configurazione  Firewall             #
################################################
 
# Disabilito il Firewall 
sudo ufw disable
 
# Permetto accessi HTTPS
sudo ufw allow https

# Permetto accessi SSH
sudo ufw allow ssh

# Abilito Firewall
sudo ufw enable
 
# Disabilito IPv6
sudo cat <<EOF3 >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF3
 
# Attivazione sysctl
sudo sysctl -p
