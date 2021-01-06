#!/bin/bash

function wait_until_running () {
    namespace=$1
    name=$2
    while true
    do
        echo "Waiting for debug pod to be Running..."
        sleep 5
        
        if oc get pod -n ${namespace} ${name} | grep Running > /dev/null ; then
            echo "the debug pod is ready. Start to copy files."
            break
        fi
    done
}

function install_header_on_signle_node () {
    node_number=$1
    rpm_file_path=$2
    rpm_file_name=`basename ${rpm_file_path}`
    debug_image=$3
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

    debug_pod=`oc debug node/${nodename} -o json`
    namespace=`echo -e "${debug_pod}" | jq -r .metadata.namespace`
    name=`echo -e "${debug_pod}" | jq -r .metadata.name`
    echo $namespace
    echo $name
    echo ""

    nohup bash -c "oc debug ${image_option} ${debug_image} node/${nodename} --no-tty=true -- sleep 600" > /dev/null &
    wait_until_running ${namespace} ${name}
    oc cp -n ${namespace} ${rpm_file_path} ${name}:/host/etc/${rpm_file_name}
    oc exec -it -n ${namespace} ${name} -- bash -c "chroot /host bash -c \"
#!/bin/bash
nsenter -t 1 -n -m -u -p -i -- bash -c \\\"
#!/bin/bash
kernel_version=\\\`uname -r\\\`
kernel_major_version=\\\`uname -r | sed 's/\([.0-9]*-[0-9]*\).*/\1/g'\\\`
kernel_header_dir=/usr/src/kernels/\\\\\\\${kernel_version}

###########################################
#   check the kernel header dir existence
###########################################

if [[ -d \\\\\\\$kernel_header_dir ]]; then
    echo ''
    echo '---------------------------------------------------------'
    echo 'Kernel headers are already installed. ( at '\\\\\\\$kernel_header_dir' )'
    echo Exiting...
    exit 0
fi

###########################################
#   create writable overlay
###########################################

bash -c 'cat > /etc/fstab << END
overlay /usr/src/kernels overlay lowerdir=/usr/src/kernels,upperdir=/opt/kernels,workdir=/opt/kernels.wd,nofail 0 0
END'

sudo mkdir -p /opt/kernels /opt/kernels.wd
sudo mount -o lowerdir=/usr/src/kernels,upperdir=/opt/kernels,workdir=/opt/kernels.wd -t overlay overlay /usr/src/kernels
sudo mkdir -p /opt/modules /opt/modules.wd
sudo mount -o lowerdir=/lib/modules,upperdir=/opt/modules,workdir=/opt/modules.wd -t overlay overlay /lib/modules

sudo setenforce 0

bash -c \\\\\\\"

src_kernel_version=\\\\\\\$kernel_version
rename_required=0

###########################################
#   Trial 1:  extract rpm & place the files
###########################################


if [[ ! -d \\\\\\\$kernel_header_dir ]]; then
    echo Extracting files from rpm...
    if [[ -f /etc/${rpm_file_name} ]] ; then
        rpm2cpio /etc/${rpm_file_name} | cpio -id
    fi

    if [[ -d \\\\\\\$kernel_header_dir ]]; then
        echo extracted files are placed at \\\\\\\$kernel_header_dir .
    else
        echo Trying to find kernel headers with same major kernel version...
        found_kernel_version=\\\\\\\\\\\\\\\`ls -1t '/usr/src/kernels/' | grep \\\\\\\${kernel_major_version} | head -n 1 \\\\\\\\\\\\\\\`
        if [[ ! -z "\\\\\\\\\\\\\\\$found_kernel_version" ]] ; then
            echo Found extracted files at /usr/src/kernels/\\\\\\\\\\\\\\\$found_kernel_version . this will be copied to /usr/src/kernels/\\\\\\\$kernel_version .
            src_kernel_version=\\\\\\\\\\\\\\\${found_kernel_version}
            rename_required=1
        else
            echo ''
            echo Failed to find correct version of kernel header files. please confirm the RPM package is for \\\\\\\${kernel_major_version}.xx.xx .
            exit 1
        fi
    
    fi

fi


###########################################
#   rename dir name if necessary
###########################################

if [[ \\\\\\\\\\\\\\\$rename_required -eq 1 ]]; then
    cp -r /usr/src/kernels/\\\\\\\\\\\\\\\$src_kernel_version /usr/src/kernels/\\\\\\\$kernel_version
fi


\\\\\\\" # end of bash

###########################################
#   confirm the kernel header dir existence
###########################################

if [[ -d \\\\\\\$kernel_header_dir ]]; then
    echo '---------------------------------------------------------'
    echo Kernel headers are successfully installed!
    exit 0
else
    echo '---------------------------------------------------------'
    echo Failed to install kernel headers.
    exit 1
fi

\\\" # end of nsenter
\" # end of chroot
echo \$?
" 2>&1 | tee /tmp/ma-install-kernel.log # end of oc debug
    oc delete pod -n ${namespace} ${name}
    ret_val=`cat /tmp/ma-install-kernel.log | tail -n 1 | sed 's/[^0-9]*//g'`
    rm /tmp/ma-install-kernel.log
    return $ret_val
}

args=$(getopt -l "debug-image:" -o "d:h" -- "$@")

eval set -- "$args"

while [ $# -ge 1 ]; do
    case "$1" in
        --)
            # No more options left.
            shift
            break
            ;;
        -d|--debug-image)
            debug_image="$2"
            shift
            ;;
        -h|--help)
            echo "./install-kernel-headers-on-all-nodes-air-gap.sh [--debug-image=DEBUG_IMAGE] RPM_FILE"
            exit 0
            ;;
    esac
    shift
done

#echo "debug_image: $debug_image"
#echo "remaining args: $*"

declare -a nodearray=()

rpm_file_path=$*

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
    if install_header_on_signle_node "$i" "$rpm_file_path" "$debug_image" ; then
        continue
    else
        echo "Failed to install kernel header on ${nodearray[$i]}"
        exit 1
    fi
done
