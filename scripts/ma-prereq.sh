#!/bin/bash

function install_header_on_signle_node () {
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
nsenter -t 1 -n -m -u -p -i -- bash -c \\\"
#!/bin/bash
kernel_version=\\\`uname -r\\\`
arch=\\\`uname -m\\\`
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

repo_url_1=https://ftp.heanet.ie/pub/centos/8/BaseOS/x86_64/os/
repo_url_2=https://vault.centos.org/VERSION_PLACEHOLDER/BaseOS/x86_64/os/

if [[ \\\\\\\$arch == \\\\\\\"ppc64le\\\\\\\" ]]; then
    repo_url_1=https://ftp.heanet.ie/pub/centos/8/BaseOS/ppc64le/os/
    repo_url_2=https://vault.centos.org/VERSION_PLACEHOLDER/BaseOS/ppc64le/os/
fi


bash -c \\\\\\\"

src_kernel_version=\\\\\\\$kernel_version
rename_required=0
versions=\\\\\\\\\\\\\\\`curl -sk https://vault.centos.org/ | grep -E '<a href=.8\.[0-9]+\.[0-9]+/.>8\.[0-9]+\.[0-9]+/</a>' | sed 's@.*href=.@@g' | sed 's@/..*@@g'\\\\\\\\\\\\\\\`
IFS=\\\\\\\\\\\\\\\$'\\\\\\\\\\\\\\\\n'

###########################################
#   Trial 1:  download rpm & install
###########################################

if [[ ! -d \\\\\\\$kernel_header_dir ]]; then
    echo Trying \\\\\\\${repo_url_1}...
    status_code=\\\\\\\\\\\\\\\`curl --write-out %{http_code} -sk --output /etc/kernel-devel-\\\\\\\${kernel_version}.rpm \\\\\\\${repo_url_1}Packages/kernel-devel-\\\\\\\${kernel_version}.rpm\\\\\\\\\\\\\\\`
    if [[ "\\\\\\\\\\\\\\\$status_code" -eq 200 ]] ; then
        rpm2cpio /etc/kernel-devel-\\\\\\\${kernel_version}.rpm | cpio -id
    fi
fi

if [[ ! -d \\\\\\\$kernel_header_dir ]]; then   
    for line in \\\\\\\\\\\\\\\$versions
    do
        repo_url_alt=\\\\\\\\\\\\\\\`echo \\\\\\\${repo_url_2} | sed \\\\\\\\\\\\\\\"s/VERSION_PLACEHOLDER/\\\\\\\\\\\\\\\$line/g\\\\\\\\\\\\\\\"\\\\\\\\\\\\\\\`
        echo Trying \\\\\\\\\\\\\\\$repo_url_alt...
        status_code=\\\\\\\\\\\\\\\`curl --write-out %{http_code} -sk --output /etc/kernel-devel-\\\\\\\${kernel_version}.rpm \\\\\\\\\\\\\\\${repo_url_alt}Packages/kernel-devel-\\\\\\\${kernel_version}.rpm\\\\\\\\\\\\\\\`
        if [[ "\\\\\\\\\\\\\\\$status_code" -eq 200 ]] ; then
            rpm2cpio /etc/kernel-devel-\\\\\\\${kernel_version}.rpm | cpio -id
            break
        fi
    done
fi

###########################################
#   Trial 2:  download latest kernel-devel for the same major kernel version & install (then rename dir)
###########################################

if [[ ! -d \\\\\\\$kernel_header_dir ]]; then
    echo Trying \\\\\\\${repo_url_1}...
    found_kernel_version=\\\\\\\\\\\\\\\`curl -sk '\\\\\\\${repo_url_1}Packages/?C=M;O=A' | grep kernel-devel-\\\\\\\${kernel_major_version} | tail -n 1 | sed 's/.*kernel-devel-\(.*\).rpm.*/\1/g'\\\\\\\\\\\\\\\`
    if [[ ! -z "\\\\\\\\\\\\\\\$found_kernel_version" ]] ; then
        status_code=\\\\\\\\\\\\\\\`curl --write-out %{http_code} -sk --output /etc/kernel-devel-\\\\\\\\\\\\\\\${found_kernel_version}.rpm \\\\\\\${repo_url_1}Packages/kernel-devel-\\\\\\\\\\\\\\\${found_kernel_version}.rpm\\\\\\\\\\\\\\\`
        if [[ "\\\\\\\\\\\\\\\$status_code" -eq 200 ]] ; then
            rpm2cpio /etc/kernel-devel-\\\\\\\\\\\\\\\${found_kernel_version}.rpm | cpio -id
            src_kernel_version=\\\\\\\\\\\\\\\${found_kernel_version}
            rename_required=1
        fi
    fi
    
fi

if [[ ! -d \\\\\\\$kernel_header_dir ]]; then
    for line in \\\\\\\\\\\\\\\$versions
    do
        repo_url_alt=\\\\\\\\\\\\\\\`echo \\\\\\\${repo_url_2} | sed \\\\\\\\\\\\\\\"s/VERSION_PLACEHOLDER/\\\\\\\\\\\\\\\$line/g\\\\\\\\\\\\\\\"\\\\\\\\\\\\\\\`
        echo Trying \\\\\\\\\\\\\\\$repo_url_alt...
        found_kernel_version=\\\\\\\\\\\\\\\`curl -sk \\\\\\\\\\\\\\\"\\\\\\\\\\\\\\\${repo_url_alt}Packages/?C=M;O=A\\\\\\\\\\\\\\\" | grep kernel-devel-\\\\\\\${kernel_major_version} | tail -n 1 | sed 's/.*kernel-devel-\(.*\).rpm.*/\1/g'\\\\\\\\\\\\\\\`
        if [[ ! -z "\\\\\\\\\\\\\\\$found_kernel_version" ]] ; then
        status_code=\\\\\\\\\\\\\\\`curl --write-out %{http_code} -sk --output /etc/kernel-devel-\\\\\\\\\\\\\\\${found_kernel_version}.rpm \\\\\\\\\\\\\\\${repo_url_alt}Packages/kernel-devel-\\\\\\\\\\\\\\\${found_kernel_version}.rpm\\\\\\\\\\\\\\\`
        if [[ "\\\\\\\\\\\\\\\$status_code" -eq 200 ]] ; then
            rpm2cpio /etc/kernel-devel-\\\\\\\\\\\\\\\${found_kernel_version}.rpm | cpio -id
            src_kernel_version=\\\\\\\\\\\\\\\${found_kernel_version}
            rename_required=1
            break
        fi
    fi
    done 
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
    ret_val=`cat /tmp/ma-install-kernel.log | tail -n 3 | head -n 1`
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
            echo "./install-kernel-headers-on-all-nodes.sh [--debug-image=DEBUG_IMAGE]"
            exit 0
            ;;
    esac
    shift
done

#echo "debug_image: $debug_image"
#echo "remaining args: $*"


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
    if install_header_on_signle_node "$i" "$debug_image"; then
        continue
    else
        echo "Failed to install kernel header on ${nodearray[$i]}"
        exit 1
    fi
done
