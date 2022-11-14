#!/bin/bash
# Purpose: Debug server load
# Author: Elisha | Cloudways

_bold=$(tput bold)
_underline=$(tput sgr 0 1)
_red=$(tput setaf 1)
_green=$(tput setaf 76)
_blue=$(tput setaf 38)
_reset=$(tput sgr0)

dir=$(pwd)
function _success()
{
	printf '%s✔ %s%s\n' "$_green" "$@" "$_reset"
}

function _error() {
    printf '%s✖ %s%s\n' "$_red" "$@" "$_reset"
}

function _note()
{
    printf '%s%s%sNote:%s %s%s%s\n' "$_underline" "$_bold" "$_blue" "$_reset" "$_blue" "$@" "$_reset"
}

get_email() {
if [ -z $email ]; then
	read -p "Enter primary email: " email
	get_email;
fi
}
get_apiKey() {
if [ -z $apikey ]; then
        read -p "Enter API key: " apikey
	get_apiKey;
fi
}
get_email;
get_apiKey;

# FETCH AND STORE ACCESS TOKEN
get_accesstoken() {
_note "Retrieving Access Token"
access_token=$(curl -s -H "Accept: application/json" -H "Content-Type:application/json" -X POST --data '{"email" : "'$email'", "api_key" : "'$apikey'"}'  'https://api.cloudways.com/api/v1/oauth/access_token'  | jq -r '.access_token');
sleep 5;
}

# FETCH SERVER LIST
get_serverList() {
curl -s -X GET --header 'Accept: application/json' --header 'Authorization: Bearer '$access_token'' 'https://api.cloudways.com/api/v1/server' > $dir/server-list.txt;
}

# GET SERVER IPs
get_serverIP() {
jq -r '.servers[] | select (.status == "'running'").public_ip' $dir/server-list.txt  > $dir/srvip.txt
readarray -t srvIP < <(cat $dir/srvip.txt);
}
#for i in "${!srvIP[@]}"; 
#	do echo "${srvIP[$i]}";
#done; 

get_SSHusers() {
jq -r '.servers[] | select (.status == "'running'").master_user' $dir/server-list.txt  > $dir/sshusers.txt
readarray -t sshuser < <(cat $dir/sshusers.txt);
}

get_serverID() {
jq -r '.servers[] | select (.status == "running").id' $dir/server-list.txt > $dir/srvIDs.txt;
readarray -t srvID < <(cat $dir/srvIDs.txt);
}

set_SSHkey() {
ssh-keygen -b 2048 -t rsa -f ~/.ssh/bulkops -q -N ""
pubkey=$(<~/.ssh/bulkops.pub);
}

get_accesstoken;
get_serverList;
get_serverIP;
get_serverID;
get_SSHusers;
set_SSHkey;

# Create JSON data for SSH key
create_keyFiles () {
for id in ${!srvID[@]}
#       do echo $id;
        do echo "{" > srv-${id}.json
        #echo "\"server_id\": \"${srvID[$id]}\"," >> srv-${id}.json
	echo "\"server_id\": ${srvID[$id]}," >> srv-${id}.json
        echo "\"ssh_key_name\": \"bulkOps\"," >> srv-${id}.json
        echo "\"ssh_key\": \"$pubkey\"" >> srv-${id}.json
        echo "}" >> srv-${id}.json
done
}
create_keyFiles;

#SET UP SSH KEYS
declare -a keyID=()
for srv in ${!srvID[@]}; do
	_note "Setting up SSH keys on Server ${srvID[$srv]}"
	keyID+=("$(curl -s -X POST -H "Content-Type: application/json" -H 'Accept: application/json' -H 'Authorization: Bearer '$access_token'' -d "@srv-${srv}.json" 'https://api.cloudways.com/api/v1/ssh_key' | jq -r '.id')") 
	sleep 5;
	rm srv-${srv}.json;
done;
#declare -p keyID

# CONNECT TO EACH RUNNING SERVER AND PERFORM A TASK
do_task() {
for i in ${!sshuser[@]}; do
#        echo "Master user: ${sshuser[$i]}";
#        echo "IP: ${srvIP[$i]}";
	sleep 10;
	echo -e "\nPerforming task on server ${srvIP[$i]}"
	ssh -i ~/.ssh/bulkops -o StrictHostKeyChecking=no ${sshuser[$i]}@${srvIP[$i]} 'bash -s' <<'EOF'	
        cd /home/master/;
        # touch server.txt
	for app in $(ls -l /home/master/applications/ | awk '/^d/ {print $NF}'); do
		cd /home/master/applications/$app/public_html/;
		# touch app.txt
		cd /home/master/applications/;
        done;
EOF
        _note "Exiting server ${srvIP[$i]}";
done;
}
do_task;

# Delete SSH keys
for id in ${!srvID[@]}
	do
	#echo " ID: $id, Server ID: ${srvID[$id]}, Key ID: ${keyID[$id]}" 
	curl -s -X DELETE -H "Content-Type: application/json" -H 'Accept: application/json' -H 'Authorization: Bearer '$access_token'' 'https://api.cloudways.com/api/v1/ssh_key/'${keyID[$id]}'?server_id='${srvID[$id]}'' 1>/dev/null;
	sleep 5;
done

rm $dir/server-list.txt $dir/srvip.txt $dir/srvIDs.txt $dir/sshusers.txt ~/.ssh/bulkops.pub ~/.ssh/bulkops
exit;
