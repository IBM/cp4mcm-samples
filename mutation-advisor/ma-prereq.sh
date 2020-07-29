#!/bin/bash

function install_header_on_signle_node () {
    node_number=$1
    #echo $node_number
    nodename=${nodearray[$node_number]}
    echo "---------------------------------------------------------"
    echo ""
    echo "Start to install kernel headers on the node $nodename."
    echo ""

    oc debug node/${nodename} -- bash -c "chroot /host bash -c \"
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

repo_url_1=http://ftp.heanet.ie/pub/centos/8/BaseOS/x86_64/os/
repo_url_2=http://vault.centos.org/8.1.1911/BaseOS/x86_64/os/

bash -c \\\\\\\"

src_kernel_version=\\\\\\\$kernel_version
rename_required=0

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
    echo Trying \\\\\\\${repo_url_2}...
    status_code=\\\\\\\\\\\\\\\`curl --write-out %{http_code} -sk --output /etc/kernel-devel-\\\\\\\${kernel_version}.rpm \\\\\\\${repo_url_2}Packages/kernel-devel-\\\\\\\${kernel_version}.rpm\\\\\\\\\\\\\\\`
    if [[ "\\\\\\\\\\\\\\\$status_code" -eq 200 ]] ; then
        rpm2cpio /etc/kernel-devel-\\\\\\\${kernel_version}.rpm | cpio -id
    fi
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
    echo Trying \\\\\\\${repo_url_2}...
    found_kernel_version=\\\\\\\\\\\\\\\`curl -sk '\\\\\\\${repo_url_2}Packages/?C=M;O=A' | grep kernel-devel-\\\\\\\${kernel_major_version} | tail -n 1 | sed 's/.*kernel-devel-\(.*\).rpm.*/\1/g'\\\\\\\\\\\\\\\`
    if [[ ! -z "\\\\\\\\\\\\\\\$found_kernel_version" ]] ; then
        status_code=\\\\\\\\\\\\\\\`curl --write-out %{http_code} -sk --output /etc/kernel-devel-\\\\\\\\\\\\\\\${found_kernel_version}.rpm \\\\\\\${repo_url_2}Packages/kernel-devel-\\\\\\\\\\\\\\\${found_kernel_version}.rpm\\\\\\\\\\\\\\\`
        if [[ "\\\\\\\\\\\\\\\$status_code" -eq 200 ]] ; then
            rpm2cpio /etc/kernel-devel-\\\\\\\\\\\\\\\${found_kernel_version}.rpm | cpio -id
            src_kernel_version=\\\\\\\\\\\\\\\${found_kernel_version}
            rename_required=1
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
    if install_header_on_signle_node "$i"; then
        continue
    else
        echo "Failed to install kernel header on ${nodearray[$i]}"
        exit 1
    fi
done
