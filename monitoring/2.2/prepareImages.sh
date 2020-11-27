#! /bin/bash
pushImages(){
if [ ! -d $IMAGEFOLDER ]
then
  echo $IMAGEFOLDER " is not a valid folder that contains docker images you need"
  exit 1
fi
for item in $list 
do
  for FILE in `ls $IMAGEFOLDER | grep "$item"`
    do
      if [ -e $UA_INSTALL/ua-pkg/images/$FILE  ]
      then
        PREFIX=${FILE%%_*}
        SUFFIX=${FILE#*_}
        echo $PREFIX:$SUFFIX
        TAG=${SUFFIX%%.*}
        echo 'loading '$IMAGEFOLDER/$FILE
        docker load -i $IMAGEFOLDER/$FILE
        sleep 5
        echo 'tag to '$DOCKERREG/$PREFIX:$TAG
        docker tag $PREFIX:$TAG  $DOCKERREG/$PREFIX:$TAG     
        echo 'push image ' $DOCKERREG/$PREFIX:$TAG
        docker push $DOCKERREG/$PREFIX:$TAG
      else
        echo " failed to find the file " $UA_INSTALL/ua-pkg/images/$FILE
        exit
      fi
  done
done

}
createManifest(){
  for item in $list
  do
    FILE=`ls $IMAGEFOLDER | grep "${item}" | grep "amd64"`
    if [ -n "$FILE" ]
    then
      SUFFIX=${FILE#*_}
      TAG=${SUFFIX%-*}
      MANIFEST=`docker manifest inspect $DOCKERREG/$item:$TAG | grep "schemaVersion"` 
      echo $MANIFEST
      if [ -z "$MANIFEST" ]
      then
        echo "Create manifest for " $DOCKERREG/$item:$TAG   
        docker manifest create $DOCKERREG/$item:$TAG  \
                            $DOCKERREG/$item:$TAG-amd64 \
                            $DOCKERREG/$item:$TAG-ppc64le \
                            $DOCKERREG/$item:$TAG-s390x
      fi   
      echo "Push manifest for " $DOCKERREG/$item:$TAG             
      docker manifest push --purge $DOCKERREG/$item:$TAG  
      sleep 5 
    fi
  done
}
##----------------------------------------------------------------------
#    main function
##----------------------------------------------------------------------
if [ $# != 2 -a $# != 3 ]
  then
    echo " Please input 2 or 3 parameters: "
    echo "        #1 is directory that contains all images; "
    echo "        #2 is docker registry and image group split with / ; "   
    echo "        #3 is optional, it is image you want to push besides the default list (ua-operator ua-cloud-monitoring ua-repo ua-plugins reloader)"
    echo "  E.g:     ./prepareImages.sh  /var/uainstall  uaocp.fyre.ibm.com:5000/ua 'k8-monitor k8sdc-operator'"
    echo "  E.g:     ./prepareImages.sh  /var/uainstall  uaocp.fyre.ibm.com:5000/ua "
    exit 1
fi

UA_INSTALL=$1
DOCKERREG=$2
IMAGELIST=$3
IMAGEFOLDER=$UA_INSTALL/ua-pkg/images

list="ua-operator ua-cloud-monitoring ua-repo ua-plugins reloader $IMAGELIST" 
pushImages
createManifest
