#!/bin/bash

#set -x

print_help()
{
	printf '\t%s\n' " "
    printf '%s\n' "This script helps you to configure the integration settings for Chatops."
    printf '\t%s\n' " "
    printf 'Usage: %s  [-t <slack hubot token>] [-a <PagerDuty API key>] [-s <PagerDuty service key>] [-u <Monitoring URL>] [-n <Monitoring API key name>] [-p <Monitoring API key password>] [-h]\n' "$0"
    printf '\t%s\n' "-t: The Slack hubot token HUBOT_SLACK_TOKEN, it's the string as xoxb-YOUR-TOKEN-HERE"
    printf '\t%s\n' "-a: The PagerDuty REST API key"
    printf '\t%s\n' "-s: The PagerDuty service key (integration key)"
	printf '\t%s\n' "-u: The IBM Cloud Pak console URL"
	printf '\t%s\n' "-n: The Monitoring service API key name"
	printf '\t%s\n' "-p: The Monitoring service API key password"
	printf '\t%s\n' "-h: Prints help"
    printf '\t%s\n' " "
    printf 'Examples: %s\n' 
    printf '%s\n' "Update Slack Hubot token to connect with Slack, and update integration settings for PagerDuty to integrate with Pagerduty"    
    printf '%s\n' "    ./chatops_update.sh -t <HUBOT_SLACK_TOKEN> -a <PagerDuty API key> -s <PagerDuty service key>"    
    printf '%s\n' "Update Slack Hubot token to connect with Slack, and update integration settings for Monitoring service to integrate with Monitoring service"    
    printf '%s\n' "   ./chatops_update.sh -t <HUBOT_SLACK_TOKEN> -u <Monitoring URL> -n <Monitoring API key name> -p <Monitoring API key password>"    

}

parse_commandline()
{
    echo ""
    while getopts ":t:a:s:u:n:p:h" opt
    do
        case $opt in
            t)
            new_slack_token=$OPTARG
            echo "Slack hubot token HUBOT_SLACK_TOKEN:  $new_slack_token"   
            prefix="xoxb"
            if [[ $new_slack_token != $prefix* ]];then
                echo "ERROR: The Slack Hubot token format is not correct, the Slack Hubot token must be the string start with xoxb "  | tee -a "$logpath"
                exit 1
            fi
            ;; 
            a)
            new_pd_apikey=$OPTARG
            echo "PagerDuty REST API key:  $new_pd_apikey"  
            string_lenth=20
            if [[ ${#new_pd_apikey} -ne $string_lenth ]];then
                echo "ERROR: The PagerDuty REST API key is not correct, the PagerDuty REST API key must be the 20-character string"  | tee -a "$logpath"
                exit 1
            fi
            ;;
            s)
            new_pd_servicekey=$OPTARG
            echo "PagerDuty service key (integration key):  $new_pd_servicekey" 
            ;;
            u)
            new_cem_url=$OPTARG
            echo "IBM Cloud Pak console URL:  $new_cem_url" 
            prefix="https://"
            if [[ $new_cem_url != $prefix* ]];then
                echo "ERROR: The Monitoring service URL is not correct, it must start with https"  | tee -a "$logpath"
                exit 1
            fi
            ;;
            n)
            new_cem_apikey=$OPTARG
            echo "Monitoring service API key name:  $new_cem_apikey" 
            ;;
            p)
            new_cem_apipass=$OPTARG
            echo "Monitoring service API key password:  $new_cem_apipass" 
            ;;
            h)
            print_help
            exit 1
            ;;
            \?)
            echo "ERROR: Invalid option: -$OPTARG"
            print_help
            exit 1 
      ;;
        esac
    done

    if [[ -n "$new_cem_url" ]]||[[ -n "$new_cem_apikey" ]]||[[ -n "$new_cem_apipass" ]]||[[ -n "$new_pd_apikey" ]]||[[ -n "$new_pd_servicekey" ]]||[[ -n "$new_slack_token" ]]; then
        echo ""
        echo "Do you want to continue with these inputs [ y or n; \"n\" is default ]?"
        read REPLY
        case $REPLY in
            y*|Y*) ;;

            *) exit 0
            ;;
        esac
    fi 
}

####
# update integration settings for cem/pagerduty
###

update_object()
{
    target_object=$1
    target_setting=$2
    new_data=$3
    
    if [[ $target_object == "cem" ]]; then 
        old_yaml=$(cat /tmp/integration.yaml | grep cem_ibm.yaml | awk '{print $2}'| head -n 1)
        old_target_data=$(cat /tmp/cem.yaml | grep $target_setting | awk '{print $2}')
        sed -i -e "s#$target_setting: $old_target_data#$target_setting: $new_data#" /tmp/cem.yaml
        new_yaml=$(cat /tmp/cem.yaml | base64 -w0 )
        sed -i -e "s#cem_ibm.yaml: $old_yaml#cem_ibm.yaml: $new_yaml#" /tmp/integration.yaml
    fi

    if [[ $target_object == "pagerduty" ]]; then 
        old_yaml=$(cat /tmp/integration.yaml | grep pagerduty.yaml | awk '{print $2}'| head -n 1)
        old_target_data=$(cat /tmp/pagerduty.yaml | grep $target_setting | awk '{print $2}')
        sed -i -e "s#$target_setting: $old_target_data#$target_setting: $new_data#" /tmp/pagerduty.yaml
        new_yaml=$(cat /tmp/pagerduty.yaml | base64 -w0 )
        sed -i -e "s#pagerduty.yaml: $old_yaml#pagerduty.yaml: $new_yaml#" /tmp/integration.yaml
    fi
}


####
# update integration settings for cem or pagerduty in the secret chatops-st2-pack-configs 
###
update_integrate_settings() 
{
    num=0
    final=20
    echo ""

    if [[ -n "$new_cem_url" ]]||[[ -n "$new_cem_apikey" ]]||[[ -n "$new_cem_apipass" ]]||[[ -n "$new_pd_apikey" ]]||[[ -n "$new_pd_servicekey" ]]; then
        echo "Getting the cem/pagerduty configuration..."  | tee -a "$logpath"
        kubectl get secret $integration -n $namespace > /dev/null 2>&1
        result=$?
        if [[ ${result} -ne 0 ]]; then
            echo "ERROR: secret: $integration in namespace: $namespace does not exist" | tee -a "$logpath"
            exit 1
        fi
        kubectl get secret $integration -n $namespace -o yaml > /tmp/integration.yaml 

        if [[ -n "$new_cem_url" ]]||[[ -n "$new_cem_apikey" ]]||[[ -n "$new_cem_apipass" ]]; then
            kubectl get secret $integration -n $namespace -o yaml | awk '/cem_ibm.yaml:/{print $2}' | head -n 1 | base64 -d > /tmp/cem.yaml
        fi

        if [[ -n "$new_pd_apikey" ]]||[[ -n "$new_pd_servicekey" ]]; then
            kubectl get secret $integration -n $namespace -o yaml | awk '/pagerduty.yaml:/{print $2}' | head -n 1 | base64 -d > /tmp/pagerduty.yaml
        fi

        echo "Updating the secret..."  | tee -a "$logpath"
        if [[ -n "$new_cem_url" ]]; then 
           update_object "cem" "cem_url" $new_cem_url
        fi

        if [[ -n "$new_cem_apikey" ]]; then 
            update_object "cem" "cem_apikey" $new_cem_apikey
        fi

        if [[ -n "$new_cem_apipass" ]]; then 
            update_object "cem" "cem_apipass" $new_cem_apipass
        fi

        if [[ -n "$new_pd_apikey" ]]; then  
            update_object "pagerduty" "api_key" $new_pd_apikey
        fi

        if [[ -n "$new_pd_servicekey" ]]; then
            update_object "pagerduty" "service_key" $new_pd_servicekey 
        fi

        echo "Applying the updated secret..."  | tee -a "$logpath"
        kubectl apply -f /tmp/integration.yaml -n $namespace 

        echo "Restarting the st2client pod..."  | tee -a "$logpath"
        kubectl get pod -n $namespace | grep st2client | awk '{ print $1}' | xargs kubectl delete pod -n $namespace 
        result=$?
        if [[ ${result} -ne 0 ]]; then
            echo "ERROR: st2client pod in namespace: $namespace does not exist" | tee -a "$logpath"
            exit 1
        fi

        while [ $num -lt $final ]; do
            res=$(kubectl get po -n $namespace -l release=$release --no-headers | grep st2client | egrep -v 'Running')
            let num=$num+1
            if [[ -z "$res" ]]; then         # Completed
                num=$final
                flag=0
            else
                sleep 10
            fi
        done

        if [[ $flag -eq 0 ]]; then 
            echo "st2client pod restarted successfully" | tee -a "$logpath"
            echo "Reloading Chatops with new settings..."  | tee -a "$logpath"
            client_pods=$(kubectl get po -n $namespace | grep st2client | awk '{ print $1}')
            result=$(kubectl -n $namespace exec -it $client_pods -- st2ctl reload 2>/dev/null | grep -c terminated)

            if [[ $result -ne 0 ]]; then
                echo "ERROR: Failed to reload new integration settings" | tee -a "$logpath" 
            else
                echo "Reloaded new integration settings sucessfully" | tee -a "$logpath"  
            fi
        else
            echo "ERROR: Failed to restart st2client pod" | tee -a "$logpath"
        fi 

    fi

}

###
# update secret for slack connection
###
update_slack_connection() 
{
    num=0
    final=20
    echo ""
    #echo "new token is: $new_token" | tee -a "$logpath"

    if [[ -n "$new_slack_token" ]]; then
        new_token=$(echo -n $new_slack_token|base64)
        echo "Getting the slack configuration..." | tee -a "$logpath"
        kubectl get secret $slack -n $namespace > /dev/null 2>&1
        result=$?
        if [[ ${result} -ne 0 ]]; then
            echo "ERROR: secret: $slack in namespace: $namespace does not exist" | tee -a "$logpath"
            exit 1
        fi

        kubectl get secret $slack -n $namespace -o yaml > /tmp/slack.yaml 

        old_slack_token=$(oc get secret $slack -n $namespace -o yaml |awk '/HUBOT_SLACK_TOKEN:/{print $2}'|head -n 1)
        #echo "old slack token is: $old_slack_token" | tee -a "$logpath"

        echo "Updating the secret..."  | tee -a "$logpath"      
        sed -i -e "s#HUBOT_SLACK_TOKEN: $old_slack_token#HUBOT_SLACK_TOKEN: $new_token#" /tmp/slack.yaml 

        echo "Applying the updated secret..." | tee -a "$logpath"
        kubectl apply -f /tmp/slack.yaml -n $namespace 

        echo "Restarting the st2chatops pod" | tee -a "$logpath"
        kubectl get pod -n $namespace | grep st2chatops | awk '{ print $1}' | xargs kubectl delete pod -n $namespace
        result=$?
        if [[ ${result} -ne 0 ]]; then
            echo "ERROR: st2chatops pod in namespace: $namespace does not exist" | tee -a "$logpath"
            exit 1
        fi

        while [ $num -lt $final ]; do
            res=$(kubectl get po -n $namespace -l release=$release --no-headers | grep st2chatops | egrep -v 'Running')
            let num=$num+1
            if [[ -z "$res" ]]; then         # Completed
                num=$final
                flag=0
            else
                sleep 10
            fi
        done

        if [[ $flag -ne 0 ]]; then 
            echo "ERROR: Failed to restart st2chatops pod" | tee -a "$logpath"
        else
            echo "st2chatops pod restarted successfully" | tee -a "$logpath" 
        fi
    fi

}

###
# Check if oc login 
###
oclogin_verify() 
{
    oc status > /dev/null 2>&1	
    result=$?
    if [[ ${result} -ne 0 ]]; then
        echo "ERROR: Pls ensure that you are logged in to your cluster with oc login command." | tee -a "$logpath"
        exit 1
    fi
}


###
# Clean up the temp files
###
clean_up() 
{
	rm -f /tmp/integration.yaml 2>/dev/null
	rm -f /tmp/slack.yaml 2>/dev/null
	rm -f /tmp/cem.yaml 2>/dev/null
    rm -f /tmp/pagerduty.yaml 2>/dev/null
}


###
# Main code starts here.
###
timestamp=`date +%Y%m%d%H%M%S`
logs="chatops-template-update."
logpath="/tmp/$logs$timestamp.txt"

release=chatops
namespace=management-operations
integration=$release-st2-pack-configs
slack=$release-st2chatops

[[ $# -eq 0 ]] && print_help

parse_commandline "$@"
oclogin_verify
update_slack_connection
update_integrate_settings
clean_up

exit 0
