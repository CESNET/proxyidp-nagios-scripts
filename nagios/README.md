# ProxyIdP Nagios scripts

## List of Local scripts
Local scripts are located in /usr/lib/check_mk/local/

###  php_syntax_check.sh
* Attributes to be filled:
<pre>
# List of paths to check separated by space
paths=""
</pre>

###  git_pull_check.sh
* Attributes to be filled:
<pre>
# The root directory to check
dir=""
</pre>

### services_running_check.sh
* Attributes to be filled:
<pre>
# List of service names separated by space
services=""
</pre>

### Proxy idp authentication test - local
There are two main scripts (one of them uses SAML, the other uses OIDC) checking the login to SP via the host from which the scripts run and some helper scripts located in folder `proxy_idp_auth_test_script/`
The main script gradually try to sign in via AAI Playground IdP, MUNI IdP and CESNET IdP.

These scripts are able to cache their last result.

* Params:
    * 1 - if this param contains '-f', script does not use its cache and is forced to do whole login process

* Main scripts:
    * proxy_idp_auth_test_saml.sh
    * proxy_idp_auth_test_oidc.sh
* Helper scripts:
    * proxy_idp_auth_test_script/saml_auth_test_aai.sh
    * proxy_idp_auth_test_script/saml_auth_test_cesnet.sh
    * proxy_idp_auth_test_script/saml_auth_test_muni.sh
    * proxy_idp_auth_test_script/oidc_auth_test_aai.sh
    * proxy_idp_auth_test_script/oidc_auth_test_cesnet.sh
    * proxy_idp_auth_test_script/oidc_auth_test_muni.sh
* Requirements:
    * library *bc*
        <pre>
        apt-get install bc
        </pre>
    * Configuration file proxy_idp_auth_test_config.sh in the same folder as script
        * Attributes to be filled:
            <pre>
            # The urls of tested SP
            # For example: https://aai-playground.ics.muni.cz/simplesaml/nagios_check.php?proxy_idp=cesnet&authentication=muni
            AAI_SAML_TEST_SITE=""          # Needed only for SAML
            MUNI_SAML_TEST_SITE=""          # Needed only for SAML
            CESNET_SAML_TEST_SITE=""        # Needed only for SAML
            AAI_OIDC_TEST_SITE=""          # Needed only for OIDC
            MUNI_OIDC_TEST_SITE=""          # Needed only for OIDC
            CESNET_OIDC_TEST_SITE=""        # Needed only for OIDC

            # The url of logins form of used IdP
            # For example: https://idp2.ics.muni.cz/idp/Authn/UserPassword
            AAI_LOGIN_SITE=""
            MUNI_LOGIN_SITE=""
            CESNET_LOGIN_SITE=""

            # Fill in logins
            AAI_LOGIN=""
            MUNI_LOGIN=""
            CESNET_LOGIN=""

            # Fill in passwords as string
            MUNI_PASSWORD=""
            CESNET_PASSWORD=""

            # Fill in the instance name
            # Instance name must not contain a space
            INSTANCE_NAME=""

            # Fill in the global domain name of ProxyIdP
            # For example: login.cesnet.cz
            PROXY_DOMAIN_NAME=""

            # How long is normal for total roundtrip (seconds)
            SAML_WARNING_TIME=10        # Needed only for SAML
            OIDC_WARNING_TIME=15        # Needed only for OIDC

            # Timeout time
            TIMEOUT_TIME=40
            
            # Cache time
            CACHE_TIME=60
            </pre>

### ldap_status.sh
This script checks if the LDAP servers are accessible

* Requirements:
    * library *ldap-utils*
        <pre>
        apt-get install ldap-utils
        </pre>
* Attributes to be filled:
    <pre>
    # LDAP username
    user=""

    # LDAP password
    password=""

    # Base dn of LDAP tree
    basedn=""

    # eduPersonPrincipalName which will be searched
    searchedIdentity=""

    # List of LDPA hostnames separated by space
    # Included ldap:// or ldaps://
    hostnames=""
    </pre>

## List of plugins
Plugins are located in /usr/lib/check_mk/plugins/

## Nagios active scripts
Active scripts are located in Nagios machine

### Proxy idp authentication test - active
There are two main scripts (one uses SAML, the other uses OIDC) checking the login via active ProxyIdP machine and some helper scripts located in folder `proxy_idp_auth_test_script/`
The main script gradually try to sign in via AAI Playground IdP, MUNI IdP and CESNET IdP.

* Main scripts:
    * proxy_idp_auth_test_active_saml.sh
    * proxy_idp_auth_test_active_oidc.sh
* Helper scripts:
    * proxy_idp_auth_test_script/saml_auth_test_cesnet_active.sh
    * proxy_idp_auth_test_script/saml_auth_test_muni_active.sh
    * proxy_idp_auth_test_script/oidc_auth_test_cesnet_active.sh
    * proxy_idp_auth_test_script/oidc_auth_test_muni_active.sh
* How to run these scripts:
    * Params:
        * 1 - The url of tested SP via MU account
        * 2 - The url of login form of MU IdP
        * 3 - MU Login
        * 4 - MU Password
        * 5 - The url of tested SP via CESNET account
        * 6 - The url of login form of CESNET IdP
        * 7 - CESNET Login
        * 8 - CESNET Password
        * 9 - Roundtrip time (in seconds) - The standard login time. After this time the return value can be changed to WARNING state
        * 10 - Timeout time (in seconds) - After this time the helper script timeouts
    * Examples:
        <pre>
        ./proxy_idp_auth_test_active_saml.sh "https://aai-playground.ics.muni.cz/simplesaml/nagios_check.php?proxy_idp=cesnet&authenticate=muni" "https://idp2.ics.muni.cz/idp/Authn/UserPassword" "login" "passwd" "https://aai-playground.ics.muni.cz/simplesaml/nagios_check.php?proxy_idp=cesnet&authenticate=cesnet" "https://idp2.ics.muni.cz/idp/Authn/UserPassword" "login" "passwd" 10 40
        ./proxy_idp_auth_test_active_oidc.sh "https://aai-playground.ics.muni.cz/simplesaml/nagios_check.php?proxy_idp=cesnet&authenticate=muni" "https://idp2.ics.muni.cz/idp/Authn/UserPassword" "login" "passwd" "https://aai-playground.ics.muni.cz/simplesaml/nagios_check.php?proxy_idp=cesnet&authenticate=cesnet" "https://idp2.ics.muni.cz/idp/Authn/UserPassword" "login" "passwd" 15 40
        </pre>

### mariadb_replication_check.sh
This script checks the database replication

* How to run this script:
    * Params:
        * 1 - Path to the configuration
    * Requirements:
        * Configuration file - Example configuration file: `mariadb_replication_check_config.sh`
    * Example:
        <pre>
        ./mariadb_replication_check.sh "mariadb_check_config.sh"
        </pre>
