#!/bin/bash

### apache configuration files ###

# webserver
webserver="<VirtualHost *:80>

    ServerAdmin $serverAdmin
    ServerName $serverName
    ServerAlias $serverAlias
    DocumentRoot /var/www/html

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined

</VirtualHost>"

# webserver + SSL
webserverSSL='<IfModule mod_ssl.c>
    <VirtualHost _default_:443>
        ServerAdmin $serverAdmin
        ServerName $serverName
        ServerAlias $serverAlias
        DocumentRoot /var/www/html
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
        SSLEngine on
        SSLCertificateFile /etc/apache2/ssl/apache.crt
        SSLCertificateKeyFile /etc/apache2/ssl/apache.key
        <FilesMatch "\.(cgi|shtml|phtml|php)$">
                        SSLOptions +StdEnvVars
        </FilesMatch>
        <Directory /usr/lib/cgi-bin>
                        SSLOptions +StdEnvVars
        </Directory>
        BrowserMatch "MSIE [2-6]" \
                        nokeepalive ssl-unclean-shutdown \
                        downgrade-1.0 force-response-1.0
        BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown
    </VirtualHost>
</IfModule>'

# reverse-proxy
reverseProxy="<VirtualHost *:80>
	
	ServerName $serverName
	ServerAlias $serverAlias
    ServerAdmin $serverAdmin
    DocumentRoot /var/www/html 

    ProxyPreserveHost On
    ProxyPass / http://$proxy:$proxyPort/
    ProxyPassReverse / http://$proxy:$proxyPort/

</VirtualHost>"

# reverse-proxy + SSL
reverseProxySSL="<VirtualHost *:443>

	ServerName $serverName
	ServerAlias $serverAlias
    ServerAdmin $serverAdmin
    DocumentRoot /var/www/html 

    SSLEngine On
    SSLCertificateFile /etc/apache2/ssl/apache.pem

    ProxyPreserveHost On
    ProxyPass / https://$proxy:$proxyPort/
    ProxyPassReverse / https://$proxy:$proxyPort/

</VirtualHost>"

# custom
custom="$apache_conf"

config=""
if [ -n "$custom" ]
then

	config=$custom

elif [ "$apache_role" = "webserver" ] && [ "$apache_ssl" = "false" ]
then

	config=$webserver

elif [ "$apache_role" = "webserver" ] && [ "$apache_ssl" = "true" ]
then
	
	config=$webserverSSL

elif [ "$apache_role" = "reverse-proxy" ] && [ "$apache_ssl" = "false" ]
then
	
	config=$reverseProxy

elif [ "$apache_role" = "reverse-proxy" ] && [ "$apache_ssl" = "true" ]
then

	config=$reverseProxySSL

fi

echo "$config" > /etc/apache2/sites-available/custom-config.conf

if [ "$apache_ssl" = "true" ]
then
	
	mkdir /etc/apache2/ssl

	### custom SSL certificates ###
	if [ -n "$sslKey" ] && [ -n "$sslCrt" ]
	then
		echo "$sslKey" > /etc/apache2/ssl/apache.key
		echo "$sslCrt" > /etc/apache2/ssl/apache.crt

        if [ "$apache_role" = "reverse-proxy" ]
	    then
		
		    cat /etc/apache2/ssl/apache.crt /etc/apache2/ssl/apache.key > /etc/apache2/ssl/apache.pem

	    fi

        a2enmod ssl

    fi

fi

if [ "$apache_role" = "reverse-proxy" ]
then
	
	apt-get update
    apt-get -y upgrade
    apt-get install -y build-essential
    apt-get install -y libapache2-mod-proxy-html libxml2-dev
    a2enmod proxy
    a2enmod proxy_http
    a2enmod proxy_ajp
    a2enmod rewrite
    a2enmod deflate
    a2enmod headers
    a2enmod proxy_balancer
    a2enmod proxy_connect
    a2enmod proxy_html

fi

if ["$mpm_module" = "prefork"]
then
    prefork = "<IfModule mpm_prefork_module>
	    StartServers			5
	    MinSpareServers		    5
	    MaxSpareServers		    10
	    MaxRequestWorkers	    150
	    MaxConnectionsPerChild  0
    </IfModule>"
fi

if ["$mpm_module" = "worker"]
then
    worker = "<IfModule mpm_worker_module>
        StartServers			2
        MinSpareThreads		    25
        MaxSpareThreads		    75
        ThreadLimit			    64
        ThreadsPerChild		    25
        MaxRequestWorkers	    150
        MaxConnectionsPerChild  0
    </IfModule>"

    a2dismod mpm_prefork
    a2enmod mpm_worker
fi

if ["$mpm_module" = "event"]
then
    event = "<IfModule mpm_event_module>
        StartServers			2
        MinSpareThreads		    25
        MaxSpareThreads		    75
        ThreadLimit			    64
        ThreadsPerChild		    25
        MaxRequestWorkers	    150
        MaxConnectionsPerChild  0
    </IfModule>"

    a2dismod mpm_prefork
    a2enmod mpm_event
fi

a2ensite custom-config.conf
a2dissite 000-default.conf
apache2-foreground
