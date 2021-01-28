#########################################################################################
# This script uses az and jq CLI to search for service principals with expiring resources
# listed in the terraform state file.  
#
# Usage: ./find-tf-expiring-resources.sh 1m
# Parameter '1m' is the time span, 1 month in this case, from now that the credentials 
# will expire by.
# 
#########################################################################################

devFile=fg-global.tfstateenv.dev
stgFile=fg-global.tfstateenv.stg 
prodFile=fg-global.tfstateenv.prod 

dateToExpire="$(date -v +$1  +%Y-%m-%d)"

#The web hook used by Flipgrid-Platform team's Hooks channel
url=https://outlook.office.com/webhook/e7e77091-2a55-48dd-b6f3-974e04ffcc39@72f988bf-86f1-41af-91ab-2d7cd011db47/IncomingWebhook/dd854d91bc4744d694b61c05187633b0/dae8bb79-9600-4c4f-90f8-6403e65e5bd4?files=2


az storage blob download \
--account-name fgterraform \
--account-key aRZFTGe/LpzcESCJHeN/Z0tOWsllE0vbGw+e1Bluxuqlyg4m1cLExhWP6JwSKqbqEJ70Xc0Cm4aObizyxhYt1Q== \
--container-name tfstate \
--name "fg-global.tfstateenv:dev" \
--file "./$devFile" -o none

az storage blob download \
--account-name fgterraform \
--account-key aRZFTGe/LpzcESCJHeN/Z0tOWsllE0vbGw+e1Bluxuqlyg4m1cLExhWP6JwSKqbqEJ70Xc0Cm4aObizyxhYt1Q== \
--container-name tfstate \
--name "fg-global.tfstateenv:stg" \
--file "./$stgFile" -o none

az storage blob download \
--account-name fgterraform \
--account-key aRZFTGe/LpzcESCJHeN/Z0tOWsllE0vbGw+e1Bluxuqlyg4m1cLExhWP6JwSKqbqEJ70Xc0Cm4aObizyxhYt1Q== \
--container-name tfstate \
--name "fg-global.tfstateenv:prod" \
--file "./$prodFile" -o none

echo "Searching terraform managed resources that will expire by $dateToExpire in dev env..."
devResult=$(jq --arg EXPIRE_DATE "$dateToExpire" '.resources[] | select( .. | .end_date? | select (. < $EXPIRE_DATE and . != null )) | .type + " -- " + .name' $devFile | jq -s .)
echo $devResult

echo "Searching terraform managed resources that will expire by $dateToExpire in stg env..."
stgResult=$(jq --arg EXPIRE_DATE "$dateToExpire" '.resources[] | select( .. | .end_date? | select (. < $EXPIRE_DATE and . != null )) | .type + " -- " + .name' $stgFile | jq -s .)
echo $stgResult 

echo "Searching terraform managed resources that will expire by $dateToExpire in prod env..."
prodResult=$(jq --arg EXPIRE_DATE "$dateToExpire" '.resources[] | select( .. | .end_date? | select (. < $EXPIRE_DATE and . != null )) | .type + " -- " + .name' $prodFile | jq -s .)
echo $prodResult 

rm $devFile
rm $stgFile
rm $prodFile

#adding <pre></pre> to remove markdown when posting to web hook 
if [ "$devResult" != "[]" ]; then  
    curl -s -H "Content-Type:application/json" -X POST --data "{'title': 'Found expiring resources by $dateToExpire from terraform state - dev', 'text':'<pre>$devResult</pre>'}" $url 
fi

if [ "$stgResult" != "[]" ]; then
    curl -s -H "Content-Type:application/json" -X POST --data "{'title': 'Found expiring resources by $dateToExpire from terraform state - stg', 'text':'<pre>$stgResult</pre>'}" $url
fi

if [ "$prodResult" != "[]" ]; then 
    curl -s -H "Content-Type:application/json" -X POST --data "{'title': 'Found expiring resources by $dateToExpire from terraform state - prod', 'text':'<pre>$prodResult</pre>'}" $url
fi

