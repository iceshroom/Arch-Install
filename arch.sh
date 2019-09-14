#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'


#全局变量

#目标安装磁盘，这个变量代表Arch将要安装到的磁盘，缺省值为/dev/sda，可由 -d 参数修改
TARGET_DISK='/dev/sda'

#自动分区中将要分的各个区大小
PARTITION_TO_MAKE=''

#需要分区标志，设置之后启用自动分区，此变量由脚本自动设置，一般不需修改
NEED_MAKE_PARTITION='0'

#需要格式化启动分区标志，此变量由脚本自动设置，一般不需修改
EFI_FORMAT='0'

#自动分区所创建的新分区
NEWDISK=''

#指定 / 将要被安装到的磁盘号，默认为自动分区中空间最大的分区，可由 -r/--rootdisk 参数指定
INSTALL_PARTITION=''

#指定 /boot/efi 的磁盘号，默认为自动分区中第一个分出的磁盘，默认大小为512M，可由 -b/--bootdisk 参数指定
BOOT_PARTITION=''

#是否是UEFI，1代表是, 0不是
IS_UEFI=''


#是否默认yes，由 -y 参数设置
YES='0'
NOCONFIRM=''

#保护正在使用的磁盘，此变量将被set_protect_disk()赋值为由 $TARGET_DISK 指定磁盘中已经存在的磁盘分区
#格式为 /dev/sd[a-z][1-9]
PROTECT_DISK=''


#基本安装包
PACKAGE=( vim gcc mesa ttf-dejavu wqy-zenhei alsa-utils ntfs-3g bash-completion networkmanager net-tools archlinuxcn-keyring )

#自定义桌面环境
GNOME_DESKTOP=( xorg gnome gnome-extra gdm gnome-tweak-tool)
DEEPIN_DESKTOP=( xorg deepin deepin-extra deepin-anything-arch )
DESKTOP=(${DEEPIN_DESKTOP[@]})
DE='d'

###############################

#输出帮助
print_help()
{
    echo -e "Archiso auto install and configure script by ${yellow} BBDDD7 ${plain}

    -d Specify installation disk，please use: -d /dev/sd* , Default is/dev/sda

    -g Set Graphic Interface environment. Follow g set to gnome.  Follow d set to DDE ,Default is DDE.
       Use: -g [dg]

    -s Default mode, ${red}(Best use this select when no other partition in your disk) ${plain}，Running scripts with default values，If this parameter is used, all other parameters will fail.
 ${red}Be careful${plain}，When using this parameter, the automatic partition will allocate 256MB (1MB If is BIOS boot on GPT) as ${red} /boot/efi (Be \"bios boot\" If is BIOS boot on GPT) ${plain} by default and the remaining disk space as ${red} / ${plain}.

    -h Print this help.

    -p Auto partition，Use：-p \"*G,*G, ...\" Replace the *  with the size of the partition you want，Should specified M and G  ，like \"20G,512M ...\"
       Use ”FULL“ to divide the remaining disk space into one partition，So \"FULL\" must be the last parameter，like: \"512M,20G,FULL\".
       If there are multiple parameters，Use \"\"  to enclose parameters and Separate by ','.If success，The script will output the result of the partition at the end.
       If the partition fails (the expected number of partitions is less than the actual number of partitions), the script exits directly.

    -r/--rootdisk Specify\"${red} / ${plain}\" partition，Use ：--rootdisk 1~128 or -r 1~128 (GPT),Default is the second partition make by Auto partition.

    -b/--bootdisk Specify\"${red} /boot/efi ${plain}\"partition，Use ：--bootdisk 1~128 or -b 1~128 (GPT), If no partition on the disk and -s is Used , It will be automated create ，If there was already a EFI partition, It will be auto detect and use.

    -y  Auto select yes, In the same time pacman will use --noconfirm.
        "
    exit 0
}

#检查是BIOS还是UEFI
BIOS_OR_UEFI()
{
    IS_UEFI=$( [ -d /sys/firmware/efi ] && echo '1' || echo '0' ) 
}

#检查PARTITION_TO_MAKE变量，此变量由-p参数设置
check_partition_to_make()
{
    check_list=(${PARTITION_TO_MAKE})
    list_num=0
    
    while [ $list_num -lt ${#check_list[@]} ]
    do
        result="$( echo ${check_list[$list_num]} | grep -E "^[1-9][0-9]*[MG]$")"
        result_full="$( echo ${check_list[$list_num]} | grep "FULL")"

        if [ "$result" != "" ] ;then
            check_list[$list_num]="$result"
        elif [ "$result_full" = "FULL" ];then
            check_list[$list_num]="$result_full"
        else
            check_list[$list_num]=''
        fi
        list_num=$(( $list_num+1 ))
    done
    PARTITION_TO_MAKE=(${check_list[@]})
}


#检查网络连接
check_net()
{
    ping -c 4 mirrors.163.com
    if [ $? -eq 0 ]; then
        echo -e "${green}Network connect!${plain}"
        return 0
    else
        echo -e "${red}Please check network connect!${plain}"
        exit 1
    fi
}



#保护已经存在的分区
set_protect_disk()
{
    PROTECT_DISK=($( ls ${TARGET_DISK}* | grep -v "^${TARGET_DISK}$" ))
}

#更新 NEWDISK 数组
find_new_disk()
{
    new_table=($( ls ${TARGET_DISK}* | grep -v "^${TARGET_DISK}$" ))

    findout="true"
    findcount1='0'
    findcount2='0'
    while [ $findcount1 -lt ${#new_table[@]} ]
    do
        while [ $findcount2 -lt ${#PROTECT_DISK[@]} ]
        do
            if [ ${new_table[$findcount1]} = ${PROTECT_DISK[$findcount2]} ]; then
                findout="fault"
                break
            fi
            findcount2=$(($findcount2+1))
        done
        if [ "$findout" == "true" ];then
            NEWDISK=( ${NEWDISK[@]} ${new_table[$findcount1]} )
        fi
        findcount1=$(($findcount1+1))
        findout="true"
    done

    #echo -e "find_target: ${green} ${find_out} ${plain}"
    echo -e "NEWDISK: ${yellow} ${NEWDISK[@]} ${plain}"
}

######################

#输出新创建的分区
print_newdisk()
{
    if [ "$( echo "${NEWDISK[@]}" | grep /dev )" == '' ]; then
        echo -e "${red}No partition was created!${plain}"
        exit 1
    fi
    echo -e "${yellow}New partitions：${plain}"
    for newdisk in "${NEWDISK[@]}"
    do
        fdisk -l ${newdisk}
    done
}

#执行分区函数
diskpart()
{
    set_protect_disk
    disk_num=0

    #在MBR分区中，fdisk要多输入一次回车
    IS_MBR=$(fdisk -l ${TARGET_DISK} | grep dos) 

    while [ $disk_num -lt ${#PARTITION_TO_MAKE[@]} ]
    do
        if [ "${PARTITION_TO_MAKE[$disk_num]}" !=  'FULL' ] ; then
	    if [ -n "$IS_MBR" ] ; then
            	echo -e "n\n\n\n\n+${PARTITION_TO_MAKE[$disk_num]}\nw" | fdisk -B $TARGET_DISK 
	    else
		echo -e "n\n\n\n+${PARTITION_TO_MAKE[$disk_num]}\nw" | fdisk -B $TARGET_DISK
	    fi
        else
	    if [ -n "$IS_MBR" ] ; then
            	echo -e "n\n\n\n\n\nw" | fdisk -B $TARGET_DISK
	    else
		echo -e "n\n\n\n\nw" | fdisk -B $TARGET_DISK
	    fi	    
        fi
            partprobe
            disk_num=$(( $disk_num + 1 ))
    done

    sleep 1
    find_new_disk

    if [ -z "$BOOT_PARTITION" ] ; then
        BOOT_PARTITION="${NEWDISK[0]}"
        EFI_FORMAT='1'
    fi
    if [ -z "$INSTALL_PARTITION" ] ; then
	if [ ${PARTITION_TO_MAKE[0]} == 'FULL' ] ; then
            INSTALL_PARTITION="${NEWDISK[0]}"
	else
	    INSTALL_PARTITION="${NEWDISK[1]}"
	fi
    fi


    if [ '${NEWDISK[@]}' != '' ] ; then
        print_newdisk
        return 0
    else
        echo -e "${red}diskpart fault!${plain}"
        exit 1
    fi

}

is_diskpart_success()
{
    if [ ${#PARTITION_TO_MAKE[@]} != ${#NEWDISK[@]} ];then
        echo -e "${red}diskpart fault!${plain}"
        exit 1;
    fi
}


#设置镜像
set_mirror()
{
    mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.back
    echo "Server = http://mirrors.163.com/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist
    echo '[archlinuxcn]
SigLevel = Optional TrustedOnly
Server = http://mirrors.163.com/archlinux-cn/$arch
' >> /etc/pacman.conf
}


#安装运行脚本所需要的包
pre_download()
{
        pacman -Sy $NOCONFIRM expect
}

#通过fdisk -l寻找已经存在的efi或BIOS boot分区
find_efi()
{
    set_protect_disk
    num='0'
    efi_pa=''
    while [ "$num" -lt "${#PROTECT_DISK[@]}" ] && [ -z "$efi_pa" ]
    do
        if [ "$IS_UEFI" -eq '1' ] ; then
            efi_pa=$( fdisk -l "$TARGET_DISK" | grep "$TARGET_DISK" | grep -v Disk | grep EFI | awk '{print $1}' )
        else
            efi_pa=$( fdisk -l "$TARGET_DISK" | grep "$TARGET_DISK" | grep -v Disk | grep "BIOS boot" | awk '{print $1}' )
        fi 
        num=$(( $num + 1 ))
    done
    num=$(( $num - 1 ))
    if [ -n "$efi_pa" ] ; then
        BOOT_PARTITION=${efi_pa}
        echo -e "${red} Find Boot partition at ${BOOT_PARTITION} .${plain}"
        return 0
    fi
    
    return 1
}

#检查系统中存在的所有磁盘，通过查找BIOS boot 或 EFI启动分区来设置启动磁盘，在MBR+BIOS环境下将TARGET_DISK设置为/dev/sda
find_target_disk()
{
    target_temp=($(ls /dev/sd* | grep "^/dev/sd.$") $(ls /dev/nvme0n* | grep "^/dev/nvme0n.$"))
    num1='0'
    BIOS_OR_UEFI
    while [ "$num1" -lt "${#target_temp[@]}" ]
    do
        TARGET_DISK=${target_temp[$num1]}
        find_efi
        if [ $? -eq '0' ] ; then
            echo -e "${red} Set Target disk at ${TARGET_DISK} ${plain}"
            return
        fi
        num1=$(( $num1 + 1 ))
    done
    TARGET_DISK='/dev/sda'
    echo -e "${red} Default Target disk at ${TARGET_DISK} ${plain}"
}


#参数处理函数，按照参数来初始化全局变量
deal_opt()
{

    opt=($@)
    i=0
    while [ $i -lt $# ] 
    do 
        case ${opt[i]} in
            "-h")  
                   print_help
                   i=$(($i+1))
                   ;;
            "-g")
                   i=$(($i+1))
                   if [ "g" =  "${opt[$i]}" ];then
                        DESKTOP=(${GNOME_DESKTOP[@]})
                        DE='g'
                   elif [ "d" =  "${opt[$i]}" ];then
                        DESKTOP=(${DEEPIN_DESKTOP[@]})
                        DE='d'
                   fi
                   echo "${yellow} Select ${DESKTOP} ${plain}"
                   i=$(($i+1))
                   ;;
            "-s")  
                   if [ "$IS_UEFI" == "1" ] ; then
                        if [ -z "$BOOT_PARTITION" ] ; then
                            deal_opt -p "256M,FULL" -g d
                        else
                            deal_opt -p "FULL" -g d
                        fi
                   else
                        if [ -z "$BOOT_PARTITION" ] ; then
                            deal_opt -p "1M,FULL" -g d
                        else
                            deal_opt -p "FULL" -g d
                        fi
                   fi
                   break
                   ;;
            "-d")
                  i=$(($i+1))
                  TARGET_DISK=$( echo ${opt[$i]} | grep -E "^/dev/sd[a-z]$" )
		          if [ -z "$TARGET_DISK" ] ; then
		  	        TARGET_DISK=$( echo ${opt[$i]} | grep -E "^/dev/nvme0n.$" )
		          fi
                  if [ -z "$TARGET_DISK" ] ; then
                    echo -e "${red}Unreconized disk: ${opt[$i]}${plain}"
                    exit 0
                  fi
                  i=$(($i+1))
                  echo $TARGET_DISK 
                  ;;
            "-p")
                  i=$(($i+1))
                  PARTITION_TO_MAKE=$( echo ${opt[$i]} | sed 's/,/\ /g' )
		          NEED_MAKE_PARTITION='1'
                  i=$(($i+1))
                  check_partition_to_make
                  ;;
            "-r" | "--rootdisk")
                  i=$(($i+1))
                  INSTALL_PARTITION=$( echo ${opt[$i]} | grep -E "^[1-9]+$" )
                  if [ -z "$INSTALL_PARTITION" ] ; then
                    echo -e "${red}Unreconized partition: ${TARGET_DISK}${opt[$i]}${plain}"
                    exit 0
                  fi
                  if [ $INSTALL_PARTITION -gt 128 ] ; then
                    echo -e "${red}Partition illegal: $TARGET_DISK${opt[$i]}${plain} , should in range ${TARGET_DISK}1~128. "
                    exit 0;
                  fi
		  temp_tar=$( echo $TARGET_DISK | grep nvme )
		  if [ -z "$temp_tar" ] ; then
                  	INSTALL_PARTITION=$TARGET_DISK${opt[$i]}
		  else
			INSTALL_PARTITION="${TARGET_DISK}p${opt[$i]}"
		  fi
                  i=$(($i+1))
                  ;;
            "-b" | "--bootdisk")
                  i=$(($i+1))
                  BOOT_PARTITION=$( echo ${opt[$i]} | grep -E "^[1-9]+$" )
                  if [ -z "$BOOT_PARTITION" ] ; then
                    echo -e "${red}Unreconized partition: ${TARGET_DISK}${opt[$i]}${plain}"
                    exit 0
                  fi
                  if [ $BOOT_PARTITION -gt 128 ] ; then
                    echo -e "${red}Partition illegal: $TARGET_DISK${opt[$i]}${plain} , should in range ${TARGET_DISK}1~128. "
                    exit 0;
                  fi
                  BOOT_PARTITION=$TARGET_DISK${opt[$i]}
                  i=$(($i+1))
                  ;;
            "-y")
                  YES='1'
                  NOCONFIRM='--noconfirm'
                  i=$(($i+1))
                  ;;
              * )
                  echo "Undefine option: ${opt[i]} , exit"
                  exit 1;
                  ;;
        esac
    done
}

#main
#直接运行脚本不带参数，输出-h然后退出，其他情况先运行find_target_disk设置全局变量然后再处理参数.
if [ $# -eq 0 ]; then
    deal_opt -h
else
    if [ "$EUID" -ne 0 ]; then
	    echo -e "${red}need been root，use sudo${plain} "
	    exit 1;
    fi  
    find_target_disk
    deal_opt $@
fi

if [ "$NEED_MAKE_PARTITION" -eq '1' ]; then
diskpart
is_diskpart_success
fi

echo -e "${red}root(/) locate at：$INSTALL_PARTITION"
echo -e "/boot/efi locate at：$BOOT_PARTITION ${plain}"
sleep 1

BIOS_OR_UEFI

#确定分区是MBR或GPT
EFI_N=$(fdisk -l ${TARGET_DISK} | grep dos)

#当在BIOS+GPT时，需要BIOS boot分区.而在UEFI时只需要EFI.
if [ "$IS_UEFI" -eq '1' ] ; then
    if [ -n "$EFI_N" ] ;then
        EFI_N="ef"
    else
        EFI_N="1"
    fi
else
    if [ -n "$EFI_N" ] ;then
        EFI_N="ef"
    else
        EFI_N="4"
    fi
fi

if [ "$EFI_FORMAT" -eq '1' ] ; then
    echo -e "${red} Format EFI ( bios boot ) partition! Are you sure to continue?[y/n] ${plain}"
    read -a yesno
    if [ "$yesno" = "y" ]; then
        mkfs.fat -F32 $BOOT_PARTITION
        BOOT_PARTITION_NUM=$( echo $BOOT_PARTITION | sed "s/\/dev\/sd.//g" )
        fatlabel $BOOT_PARTITION EFI
        echo -e "t\n${BOOT_PARTITION_NUM}\n${EFI_N}\nw" | fdisk -B $TARGET_DISK
    else
        echo -e "${red} CANCEL! ${plain}"
        exit 1
    fi
fi
mkfs.ext4 $INSTALL_PARTITION

mount $INSTALL_PARTITION /mnt
mkdir -vp /mnt/boot/efi

#BIOS下不需要efi，只在UEFI下挂载
if [ "$IS_UEFI" -eq '1' ] ; then
    mount $BOOT_PARTITION /mnt/boot/efi
fi

check_net
timedatectl set-timezone Asia/Shanghai
timedatectl set-ntp true
echo "DNS=8.8.8.8" >> /etc/systemd/resolved.conf
systemctl start systemd-resolved.service

set_mirror
pacman -Sy
while [ "$?" -ne "0" ]
do
    pacman -Sy
done

pacstrap /mnt base base-devel grub os-prober efibootmgr  $NOCONFIRM
while [ "$?" -ne "0" ]
do
    echo -e "${yellow} pacstrap was fail,try again? [y/n]${plain}"
    read -a yesno3
    if [ "$yesno3" = "y" ]; then
        pacstrap /mnt base base-devel grub os-prober efibootmgr  $NOCONFIRM
    else
        echo -e "${red} CANCEL! ${plain}"
        exit 1
    fi
done

genfstab -U /mnt >> /mnt/etc/fstab

pacstrap /mnt ${PACKAGE[@]} ${DESKTOP[@]} $NOCONFIRM
while [ "$?" -ne "0" ]
do
    echo -e "${yellow} pacstrap was fail,try again? [y/n]${plain}"
    read -a yesno4
    if [ "$yesno4" = "y" ]; then
        pacstrap /mnt ${PACKAGE[@]} ${DESKTOP[@]} $NOCONFIRM
    else
        echo -e "${red} CANCEL! ${plain}"
        exit 1
    fi
done

ln -sf /mnt/usr/share/zoneinfo/Asia/Shanghai /mnt/etc/localtime
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "zh_CN.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "LANG=zh_CN.UTF-8" >> /mnt/etc/locale.conf

echo "Arch" >> /mnt/etc/hostname
echo '127.0.0.1       localhost
::1             localhost
127.0.1.1       Arch.localdomain  Arch' >> /mnt/etc/hosts

echo '[archlinuxcn]
SigLevel = Optional TrustedOnly
Server = http://mirrors.163.com/archlinux-cn/$arch
' >> /mnt/etc/pacman.conf

mv /mnt/etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist.back
echo "Server = http://mirrors.163.com/archlinux/\$repo/os/\$arch" > /mnt/etc/pacman.d/mirrorlist

useradd -m -G wheel -R /mnt admin
echo "admin:admin123" | chpasswd -R /mnt
echo "%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers

echo '#!/bin/bash ' >> /mnt/set.sh
echo 'hwclock --systohc
locale-gen' >> /mnt/set.sh
isx64=$(uname -a | grep x86_64 )

if [ "$IS_UEFI" -eq '1' ] && [ -n "$isx64" ] ; then
    echo 'grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-install --target=x86_64-efi' >> /mnt/set.sh
else
    echo "grub-install --target=i386-pc $TARGET_DISK" >> /mnt/set.sh
fi
echo 'sleep 1
grub-mkconfig -o /boot/grub/grub.cfg
echo "DNS=8.8.8.8" >> /etc/systemd/resolved.conf
' >> /mnt/set.sh

if [ "$DE" = 'd' ];then
    echo 'systemctl enable lightdm.service' >> /mnt/set.sh
else
    echo 'systemctl enable gdm.service' >> /mnt/set.sh
fi

echo 'systemctl enable systemd-resolved.service
systemctl enable systemd-resolved.service
systemctl enable NetworkManager
exit 0'  >> /mnt/set.sh

chmod a+x /mnt/set.sh

mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /tmp /mnt/tmp
mount --bind /sys /mnt/sys
chroot /mnt /bin/bash /set.sh

umount /mnt/dev
umount /mnt/proc
umount /mnt/tmp
umount /mnt/sys
if [ "$IS_UEFI" -eq "1"];then
    umount /mnt/boot/efi
fi
umount /mnt

if [ $YES -eq '0' ] ;then
    echo -e "${green} All work has been completed. Reboot now? [y/n]${plain}"
    read -a yesno2
    if [ "$yesno2" = "y" ]; then
        reboot
    else
        echo -e "${red} Reboot later! ${plain}"
        exit 0
    fi
else
    reboot
fi
exit 0
