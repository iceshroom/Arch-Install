# Arch-Install
## Arch-Install-script

## 2020-6-22 更新：
* 1.修复了MBR+LEGACY环境下会多分出1mb的分区的问题 
* 2.将默认桌面环境更换为gnome，现在会自动安装gnome-terminal了（如果你选择使用dde，一样会自动安装deepin-terminal）
* 3.因为现在base包中不再包含linux内核，现在脚本还将自动安装linux内核以及固件 

## The script will add a user name admin ，passwd admin123 . 
## More detail please run ./arch.sh or ./arch.sh -h

# 使用简介：
* 使用 ./arch.sh -s 来全自动安装，这样会将将所有剩余的磁盘空间分配到同一个分区中，且将根目录安装到此分区。 <br>
* 在UEFI环境下脚本会自动识别出已经存在的EFI分区，并且将grub安装到里面。<br>
* 脚本的默认桌面环境为gnome，也可以通过设置参数改为dde。（注意如果使用了-s参数其他参数都将失效，所以请根据 <br>
  下面的提示手动设置参数）<br>
  
# 参数详解：
* -d 设置安装磁盘，除sata（/dev/sd\*）外还支持nvme（/dev/nvme0n\*） <br>
     默认值为/dev/sda。
     例子： -d /dev/nvme0 或 -d /dev/sda
* -g 设置桌面环境，默认为gnome (g)，也可以设置为DDE (d) <br>
     例子：-g g 或 -g d
  
     
