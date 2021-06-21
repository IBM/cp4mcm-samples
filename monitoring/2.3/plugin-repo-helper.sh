#!/bin/bash


printUsage() {
    echo "Set environment variable PLUGIN_REPO, e.g.: export PLUGIN_REPO=https://plugin-repo-ua.apps.uaocp.os.fyre.ibm.com"
    echo "Usage: ./plugin-repo-helper.sh [-p | -t] [options...] <url>"
    echo "Options: "
    echo "    [ -p ]              Request with plugin endpoint, the request URL looks like this $PLUGIN_REPO/plugin"
    echo "    [ -t ]              Request with template endpoint, the request URL looks like this $PLUGIN_REPO/template"
    echo "    [ -a ]              List data for plugins or templates, depends on the first argument -p or -t"
    echo "    [ -G <plugin >]     Send a HTTP GET request for plugin <plugin>"
    echo "    [ -A <plugin >]     Send a HTTP POST request for plugin <plugin>"
    echo "    [ -D <plugin >]     Send a HTTP DELETE request for plugin <plugin>"
    echo "    [ --platform <platform>]          Platform of the plugin, alternative values include 'xlinux', 'plinuxle', 'zlinux'. For '-t', 'all' will be used if you don't set. "
    echo "    [ --pver <plugin version> ]       Plugin version, e.g.: --pver 2020.12.0"
    echo "    [ --uaver <ua sharelib version> ] UA core version, e.g.: --uaver 0.9.7, default value is '0.9.7' "
    echo "    [ --data <data file to post> ]    data file  e.g.: --data '@./ibmace_xlinux_2020.12.0_0.9.7.tar.gz' "
    echo "                                                                              "
    echo "    [ Example: ./plugin-repo-helper.sh -p -a ]"
    echo "    [ Example: ./plugin-repo-helper.sh -p -G ibmace --platform xlinux --pver 2020.12.0 --uaver 0.9.7 ]"
    echo "    [ Example: ./plugin-repo-helper.sh -p -G ibmace --platform xlinux --uaver 0.9.7 ]"
    echo "    [ Example: ./plugin-repo-helper.sh -p -D ibmace --platform xlinux --pver 2020.12.0 --uaver 0.9.7 ]"
    echo "    [ Example: ./plugin-repo-helper.sh -p -A ibmace --platform xlinux --pver 2020.12.0 --uaver 0.9.7 --data '@./ibmace_xlinux_2020.12.0_0.9.7.tar.gz' ]"
    echo "    [ Example: ./plugin-repo-helper.sh -t -a ]"
    echo "    [ Example: ./plugin-repo-helper.sh -t -G ibmace --pver 2020.12.0 ]"
    echo "    [ Example: ./plugin-repo-helper.sh -t -G ibmace --platform xlinux --pver 2020.12.0 ]"
    echo "    [ Example: ./plugin-repo-helper.sh -t -D ibmace --platform xlinux --pver 2020.12.0 ]"
    echo "    [ Example: ./plugin-repo-helper.sh -t -A ibmace --platform all --pver 2020.12.0  --data '@./ibmace_all_2020.12.0_CR.yaml' ]"

}
read_cmd_line() {

    if [ $# -lt 1 ]  ; then
        printUsage
        exit 1
    fi
    if [ -z ${PLUGIN_REPO} ]; then
      printf "Make sure you have set environment variable PLUGIN_REPO, e.g.: export PLUGIN_REPO=https://plugin-repo-ua.apps.uaocp.os.fyre.ibm.com \n"
      exit 1
    fi
    
     while [ $# != 0 ]; do

        case "$1" in
            -p)
              shift
              endpoint="plugin"
              ;;
            -t)
              shift
              endpoint="template"
              ;;
            -a)
              shift
                request="get"
              if [ ${endpoint} == "plugin" ]; then
                endpoint="plugins"
              else
                endpoint="templates"
              fi
              ;;
            -pa)
              shift
              request="get"
              endpoint="plugins"
              ;;
            -ta)
              shift
              request="get"
              endpoint="templates"
              ;;    
            -pG)
              shift
              request="get"
              endpoint="plugin"
              plugin=$1
              shift
              ;;
            -pD)
              shift
              request="delete"
              endpoint="plugin"
              plugin=$1
              shift
              ;;
            -pA)
              shift
              request="post"
              endpoint="plugin"
              plugin=$1
              shift
              ;;
            -tG)
              shift
              request="get"
              endpoint="template"
              plugin=$1
              shift
              ;;
            -tD)
              shift
              request="delete"
              endpoint="template"
              plugin=$1
              shift
              ;;
            -tA)
              shift
              request="post"
              endpoint="template"
              plugin=$1
              shift
              ;;
            -G)
              shift
              request="get"
              plugin=$1
              shift
             ;;
            -D)
              shift
              request="delete"
              plugin=$1
              shift
             ;;
            -A)
              shift
              request="post"
              plugin=$1
              shift
             ;;
            --platform)
              shift
              platform=$1
              shift
              ;;
            --pver)
              shift
              version=$1
              shift
              ;;
            --uaver)
              shift
              uashlibv=$1
              shift
              ;;
            --data)
              shift
              data=$1
              shift
              ;;   
            --help)
              printUsage
              exit 1
             ;;
            *)
              printf "\n Invalid params '$1', Please refer to usage below \n"
              printUsage
              exit 1
              ;;
            esac
    done
} # read_cmd_line

process_parameters(){

    if [ -z ${endpoint} ]; then
      printf "ERROR: no endpoint specified. \n"
      printUsage
      exit 1
    fi
    if [[ ${endpoint} == "plugins"  ]] || [[ ${endpoint} == "templates"  ]]; then
      request_url="${PLUGIN_REPO}/${endpoint}"
    elif [ ${endpoint} == "plugin" ]; then
      if [ -z ${plugin} ] || [ -z ${platform} ] || [ -z ${uashlibv} ]; then
        printf "ERROR: please input plugin name, platform and ua version for plugin reqeust \n"
        printUsage
        exit 1
      fi
      if [ ${request} != "get"  ] && [ -z ${version} ]; then
        printf "ERROR: please input plugin version for plugin reqeust POST or DELETE \n"
        printUsage
        exit 1
      fi
      request_url="${PLUGIN_REPO}/${endpoint}?name=${plugin}&platform=${platform}&version=${version}&uashlib.version=${uashlibv}"
      if [ ${request} == "post"  ]; then
        if [ -z ${data} ] ; then
          printf "ERROR: please input data to post, e.g.: --data '@./ibmace_xlinux_2020.12.0_0.9.7.tar.gz'  \n"
          printUsage
          exit 1
        else 
          #md5sum lwdc_xlinux_20.8.2.tgz 
          tmp=`md5sum ${data##*@}`
          md5sum=${tmp%% *}
        fi
        request_url="${request_url}&MD5=${md5sum}"
      fi
      DEL_SUCCESS="SUCCESS: plugin package ${plugin}_${platform}_${version}_${uashlibv}.tar.gz was not exist or removed successfully\n "
      DEL_WARNING="WARNING: plugin package ${plugin}_${platform}_${version}_${uashlibv}.tar.gz failed to remove\n"
      POST_SUCCESS="SUCCESS: plugin package ${data##*@} was posted successfully\n"
      POST_WARNING="WARNING: can't find file ${data##*@} or file is empty\n "
      GET_SUCCESS="SUCCESS: plugin package has been saved to "
      GET_WARNING="WARNING: There is no request package ${plugin}_${platform}_${version}_${uashlibv}.tar.gz in the repo\n"
    elif [ ${endpoint} == "template" ]; then
      if [ -z ${plugin} ] || [ -z ${version} ] ; then
          printf "ERROR: please input plugin name, plugin version for template request \n"
          printUsage
          exit 1
      fi
      if [ -z ${platform} ]; then
        platform="all"
      fi       
      if [ ${request} == "post"  ]; then
        if [ -z ${data} ] ; then
          printf "ERROR: please input data to post, e.g.: --data '@./ibmace_xlinux_2020.12.0_cr.yaml'  \n"
          printUsage
          exit 1
        fi
      fi
      request_url="${PLUGIN_REPO}/${endpoint}?name=${plugin}&platform=${platform}&version=${version}"
      DEL_SUCCESS="SUCCESS: CR template ${plugin}_${platform}_${version}_${uashlibv}.tpl was not exist or removed successfully\n"
      DEL_WARNING="WARNING: CR template ${plugin}_${platform}_${version}_${uashlibv}.tpl failed to delete\n"
      POST_SUCCESS="SUCCESS: CR template ${data##*@} was posted successfully\n"
      POST_WARNING="WARNING: can't find file ${data##*@} or file is empty \n"
      GET_SUCCESS="SUCCESS: CR template has been saved to "
      GET_WARNING="WARNING: There is no request template file ${plugin}_${platform}_${version}.tpl in the repo\n"
    fi
} #process_parameters

send_request(){
    if [[ ${endpoint} == "plugins"  ]] || [[ ${endpoint} == "templates"  ]]; then
      printf "curl -k \"${request_url}\"\n"
      response=`curl -k -s "${request_url}"`
      printf "${response}\n"
    elif [ ${request} == "delete" ]; then
        printf "curl -ikX DELETE  \"${request_url}\"\n"
        reponse=`curl -ikX DELETE -o /dev/null -s "${request_url}"`
        if [ ${endpoint} == "plugin" ]; then
          exist=`curl -k -o /dev/null -s -w %{http_code}  "${request_url}" | grep "404"`
        else
          exist=`curl -ik -s "${request_url}" | grep "Content-Length: 0"`
        fi
        if [ -n "${exist}" ]; then
          printf "\033[32m${DEL_SUCCESS}\033[0m"
        else
          printf "\033[31m${DEL_WARNING}\033[0m"
          printf "$(curl -ikX DELETE  "${request_url}")\n"
        fi
    elif [ ${request} == "get" ]; then
        if [ ${endpoint} == "plugin" ]; then
          exist=`curl -k -o /dev/null -s -w %{http_code}  "${request_url}"`
          if [ ${exist} == "200" ]; then
            output_file="./${plugin}_${platform}_${version}_${uashlibv}.tar.gz"
            printf "curl -k \"${request_url}\"  --output \"${output_file}\"\n"
            response=`curl -k -s  "${request_url}" --output "${output_file}"`
            printf "\033[32m${GET_SUCCESS}${output_file}\n\033[0m"
          else
             printf "\033[31m${GET_WARNING}\033[0m"
             printf "$(curl -ik "${request_url}")\n"
          fi
        else
            exist=`curl -k -o /dev/null -s -w %{http_code}  "${request_url}"`
            if [ ${exist} == "200" ]; then
              output_file="./${plugin}_${platform}_${version}_CR.yaml"
              printf "curl -k \"${request_url}\" | tee \"${output_file}\"\n"
              response=`curl -k -s  "${request_url}" | tee ${output_file}`
              if [ -s ${output_file} ]; then
                printf "\033[32m${GET_SUCCESS}${output_file}\033[0m\n${response}\n"
              else
                rm -rf  ${output_file}
                printf "\033[31m${GET_WARNING}\033[0m"
                printf "$(curl -ik "${request_url}")\n"
              fi
            else
                printf "\033[31m${GET_WARNING}\033[0m"
                printf "$(curl -ik "${request_url}")\n"
            fi
        fi
    elif [ ${request} == "post" ]; then
        if [ ! -s "${data##*@}" ]; then
          printf "\033[31m${POST_WARNING}\033[0m"
          exit 1
        fi
        if [ ${endpoint} == "plugin" ]; then
          printf "curl -ikX POST \"${request_url}\" --data-binary \"${data}\"\n"
          response=`curl -ikX POST  "${request_url}" --data-binary "${data}"`
        else 
          printf "curl -ikX POST \"${request_url}\" --data \"${data}\"\n"
          response=`curl -ikX POST -s "${request_url}" --data "${data}"`
        fi
        printf "${response}\n"
    fi 
} #send_request
#------------------------------------------------------------------------
# main function
#------------------------------------------------------------------------
current=`pwd`
read_cmd_line "$@"
process_parameters
send_request
