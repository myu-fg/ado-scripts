#########################################################################################
# This script uses az ad CLI to search for service principals with expiring credentials
# listed in the sp-all.csv file which contains application_id, sp_object_id, display_name 
# and service principal type. As Directory Reader role cannot be assigned to a service 
# pricipal, this script has to be executed by a infrastructure team member for now.  
#  
# Usage: ./find-expiring-sp.sh sp-all.csv 1m
# 
# The first parameter is the service principals list csv file and the second parameter
# is the time span from now that the credentials will expire by
#########################################################################################

echo 'This script currently can only run by infrastructure team member directly'
echo 'How to run this script:'
echo '     ./find-expiring-sp.sh sp-all.csv 1m'
echo '     "1m" means in one month in this case'

sourceFile="$1"
expirationDate=$(date -v +$2  +%Y-%m-%d)

url=https://outlook.office.com/webhook/e7e77091-2a55-48dd-b6f3-974e04ffcc39@72f988bf-86f1-41af-91ab-2d7cd011db47/IncomingWebhook/dd854d91bc4744d694b61c05187633b0/dae8bb79-9600-4c4f-90f8-6403e65e5bd4?files=2

count=0

echo "Querying AZURE AD applicaiton credentials that will expire by $expirationDate..."

while read p; 
do
  #for each line in the input file, the first field is application Id and the second is the service principal objectId
  appId=$(cut -d',' -f1 <<<$p);
  objectId=$(cut -d',' -f2 <<<$p);

  # if this is an empty application Id, just skip this line
  if [ -z "$appId" ] ; then continue; fi

  # Querying AD to find expired credentials for applications
  result=$(az ad app show --id $appId --query "{displayName:displayName, appId:appId,  expiringPasswordCredentials:passwordCredentials[?endDate<'$expirationDate'], expiringKeyCredentials:keyCredentials[?endDate<'$week2Later']}" | jq 'select((.expiringKeyCredentials | length) > 0 or (.expiringPasswordCredentials | length) > 0)')

  if [ -z "$result" ] 
  then 
     :
  else 
    content="$content$result"
    count=$((count+1))
  fi

  # Querying AD to find expired credentials for service principals
  result=$(az ad sp show --id $objectId --query "{displayName:displayName, objectId:objectId,  expiringPasswordCredentials:passwordCredentials[?endDate<'$expirationDate'], expiringKeyCredentials:keyCredentials[?endDate<'$week2Later']}" | jq 'select((.expiringKeyCredentials | length) > 0 or (.expiringPasswordCredentials | length) > 0)')

  if [ -z "$result" ] 
  then 
     :
  else 
    content="$content$result"
    count=$((count+1))
  fi

done < $sourceFile

content=$(echo $content | jq -s .)

if [ "$content" != '[]'  ]; then   
  echo "Found $count expired/expiring AD applications or service principals"
  echo "Posting to Teams channel"
  echo $content
  curl -s -H "Content-Type:application/json" -X POST --data "{'title': 'Found $count expired/expiring application or service principal credentials by $expirationDate', 'text':'<pre>$content</pre>'}" $url

  echo 
  echo 
fi
