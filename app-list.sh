#!/bin/bash
# Purpose: Get list of apps on CW account
# Author: Elisha | Cloudways

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

dir=$(pwd)
# FETCH AND STORE ACCESS TOKEN
get_accesstoken() {
access_token=$(curl -s -H "Accept: application/json" -H "Content-Type:application/json" -X POST --data '{"email" : "'$email'", "api_key" : "'$apikey'"}'  'https://api.cloudways.com/api/v1/oauth/access_token'  | jq -r '.access_token');
}

get_accesstoken;

# Get server list
curl -s -X GET --header 'Accept: application/json' --header 'Authorization: Bearer '$access_token'' 'https://api.cloudways.com/api/v1/server' > $dir/server-list.txt;

#curl -s -X GET --header 'Accept: application/json' --header 'Authorization: Bearer '$access_token'' 'https://api.cloudways.com/api/v1/server' | jq -r '.servers[] | select (.status == "running").id' >  /home/elisha/myscripts/srvIDs.txt;

# GET SERVER IDs
jq -r '.servers[].id' $dir/server-list.txt > $dir/srvIDs.txt;
readarray -t srvID < <(cat $dir/srvIDs.txt);
#echo $srvID;

# GET SERVER IPs
jq -r '.servers[].public_ip' $dir/server-list.txt  > $dir/srvip.txt
readarray -t srvIP < <(cat $dir/srvip.txt);

# GET RAM SIZE
#jq -r '.servers[] | select (.status == "'running'").instance_type' /home/elisha/myscripts/server-list.txt  > /home/elisha/myscripts/ramsize.txt
#readarray -t ramsize < <(cat /home/elisha/myscripts/ramsize.txt);

# GET SERVER LABEL
jq -r '.servers[].label' $dir/server-list.txt  > $dir/servername.txt
readarray -t srvName < <(cat $dir/servername.txt);

#echo -e "\n\n\t\tServer IP: ${srvIP[$i]}" > AppNames.csv;
for i in ${!srvID[@]}
	do
	echo -e "\nApplications on Server \"${srvName[$i]}\" IP: ${srvIP[$i]}\n" >> AppNames.txt
	varID=$(echo ${srvID[$i]});
# Fetch APP LABELS
	jq -r '.servers[] | select (.id == "'$varID'").apps[].label' $dir/server-list.txt > $dir/applabel.txt
	readarray -t labels < <(cat $dir/applabel.txt);
	#declare -p labels
	jq -r '.servers[] | select (.id == "'$varID'").apps[].created_at' $dir/server-list.txt > $dir/appdate.txt
        readarray -t dates < <(cat $dir/appdate.txt);
	#declare -p dates;
	#echo -e "Application Name\t\t\tCreated At" >> AppNames.txt
	for app in ${!labels[@]}
	do
		echo "App Name: ${labels[$app]}" >> AppNames.txt
		echo "Created At: ${dates[$app]}" >> AppNames.txt
	done
done	
rm $dir/server-list.txt $dir/srvip.txt $dir/srvIDs.txt $dir/appdate.txt $dir/applabel.txt
