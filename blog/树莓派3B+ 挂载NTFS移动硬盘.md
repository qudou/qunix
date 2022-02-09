1、下载ntfs-3g，此软件支持读写，普通挂载只能读，不能写

sudo apt-get install ntfs-3g

2、插入移动硬盘，查看是否检测到硬盘

sudo fdisk -l

3 查看硬盘是否挂载

df -h

4 挂载，a代表硬盘,1代表第一个分区

mount -t ntfs-3g /dev/sda1 /home/pi/disk1

5 查看是否挂载成功

df -h