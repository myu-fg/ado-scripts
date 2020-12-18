while read p; 
do
  appId=$(cut -d',' -f1 <<<$p);
  if ( grep -q $appId fg-global.tfstateenv_dev ) || ( grep -q $appId fg-global.tfstateenv_stg ) || ( grep -q $appId fg-global.tfstateenv_prod )
	then 
		:
	else 
		echo $p
	fi
done < $1


