#!/bin/bash

#--------------------------------------------------------------------------
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corporation 2019.
#
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corporation.
#--------------------------------------------------------------------------

# version="0.1"
#
#
# ARG_OPTIONAL_SINGLE([all],[a],[Do all configurations OIDC, IM Connection and secret and navigation updates],[false])
# ARG_OPTIONAL_SINGLE([oidc-only],[o],[Only do the configuration for OIDC and SSO],[true])
# ARG_OPTIONAL_SINGLE([nav-only],[n],[Only add Infrastructure Management to navigation],[false])
# ARG_OPTIONAL_SINGLE([hostname],[s],[Add hostname for Infrastructure Management install],[inframgmtinstall])


die()
{
	local _ret=$2
	test -n "$_ret" || _ret=1
	test "$_PRINT_HELP" = yes && print_help >&2
	echo "$1" >&2
	exit ${_ret}
}


begins_with_short_option()
{
	local first_option all_short_options='aonsh'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - OPTIONALS
#_arg_all=""
#_arg_oidc_only=""
#_arg_nav_only=""
_arg_hostname="inframgmtinstall"


print_help()
{
	printf '\t%s\n' " "
  printf '%s\n' "This script configures OIDC, Operators and Navigation items for the IBM CloudPak and Infrastructure Management."
	printf '%s\n' "***** You must have the oc client and cloudctl authenticated ******"
  printf '\t%s\n' " "
  printf 'Usage: %s [-a|--all <arg>] [-o|--oidc-only <arg>] [-n|--nav-only <arg>] [-s|--hostname <arg>] [-h|--help]\n' "$0"
  printf '\t%s\n' "-a, --all: Configure OIDC, IM Connection and the Navigation menu"
	printf '\t%s\n' "-o, --oidc-only: Only configure OIDC"
	printf '\t%s\n' "-n, --nav-only: Only add Infrastructure Management to navigation menu"
	printf '\t%s\n' "-s, --hostname: Add hostname for Infrastructure Management install (default: 'inframgmtinstall')"
  printf '\t%s\n' "-e, --edit-nav: Edit Infrastructure Management navigation menu"
	printf '\t%s\n' "-h, --help: Prints help"
}


parse_commandline()
{
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			-a|--all)
				test $# -lt 2 
				_arg_all="true"
				shift
				;;
			--all=*)
				_arg_all="${_key##--all=}"
				;;
			-a*)
				_arg_all="${_key##-a}"
				;;
			-o|--oidc-only)
				test $# -lt 
				_arg_oidc_only="true"
				shift
				;;
			--oidc-only=*)
				_arg_oidc_only="${_key##--oidc-only=}"
				;;
			-o*)
				_arg_oidc_only="${_key##-o}"
				;;
			-n|--nav-only)
				test $# -lt 2 
				_arg_nav_only="nav only"
				shift
				;;
			--nav-only=*)
				_arg_nav_only="${_key##--nav-only=}"
				;;
			-n*)
				_arg_nav_only="${_key##-n}"
				;;
			-e|--edit-nav)
                                test $# -lt 2 
                                _arg_edit_nav="edit"
                                shift
                                ;;
                        --edit-nav=*)
                                _arg_edit_nav="${_key##--edit_nav=}"
                                ;;
                        -e*)
                                _arg_edit_nav="${_key##-e}"
                                ;;
                        -s|--hostname)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_hostname="$2"
				shift
				;;
			--hostname=*)
				_arg_hostname="${_key##--hostname=}"
				;;
			-s*)
				_arg_hostname="${_key##-s}"
				;;
			-h|--help)
				print_help
				exit 0
				;;
			-h*)
				print_help
				exit 0
				;;
			*)
				_PRINT_HELP=yes die "FATAL ERROR: Got an unexpected argument '$1'" 1
				;;
		esac
		shift
	done
}

parse_commandline "$@"

# Check for kubectl being installed
check_kubectl_installed() {
	echo "Checking if kubectl is installed..."
	command -v kubectl >/dev/null 2>&1 || {
		echo >&2 "kubectl is not installed... Aborting."
		exit 1
	}
	echo "kubectl is installed"
}


oidc()
{
#!/bin/sh
echo "Creating client id and client secret."
client_id_random=$((RANDOM * 100000000))
client_secret_random=$((RANDOM * 52300000000 + RANDOM))
client_id=`echo ${client_id_random} |base64`
client_secret=`echo ${client_secret_random} |base64`
echo "Created client id: $client_id and client secret: $client_secret"
echo "------------"

while true; do
    echo "Access tokens are not required for podified. By default, it will use internal service communication."
    read -p "Do you wish to enable access token support? (y/n)" yn
    case $yn in
        [Yy]* ) bypass="false"
           echo "Adding access token information"
           echo "Input your ldap user credentials. These will be deleted when a token is generated."
          read -p "Enter User Name: " myuser
          echo -n Enter User Password: 
          read -s mypassword
          echo
        break;;
        [Nn]* ) 
        bypass="true"
        break;;
        * ) echo "Please answer yes or no.";;
    esac
done
echo $myuser
pw=$mypassword
echo "Generating OIDC file: "
echo "-----------"

if [ -n "$myuser" ]; then
 tee im-oidc-secret.yaml  << EOF
kind: Secret                                                                                                     
apiVersion: v1                                                                                                   
metadata:                                                                                                        
  name: imconnectionsecret                                                                                         
stringData:
  cpconsole:  $cp_url
  clientid: $client_id
  clientsecret: $client_secret
  oauth_username: $myuser
  oauth_password: $pw
  oidc.conf: |-                                                                                                 
    LoadModule          auth_openidc_module modules/mod_auth_openidc.so
    ServerName          $im_url
    LogLevel            debug
    OIDCCLientID                   $client_id 
    OIDCClientSecret               $client_secret
    OIDCRedirectURI                $im_url/oidc_login/redirect_uri
    OIDCCryptoPassphrase           alphabeta
    OIDCOAuthRemoteUserClaim       sub
    OIDCRemoteUserClaim            name
    # OIDCProviderMetadataURL missing
    OIDCProviderIssuer                  https://127.0.0.1:443/idauth/oidc/endpoint/OP
    OIDCProviderAuthorizationEndpoint   $cp_url/idprovider/v1/auth/authorize
    OIDCProviderTokenEndpoint           $cp_url/idprovider/v1/auth/token
    OIDCOAuthCLientID                   $client_id
    OIDCOAuthClientSecret               $client_secret
    OIDCOAuthIntrospectionEndpoint      $cp_url/idprovider/v1/auth/introspect
    # ? OIDCOAuthVerifyJwksUri          $cp_url/oidc/endpoint/OP/jwk
    OIDCProviderJwksUri                 $cp_url/oidc/endpoint/OP/jwk
    OIDCProviderEndSessionEndpoint      $cp_url/idprovider/v1/auth/logout
    OIDCScope                        "openid email profile"
    OIDCResponseMode                 "query"
    OIDCProviderTokenEndpointAuth     client_secret_post
    OIDCOAuthIntrospectionEndpointAuth client_secret_basic
    OIDCPassUserInfoAs json
    OIDCSSLValidateServer off
    OIDCHTTPTimeoutShort 10
    OIDCCacheEncrypt On
    
    <Location /oidc_login>
      AuthType  openid-connect
      Require   valid-user
      LogLevel   debug
    </Location>
    <LocationMatch ^/api(?!\/(v[\d\.]+\/)?product_info$)>
      SetEnvIf Authorization '^Basic +YWRtaW46'     let_admin_in
      SetEnvIf X-Auth-Token  '^.+$'                 let_api_token_in
      SetEnvIf X-MIQ-Token   '^.+$'                 let_sys_token_in
      SetEnvIf X-CSRF-Token  '^.+$'                 let_csrf_token_in
      AuthType     oauth20
      AuthName     "External Authentication (oauth20) for API"
      Require   valid-user
      Order          Allow,Deny
      Allow from env=let_admin_in
      Allow from env=let_api_token_in
      Allow from env=let_sys_token_in
      Allow from env=let_csrf_token_in
      Satisfy Any
      LogLevel   debug
    </LocationMatch>
    OIDCSSLValidateServer      Off
    OIDCOAuthSSLValidateServer Off
    RequestHeader unset X_REMOTE_USER                                                                            
    RequestHeader set X_REMOTE_USER           %{OIDC_CLAIM_PREFERRED_USERNAME}e env=OIDC_CLAIM_PREFERRED_USERNAME
    RequestHeader set X_EXTERNAL_AUTH_ERROR   %{EXTERNAL_AUTH_ERROR}e           env=EXTERNAL_AUTH_ERROR          
    RequestHeader set X_REMOTE_USER_EMAIL     %{OIDC_CLAIM_EMAIL}e              env=OIDC_CLAIM_EMAIL             
    RequestHeader set X_REMOTE_USER_FIRSTNAME %{OIDC_CLAIM_GIVEN_NAME}e         env=OIDC_CLAIM_GIVEN_NAME        
    RequestHeader set X_REMOTE_USER_LASTNAME  %{OIDC_CLAIM_FAMILY_NAME}e        env=OIDC_CLAIM_FAMILY_NAME       
    RequestHeader set X_REMOTE_USER_FULLNAME  %{OIDC_CLAIM_NAME}e               env=OIDC_CLAIM_NAME              
    RequestHeader set X_REMOTE_USER_GROUPS    %{OIDC_CLAIM_GROUPS}e             env=OIDC_CLAIM_GROUPS            
    RequestHeader set X_REMOTE_USER_DOMAIN    %{OIDC_CLAIM_DOMAIN}e             env=OIDC_CLAIM_DOMAIN 
EOF
else
tee im-oidc-secret.yaml  << EOF
kind: Secret                                                                                                     
apiVersion: v1                                                                                                   
metadata:                                                                                                        
  name: imconnectionsecret                                                                                         
stringData:
  oidc.conf: |-                                                                                                  
    LoadModule          auth_openidc_module modules/mod_auth_openidc.so
    ServerName          $im_url
    LogLevel            debug
    OIDCCLientID                   $client_id 
    OIDCClientSecret               $client_secret
    OIDCRedirectURI                $im_url/oidc_login/redirect_uri
    OIDCCryptoPassphrase           alphabeta
    OIDCOAuthRemoteUserClaim       sub
    OIDCRemoteUserClaim            name
    # OIDCProviderMetadataURL missing
    OIDCProviderIssuer                  https://127.0.0.1:443/idauth/oidc/endpoint/OP
    OIDCProviderAuthorizationEndpoint   $cp_url/idprovider/v1/auth/authorize
    OIDCProviderTokenEndpoint           $cp_url/idprovider/v1/auth/token
    OIDCOAuthCLientID                   $client_id
    OIDCOAuthClientSecret               $client_secret
    OIDCOAuthIntrospectionEndpoint      $cp_url/idprovider/v1/auth/introspect
    # ? OIDCOAuthVerifyJwksUri          $cp_url/oidc/endpoint/OP/jwk
    OIDCProviderJwksUri                 $cp_url/oidc/endpoint/OP/jwk
    OIDCProviderEndSessionEndpoint      $cp_url/idprovider/v1/auth/logout
    OIDCScope                        "openid email profile"
    OIDCResponseMode                 "query"
    OIDCProviderTokenEndpointAuth     client_secret_post
    OIDCOAuthIntrospectionEndpointAuth client_secret_basic
    OIDCPassUserInfoAs json
    OIDCSSLValidateServer off
    OIDCHTTPTimeoutShort 10
    OIDCCacheEncrypt On
    
    <Location /oidc_login>
      AuthType  openid-connect
      Require   valid-user
      LogLevel   debug
    </Location>
    <LocationMatch ^/api(?!\/(v[\d\.]+\/)?product_info$)>
      SetEnvIf Authorization '^Basic +YWRtaW46'     let_admin_in
      SetEnvIf X-Auth-Token  '^.+$'                 let_api_token_in
      SetEnvIf X-MIQ-Token   '^.+$'                 let_sys_token_in
      SetEnvIf X-CSRF-Token  '^.+$'                 let_csrf_token_in
      AuthType     oauth20
      AuthName     "External Authentication (oauth20) for API"
      Require   valid-user
      Order          Allow,Deny
      Allow from env=let_admin_in
      Allow from env=let_api_token_in
      Allow from env=let_sys_token_in
      Allow from env=let_csrf_token_in
      Satisfy Any
      LogLevel   debug
    </LocationMatch>
    OIDCSSLValidateServer      Off
    OIDCOAuthSSLValidateServer Off
    RequestHeader unset X_REMOTE_USER                                                                            
    RequestHeader set X_REMOTE_USER           %{OIDC_CLAIM_PREFERRED_USERNAME}e env=OIDC_CLAIM_PREFERRED_USERNAME
    RequestHeader set X_EXTERNAL_AUTH_ERROR   %{EXTERNAL_AUTH_ERROR}e           env=EXTERNAL_AUTH_ERROR          
    RequestHeader set X_REMOTE_USER_EMAIL     %{OIDC_CLAIM_EMAIL}e              env=OIDC_CLAIM_EMAIL             
    RequestHeader set X_REMOTE_USER_FIRSTNAME %{OIDC_CLAIM_GIVEN_NAME}e         env=OIDC_CLAIM_GIVEN_NAME        
    RequestHeader set X_REMOTE_USER_LASTNAME  %{OIDC_CLAIM_FAMILY_NAME}e        env=OIDC_CLAIM_FAMILY_NAME       
    RequestHeader set X_REMOTE_USER_FULLNAME  %{OIDC_CLAIM_NAME}e               env=OIDC_CLAIM_NAME              
    RequestHeader set X_REMOTE_USER_GROUPS    %{OIDC_CLAIM_GROUPS}e             env=OIDC_CLAIM_GROUPS            
    RequestHeader set X_REMOTE_USER_DOMAIN    %{OIDC_CLAIM_DOMAIN}e             env=OIDC_CLAIM_DOMAIN 
EOF
fi
echo "Finished generating OIDC file"
echo
echo
echo "------------------------"
echo "Generating registration.json file"
tee registration.json  << EOF
{
  "token_endpoint_auth_method":"client_secret_basic",
  "client_id": "$client_id",
  "client_secret": "$client_secret",
  "scope":"openid profile email",
  "grant_types":[
     "authorization_code",
     "client_credentials",
     "password",
     "implicit",
     "refresh_token",
     "urn:ietf:params:oauth:grant-type:jwt-bearer"
  ],
  "response_types":[
     "code",
     "token",
     "id_token token"
  ],
  "application_type":"web",
  "subject_type":"public",
  "post_logout_redirect_uris":["$cp_url"],
  "preauthorized_scope":"openid profile email general",
  "introspect_tokens":true,
  "trusted_uri_prefixes":["$cp_url/"],
  "redirect_uris":["$cp_url/auth/liberty/callback","$im_url/oidc_login/redirect_uri"]
  }
EOF

echo
echo 'Finished creating registration.json file'
echo '----------------------'
echo "Register OIDC endpoint with IAM: "
oc project kube-system
cloudctl target -n kube-system
cloudctl iam oauth-client-register -f registration.json
echo "Done with end point registration"

echo "----------------------"
echo "Creating OIDC secret:"
oc apply -f im-oidc-secret.yaml -n management-infrastructure-management

echo "----------------------"
echo "OIDC registration complete"
}


config_operator(){
echo "Creating Connection for opeators"

tee connection.yaml  << EOF
apiVersion: infra.management.ibm.com/v1alpha1
kind: Connection
metadata:
 annotations:
  BypassAuth: "$bypass"
 labels:
   controller-tools.k8s.io: "1.0"
 name: imconnection
 namespace: "management-infrastructure-management"
spec:
 cfHost: web-service.management-infrastructure-management.svc.cluster.local:3000
 secrets:
   accessToken:
     secretKeyRef:
       name: imconnectionsecret
       key: accesstoken
EOF

echo "Connection created"

oc apply -f connection.yaml -n management-infrastructure-management

}

import_navigation_file() {
	# run kubectl command
	echo "Running kubectl command to retrieve navigation items..."
	echo "*** A backup cr file is stored in ./navconfigurations.orginal"
	feedback=$(bash -c 'kubectl get navconfigurations.foundation.ibm.com multicluster-hub-nav -n kube-system -o yaml > navconfigurations.orginal' 2>&1)
	echo $feedback
	cp navconfigurations.orginal navconfigurations.yaml
	echo "Finished importing into navconfigurations.yaml"
	echo "Verifying..."
	#check if yaml file is valid
	if grep -Fxq "kind: NavConfiguration" navconfigurations.yaml; then
		echo "Navconfigurations.yaml file is valid"
	else
		echo "Failed to validate navconfigurations.yaml. Check above for errors. Ensure kubectl is authenticated."
		exit 1
	fi
}

check_exist() {
	if grep -iq "id: $id" navconfigurations.yaml; then
		echo "$product_name navigation menu item already exists. Aborting..."
		exit 1
	fi
}
add_navigation_items() {

		id="cloudforms"
		product_name="Infrastructure management"
		check_exist
		echo "Adding new navigation items to file..."
		inframgmt_nav_item="  - id: cloudforms\n    isAuthorized:\n    - ClusterAdministrator\n    - AccountAdministrator\n    - Administrator\n    - Operator\n    - Editor\n    - Viewer\n    label: Infrastructure management\n    parentId: automate\n    serviceId: mcm-ui\n    target: _blank\n    url: $im_url"
		awk_output="$(awk -v cloud="$inframgmt_nav_item" '1;/navItems:/{print cloud}' navconfigurations.yaml)"
		echo "$awk_output" >navconfigurations.yaml

}

# Update CR with augmented file.
apply_new_items() {
	echo "Updating MCM with new items..."
	feedback=$(bash -c 'kubectl apply -n kube-system -f navconfigurations.yaml --validate=false' 2>&1)
	if echo $feedback | grep -q 'Error from server (NotFound): the server could not find the requested resource'; then
		echo "Failed running kubectl apply. Error from server (NotFound): the server could not find the requested resource. The kubectl version needs to be updated."
	fi
	echo "Finished updating MCM"

}

discover_im_cp_urls(){
echo "------------"

echo "Find the Infrastructure Management and CP4MCM console URL."
cp_url=`oc get routes cp-console -o=jsonpath='{.spec.host}' -n ibm-common-services`
cp_url="https://$cp_url"

echo $cp_url
im_domain=${cp_url#"https://cp-console."}
im_url="https://$_arg_hostname.$im_domain"
echo "CP4MCM URL: $cp_url"
echo "IM URL: $im_url"

}



if [ -n "$_arg_all" ]; then
   echo "******** Installing all components"
   discover_im_cp_urls
   check_kubectl_installed
   oidc
   config_operator
   import_navigation_file
   add_navigation_items
   apply_new_items
   config_operator
   exit 0
fi


if [ -n "$_arg_oidc_only" ]; then
   echo "**** Installing oidc only"
   discover_im_cp_urls
   check_kubectl_installed
   oidc
   exit 0
fi

if [ -n "$_arg_nav_only" ]; then
   echo "***** Installing navigation link only"
   check_kubectl_installed
   discover_im_cp_urls
   import_navigation_file
   add_navigation_items
   apply_new_items
   exit 0
fi

if [ -n "$_arg_edit_nav" ]; then
   echo "***** Editing navigation menu "
   kubectl edit navconfigurations.foundation.ibm.com multicluster-hub-nav -n kube-system --validate=false
   exit 0
fi

print_help
exit 0

