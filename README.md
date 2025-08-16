# Arch-Install
## Arch linux 自动安装脚本
## 2024-02-15 更新：
* 更改 / 使用的分区格式为xfs
* archlinuxcn 源 加入参数 SigLevel = Optional TrustAll 
* 修复了一些文本输出的问题
* 修复若干小bug

## 如果不使用-u参数，脚本将自动添加用户：admin ，密码为 admin123 .
## More detail please run ./arch.sh or ./arch.sh -h

# 使用简介：
* 使用 ./arch.sh -a 来全自动安装，这样会将将所有剩余的磁盘空间分配到同一个分区中，且将根目录安装到此分区。 <br>
* 在UEFI环境下脚本会自动识别出已经存在的EFI分区，并且将grub安装到里面。<br>
* 脚本的默认桌面环境为KDE-plasma，也可以通过设置参数改为Gnome。
* 注意如果使用了-a参数其他参数 (除-u参数， 但是-u要在-a前面设置，如“./arch.sh -u 'admin:passwd' -a”) 都将失效，所以请根据下面的提示手动设置参数.<br>
  
# 参数详解：
* -d 设置安装磁盘（目标磁盘），除sata（/dev/sd\*）外还支持nvme（/dev/nvme0n\*） <br>
     在UEFI环境中，脚本将自动查找所指定的磁盘中的efi分区，否则需要在-p参数中指定一个分区作为efi分区 <br>
     默认值为/dev/sda。<br>
     例子： -d /dev/nvme0 或 -d /dev/sda <br>
* -g 设置桌面环境，默认为KDE-plasma (k)，也可以设置为Gnome (g) <br>
     例子：-g k 或 -g g <br>
* -u 自定义用户名与密码
     格式为： -u "usrname:passwd", 如果不设置此参数，默认添加用户为"admin:admin123".
* -a 自动模式
     注意如果使用了-a参数其他参数 (除-u参数， 但是-u要在-a前面设置，如“./arch.sh -u 'admin:passwd' -a”) 都将失效，所以请根据下面的提示手动设置参数.<br>
     脚本将查找所有分区，查找已经存在有efi分区的磁盘，并将目标磁盘设置为该磁盘。<br>
     如果不存在efi分区，脚本将会把系统安装到/dev/sda中，将所有的硬盘剩余空间分配到同一个分区。（请保证有足够的磁盘空间来安装系统）<br>
     注意脚本可以自动识别目标磁盘中已经存在的efi分区，并将grub安装到该分区。<br>
     自动安装的桌面环境为Kde-plasma。<br>
* -h 输出此帮助文本（脚本输出为英语）<br>
* -p 设置自动分区 <br>
     设置如何分配目标磁盘的剩余空间。如： <br>
     -p "256M,20G" 或 -p "256M,20G,FULL" <br>
     第一条参数将会分配一个256MB与20GB的磁盘，第二条除了分配这两个分区，还会把剩余的磁盘空间分到第三个分区。<br>
     M代表MB，G代表GB，FULL代表将剩余的空间塞到一个分区中，所以FULL必须是最后一个参数。<br>
* -r/--rootdisk <br>
     设置根目录（ / ）所在分区的分区号，默认为-p参数中的第二个分区。但如果-p只产生一个分区，那么该分区就是根目录所在分区 <br>
     注意，如果你提供的分区号指向一个已经存在的分区，该分区将被格式化，请保证不要将此参数设置为指向还有有用数据的分区 <br>
     例子：-r 1 或 --rootdisk 1 将会把根目录安装到分区号为1的分区中。<br>
* -b/--bootdisk <br>
     设置 efi分区所在的分区号，默认为-p参数中的第一个分区。 <br>
     与-r参数不同，该参数不会格式化指向的分区，请确保指向的分区是一个有效的efi分区 <br>
     在没有使用该参数的情况下，如果在目标磁盘中已经存在一个efi分区，该分区会被自动检测到。所以一般不推荐使用此参数 <br>
     例子：-b 1 或 --bootdisk 1 将会把 efi 分区设置为分区号1的分区。<br>
* -y <br>
     给所有pacman加上--noconfirm参数。
     
# 使用例子：
* ./arch.sh -u "admin:passwd" -a <br>
自动查找有efi分区的磁盘，并将Arch安装到其剩余的磁盘空间中。<br>
如果没有找到有efi分区的磁盘，将默认安装到/dev/sda。<br>
同时，设置新用户为admin, 密码passwd

* ./arch.sh -p "256M,FULL" <br>
将Arch安装到/dev/sda中，并且分配两个分区，一个256MB，另一个将占用剩余的未分配磁盘空间 <br>
在UEFI环境中，如果没有使用-b参数，将自动识别/dev/sda中的EFI分区，如果没有找到，自动将参数中第一个256M作为EFI分区。 <br>
在legacy环境中，将自动给启动分区加上启动标签。 <br>

* ./arch.sh -d /dev/nvme0n1 -p "256M,FULL" <br>
将Arch安装到/dev/nvme0n1中，并且分配两个分区，一个256MB，另一个将占用剩余的未分配磁盘空间 <br>
在UEFI环境中，如果没有使用-b参数，将自动识别/dev/nvme0n1中的EFI分区，如果没有找到，自动将参数中第一个256M作为EFI分区。 <br>
在legacy环境中，将自动给启动分区加上启动标签。 <br>
     
* 一次性到位安装指令，推荐先在虚拟机环境中尝试 <br>
pacman -Sy git --noconfirm && git clone https://github.com/iceshroom/Arch-Install && cd Arch-Install && chmod a+x arch.sh && ./arch.sh -a 
