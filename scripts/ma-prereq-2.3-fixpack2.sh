#!/bin/bash

function install_falco_driver_loader () {
    node_number=$1
    debug_image=$2
    image_option=""
    if [[ ! -z "$debug_image" ]] ; then
        echo "debug_image: $debug_image"
        image_option="--image"
    fi
    #echo $node_number
    nodename=${nodearray[$node_number]}
    echo "---------------------------------------------------------"
    echo ""
    echo "Start to install kernel headers on the node $nodename."
    echo ""

    oc debug ${image_option} ${debug_image} node/${nodename} -- bash -c "chroot /host bash -c \"
#!/bin/bash
    echo ''
    echo '---------------------------------------------------------'
    mkdir -p /root/.falco
    echo '---------------------------------------------------------'
    podman run --rm -i -t \
    --privileged \
    -v /root/.falco:/root/.falco \
    -v /proc:/host/proc:ro \
    -v /boot:/host/boot:ro \
    -v /lib/modules:/host/lib/modules:ro \
    -v /usr:/host/usr:ro \
    -v /etc:/host/etc:ro \
    docker.io/falcosecurity/falco-driver-loader:latest

    echo Exiting...
    exit 0

\\\\\\\" # end of bash


\\\" # end of nsenter
\" # end of chroot
echo \$?
" 2>&1 | tee /tmp/ma-install-kernel.log # end of oc debug
    ret_val=`cat /tmp/ma-install-kernel.log | tail -n 3 | head -n 1`
    rm /tmp/ma-install-kernel.log
    return $ret_val
}


declare -a nodearray=()

nodes=`oc get node --selector='node-role.kubernetes.io/worker' | awk '{print $0}'`

echo ""
echo "---------------------------------------------------------"
echo ""
num=0
# echo -e "${num} ) ALL nodes"
# num=$((++num))
# nodearray=("${nodearray[@]}" "ALL") 
IFS=$'\n'
for line in `echo -e "$nodes"`
do
    if [[ $num -eq 0 ]]; then
        echo -e "    $line"
    else
        echo -e "${num} ) $line"
    fi
    nodename=`echo $line | awk '{print $1}'`
    nodearray=("${nodearray[@]}" $nodename)
    num=$((++num))
done
echo "---------------------------------------------------------"
echo ""
echo "Installing kernel headers on all nodes shown above."
echo ""
# read userinput

node_num=${#nodearray[@]}
# if [[ $userinput -lt 1 || $userinput -gt $node_num ]]; then
#     echo "Input outside acceptable range. [ 1 - ${node_num} ]"
#     exit 1
# fi

for (( i = 1; i < $node_num; i++ )) 
do 
    if install_falco_driver_loader "$i" "$debug_image"; then
        echo "successfully installed falco-driver-loader"
        continue
    else
        echo "Failed to install kernel header on ${nodearray[$i]}"
        exit 1
    fi
done
