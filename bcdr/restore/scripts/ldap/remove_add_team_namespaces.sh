#!/bin/bash

#--------------------------------------------------------------------------
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corporation 2019.
#
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corporation.
#--------------------------------------------------------------------------

print_usage() {
  echo ""
  echo "usage: ./remove_add_team_namespaces.sh -c <CP4MCM_URL>  -u <CP4MCM_USER>  -p <CP4MCM_PASS> [-v true|false]"
  echo "  where:"
  echo "        -c: CP4MCM URL"
  echo "        -u: CP4MCM User Login id eg. mcm-admin@ibm.com"
  echo "        -p: CP4MCM User Password"
  echo "        -v: (optional) Verbose option. If set to true it will be in verbose mode." 
  echo "        -f: (optional) Fetch, no prompt for user input. If set to true, no prompts, if lock dir exists, fetch and replace using lock dir" 
  echo ""
  echo "example: ./remove_add_team_namespaces.sh -c 'https://mcm-cp4mcm.multicloud-ibm.com' -u 'mcm.admin@ibm.com' -p '******' -v true"
  echo ""
  exit 1
}
gcp_version='v2'
while getopts ':c:u:p:v:f:' flag; do
  case "${flag}" in
  c) mcm_url="${OPTARG}"
     echo "MCM URL: $mcm_url" ;;
  u) mcm_user="${OPTARG}"
     echo "MCM USER: $mcm_user" ;;
  p) mcm_pass="${OPTARG}"
     # echo "MCM PASS: $mcm_pass" ;;
     echo "MCM_PASS:" $(echo "$mcm_pass" | sed -e 's/[a-zA-Z]/x/g' -e 's/[0-9]/n/g');;
  v) verbose="${OPTARG}"
     echo "verbose: $verbose" ;;
  f) no_prompts="${OPTARG}"
     echo "no_prompts: $no_prompts" ;;
  *) print_usage
     exit 1 ;;
esac
done

# Check if required commands are available
cmds=(jq tee curl python tr)
for c in "${cmds[@]}"
do
   if ! [ -x "$(command -v $c)" ]; then
   echo "Error: $c is not installed." >&2
   exit 1
   fi
done

CURRENT=`pwd`
# # switch currect dir
# if [ -d "scripts" ];
# then
#     pushd $CURRENT/scripts
# fi

if [[ "$verbose" == "true" || "$verbose" == "True" ]]; then
  echo "running script in verbose mode"
  verbose_flag="-v"
else
  verbose_flag="--silent"
fi

if [[ "$no_prompts" == "true" || "$no_prompts" == "True" ]]; then
  echo "No prompts"
  prompts="no"
else
  prompts="yes"
fi

if [[ "$mcm_url" == "" || "$mcm_user" == "" || "$mcm_pass" == "" ]]; then
    echo "Not enough arguments passed!"
    print_usage
    exit 1
fi

lock_dir="$CURRENT/_lock_"
log_file="$CURRENT/remove_add_namespace_output.log"


echo "============================================="  | tee -a "$log_file"
echo "$(date) ### Get AccessToken #############" | tee -a "$log_file"

# Get MCM AccessToken
mcm_idprovider_url="$mcm_url/idprovider/v1/auth/identitytoken"
echo "#################" | tee -a "$log_file"
echo "$(date)  get access token: $mcm_idprovider_url" | tee -a "$log_file"
mcm_idprovider_response=$(curl "$verbose_flag" -k \
    --header 'Content-Type: application/x-www-form-urlencoded' \
    --header 'charset: UTF-8' \
    --data-urlencode "grant_type=password" \
    --data-urlencode "username=$mcm_user" \
    --data-urlencode "password=$mcm_pass" \
    --data-urlencode "scope=openid" \
    -X POST "$mcm_idprovider_url") 
echo "$(date)  the response got from server is:: $mcm_idprovider_response" | tee -a "$log_file"
mcm_authorization=$(python -c "import json;
response = json.loads('$mcm_idprovider_response')
access_token = response['access_token']
token_type = response['token_type']
print('%s %s' % (token_type, access_token))")
echo "$(date) the mcm authorization is:: $mcm_authorization" | tee -a "$log_file"
echo "#################" | tee -a "$log_file"


# ===================================================================
# Fetch NameSpace resources for Teams, 
#  and create ./_lock_dir_/"<TEAM_ID>-ns-resources.json_mod" files
# ===================================================================
function fetch_teams_ns_resources() {
# --------------------
mcm_authorization=$1
lock_dir=$2
# --------------------

rm -rf "$lock_dir"
mkdir -pv "$lock_dir"

# Get Teams
teams_url="$mcm_url/idmgmt/identity/api/v1/teams"
echo "#################" | tee -a "$log_file"
echo "$(date)  get teams: $teams_url" | tee -a "$log_file"
teams_response=$(curl "$verbose_flag"  -k --location --request \
    -H "Content-Type:application/json" \
    -H "charset: UTF-8" \
    -H "Authorization: $mcm_authorization" \
    -X GET "$teams_url")
echo "$(date)  the response got from server is:: $teams_response" | tee -a "$log_file"
echo "#################" | tee -a "$log_file"


echo "#################" | tee -a "$log_file"
team_ids=$(python -c "import json;
teams = json.loads('$teams_response')
team_ids = []
for t in teams:
   team_ids.append(t.get('teamId')) 
print('|'.join(team_ids))")
echo "$team_ids" > "$lock_dir/team_ids.json_mod"
echo "$(date) the team ids are :: $team_ids" | tee -a "$log_file"
echo "#################" | tee -a "$log_file"

if [ "$team_ids" == "" ]
then
   echo ""
   echo "*** No Teams available!"
   echo ""
   exit 2
fi

team_id_array=($(echo "$team_ids" | tr '|' '\n'))
echo "${team_id_array}" | tee -a "$log_file"

# Filter namspace resurcess
for team_id in "${team_id_array[@]}"
do
echo "***** Start: Team: [$team_id] *********************************" | tee -a "$log_file"

mkdir -pv "$lock_dir/$team_id"

# Get Resources
team_resources_url="$mcm_url/idmgmt/identity/api/v1/teams/$team_id/resources"
echo "#################" | tee -a "$log_file"
echo "$(date)  get team resources : $team_resources_url" | tee -a "$log_file"
team_resources_response=$(curl "$verbose_flag"  -k --location --request \
    -H "Content-Type:application/json" \
    -H "charset: UTF-8" \
    -H "Authorization: $mcm_authorization" \
    -X GET "$team_resources_url")
echo "$(date)  the response got from server is:: $team_resources_response" | tee -a "$log_file"
echo "$team_resources_response" > "$lock_dir/$team_id-resources.json_mod"
echo "#################" | tee -a "$log_file"

# Get Namespace Resources
echo "#################" | tee -a "$log_file"
team_ns_resources=$(python -c "import json;
resources = json.loads('$team_resources_response')
team_ns_resources = []
for r in resources:
   if 'scope' in r and r['scope'] == 'namespace':
      team_ns_resources.append(r)
print(json.dumps(team_ns_resources))")
echo "$(date) the team_ns_resources are :: $team_ns_resources" | tee -a "$log_file"
echo "$team_ns_resources" > "$lock_dir/$team_id-ns-resources.json_mod"
echo "#################" | tee -a "$log_file"

echo "***** End: Team: [$team_id] *********************************" | tee -a "$log_file"
done
# End-for team_id in "${team_id_array[@]}"

}
# End-Func: fetch_teams_ns_resources()


# ============================================================
#  Remove and Add NameSpaces resources in Teams.
#  Read ./_lock_dir/"<TEAM_ID>-ns-resources.json_mod" files,
#    and remove & add namespaces
# ============================================================
function remove_and_add_ns_resource_in_teams() {
# --------------------
mcm_authorization=$1
lock_dir=$2
# --------------------
echo "**** Start with Remove & Add Namespaces in [$lock_dir] ***" | tee -a "$log_file"

team_id_array=($(cat "$lock_dir/team_ids.json_mod" | tr '|' '\n'))
echo "${team_id_array}" | tee -a "$log_file"

has_some_failures=""

for team_id in "${team_id_array[@]}"
do

team_ns_json_file="$lock_dir/$team_id-ns-resources.json_mod"
if [ ! -f "$team_ns_json_file" ]; then
    echo "** $team_ns_json_file does not exist"
    continue
fi

echo "***** Start: Team: [$team_id] *********************************" | tee -a "$log_file"
echo "== File: $team_ns_json_file =================================" | tee -a "$log_file"

tmp_dir="$team_id"
rm -rf "$tmp_dir"
mkdir -pv "$tmp_dir"

echo "#################" | tee -a "$log_file"
# Create individual ns files 
ns_count=$(python -c "import json;
with open('$team_ns_json_file') as f:
   ns_resources = json.load(f)
   data=[]
   i = 0
   for r in ns_resources:
      tmp_file = '$tmp_dir/%d.json_mod' % i
      with open(tmp_file, 'w') as outfile:
         json.dump(r, outfile)
      data.append(json.dumps(r))
      i = i + 1
   print('%d' % i)")
echo "$(date) the ns resources count is :: $ns_count" | tee -a "$log_file"

if [ "$ns_count" -eq "0" ]
then
echo "$(date) Do nothing for '$team_id'" | tee -a "$log_file"
echo "#################" | tee -a "$log_file"
else
echo "#################" | tee -a "$log_file"

failures=""
for ns_json_file in $tmp_dir/*.json_mod;
do

echo "** ns_json_file: $ns_json_file **"
ns_crn=$(python -c "import json;
with open('$ns_json_file') as f:
   ns_resource = json.load(f)
   crn = ns_resource['crn']
   print(crn)")

crn_url_encoded=$(jq -nr --arg v "$ns_crn" '$v|@uri')
echo "** crn_url_encoded: $crn_url_encoded"

# Delete Namespace Resource
team_ns_resource_url="$mcm_url/idmgmt/identity/api/v1/teams/$team_id/resources/rel/$crn_url_encoded"
echo "#################" | tee -a "$log_file"
echo "$(date) del team resource '$ns_crn' : $team_ns_resource_url" | tee -a "$log_file"
team_ns_resource_del_status=$(curl "$verbose_flag"  -k --location \
   --request DELETE "$team_ns_resource_url" \
   --header "Content-Type:application/json" \
   --header "charset: UTF-8" \
   --header "Authorization: $mcm_authorization" \
   --write-out %{http_code})
echo "$(date)  the status got from server is:: $team_ns_resource_del_status" | tee -a "$log_file"
echo "#################" | tee -a "$log_file"

if [ "$team_ns_resource_del_status" == "204" ]
then 

# Re-Add Namespace Resource
team_resource_url="$mcm_url/idmgmt/identity/api/v1/teams/$team_id/resources"
team_resource_payload="{ \"crn\": \"$ns_crn\"}"
echo "$(date) Add team resource : $team_resource_url" | tee -a "$log_file"
echo "$(date) Add : $team_resource_payload" | tee -a "$log_file"
team_ns_resource_add_response=$(curl "$verbose_flag" -k --location \
   --request POST "$team_resource_url" \
   --header 'Content-Type: application/json' \
   --header 'charset: UTF-8' \
   --header "Authorization: $mcm_authorization" \
   --write-out "|%{http_code}" \
   --data "$team_resource_payload")
echo "$(date)  the response got from server is:: $team_ns_resource_add_response" | tee -a "$log_file"
team_ns_resource_add_status=$(python -c "
rs='$team_ns_resource_add_response'
print(rs.split('|')[1])")
echo "$(date)  the status got from server is:: $team_ns_resource_add_status" | tee -a "$log_file"
echo "#################" | tee -a "$log_file"

else
   # Delete failed
   echo "$(date)  Delete failed for $team_id :: $ns_crn" | tee -a "$log_file"
fi

if [[ "$team_ns_resource_del_status" != "204" || "$team_ns_resource_add_status" != "200" ]]
then
   failures="$failures $ns_crn"
fi

done
# End-for: team_id in "${team_id_array[@]}"
fi

if [ "$failures" != "" ]
then
   echo "** There were some failures for [$team_id] :: $failures"  | tee -a "$log_file"
   has_some_failures="$has_some_failures $team_id"
else
   echo "** Success for [$team_id]"  | tee -a "$log_file"
   # Delete complete json files
   rm -rfv "$tmp_dir"
   rm -fv "$team_ns_json_file"
fi

echo "============================================="  | tee -a "$log_file"
done
# End-for: json_file in $lock_dir/*-ns-resources.json_mod

echo "============================================="  | tee -a "$log_file"
if [ "$has_some_failures" == "" ]
then
   rm -rfv "$lock_dir"
   echo "== All Resources re-added successfully ====="  | tee -a "$log_file"
else
   echo "== There were some failures for :: $has_some_failures"  | tee -a "$log_file"
   echo "== not deleting "$lock_dir"" | tee -a "$log_file"  | tee -a "$log_file"
fi

echo ""  | tee -a "$log_file"
echo ""  | tee -a "$log_file"

}
# End-Func: process_ns_resource_files()


# === START =========================================================== 
if [ -d "$lock_dir" ]
then
   echo "prompts: $prompts"
   if [ "$prompts" == "yes" ]
   then
      echo ""
      echo "**** Lock dir : [$lock_dir] exists, check if need to fetch!"
      for f in $lock_dir/*-ns-resources.json_mod; do
         echo "File: $f"
      done

      yes="Continue, with earlier fetched team resource data, to do 'remove & add namespaces'."
      no="Fetch again, overwrite the team resource data, and then do 'remove & add namespaces'."

      # yes="Do you want to continue with eariler job data ?"
      # no="Or do you want to fetch Team resource data again ?" 

      echo ""
      echo "**"
      echo "Looks like earlier task in did not complete, the fetched data from earlier run exists in lock dir[$lock_dir]."
      echo ""
      echo "Select what you want to do, 1 or 2 ?"
      select yn in "$yes" "$no"; do
         case $yn in
            "$yes" ) answer="yes"; echo "Continue with earlier data!"; break;;
            "$no" ) answer="no"; echo "Fetch again!"; break;;
         esac
      done
   else
      answer="no"
   fi

   if [ "$answer" == "no" ]
   then
      fetch_teams_ns_resources "$mcm_authorization" "$lock_dir"
   fi
else
   fetch_teams_ns_resources "$mcm_authorization" "$lock_dir"
fi

# Remove & Add Namespace in Teams
remove_and_add_ns_resource_in_teams "$mcm_authorization" "$lock_dir"

