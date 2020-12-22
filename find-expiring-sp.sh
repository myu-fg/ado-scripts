

echo 'Run this script - ./find-expiring-sp.sh sp-all.csv 1m'

expirationDate=$(date -v +$2  +%Y-%m-%d)
sourceFile="$1"

url=https://outlook.office.com/webhook/e7e77091-2a55-48dd-b6f3-974e04ffcc39@72f988bf-86f1-41af-91ab-2d7cd011db47/IncomingWebhook/dd854d91bc4744d694b61c05187633b0/dae8bb79-9600-4c4f-90f8-6403e65e5bd4?files=2

content="["
count=0

echo "Querying expiring AD applicaiton credentials that will expire by $expirationDate..."

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
    content="$content$result,"
    count=$((count+1))
  fi

  # Querying AD to find expired credentials for service principals
  result=$(az ad sp show --id $objectId --query "{displayName:displayName, objectId:objectId,  expiringPasswordCredentials:passwordCredentials[?endDate<'$expirationDate'], expiringKeyCredentials:keyCredentials[?endDate<'$week2Later']}" | jq 'select((.expiringKeyCredentials | length) > 0 or (.expiringPasswordCredentials | length) > 0)')

  if [ -z "$result" ] 
  then 
     :
  else 
    content="$content$result,"
    count=$((count+1))
  fi

done < $sourceFile

content="$content{}]" 

if [ "$content" != '[{}]'  ]; then   
  echo "Found $count expired/expiring AD applications or service principals"
  echo "Posting to Teams channel"
  echo $content
  curl -s -H "Content-Type:application/json" -X POST --data "{'title': 'Found $count expired/expiring application or service principal credentials by $expirationDate', 'text':'<pre>$content</pre>'}" $url

  echo 
  echo 

  filename=expiring-app-sp-$(date +%Y-%m-%d).json
  echo "Uploading file $filename to Azure blob storage" 
  echo $content > $filename
  az storage blob upload \
    --account-name myustorageblob \
    --account-key fbT42dYhklymHpKCVv23r7V+8NMyNdTdDe7EUBhOecFJUJvVd9QjrrNB5abipkF029VPyPXNOPKwNLvBj5EoxQ== \
    --container-name expiring-alert \
    --file ./$filename \
    --name $filename -o none
fi
