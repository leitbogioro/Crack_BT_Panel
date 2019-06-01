#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
LANG=en_US.UTF-8

setuptools_Ver="41.0.1"
pillow_Ver="6.0.0"
psutil_Ver="5.6.2"
MySQL-python_Ver="1.2.5"
chardet_Ver="3.0.4"
webpy_Ver="0.39"

echo "
+----------------------------------------------------------------------
| Bt-WebPanel 5.x FOR Ubuntu/Debian
+----------------------------------------------------------------------
| Copyright © 2015-2018 BT-SOFT(http://www.bt.cn) All rights reserved.
+----------------------------------------------------------------------
| The WebPanel URL will be http://SERVER_IP:8888 when installed.
+----------------------------------------------------------------------
| This panel is modified by MollyLau
+----------------------------------------------------------------------
"
deepinSys=`cat /etc/issue`
if [[ "${deepinSys}" =~ eepin ]]; then
	isroot=''
	if [ `whoami` != "root" ];then
		isroot='sudo '
	fi
	if [ -f "/etc/init.d/bt" ]; then
		password=`${isroot}cat /www/server/panel/default.pl`
		port=`${isroot}cat /www/server/panel/data/port.pl`
		echo -e "=================================================================="
		echo -e "Bt-Panel: http://localhost:$port"
		echo -e "默认账户: admin"
		echo -e "默认密码: $password"
		echo -e "=================================================================="
		echo -e "正在尝试打开浏览器..."
		if [ -f "/opt/google/chrome/chrome" ]; then
			${isroot}/opt/google/chrome/chrome --no-sandbox http://localhost:$port
			exit;
		fi
		if [ -f "/usr/lib/firefox/firefox" ]; then
			/usr/lib/firefox/firefox http://localhost:$port
			exit;
		fi
		echo -e "找不到chrome/firefox浏览器，请自行打开浏览器访问宝塔面板: http://loshost:$port"
		exit;

	fi
fi
if [ `whoami` != "root" ];then
	echo -e "\033[31mError: Please run the script with root privileges on Ubuntu, for example: sudo bash install.sh\033[0m";
	exit;
fi

#自动选择下载节点
get_node_url(){
	nodes=(http://125.88.182.172:5880 http://103.224.251.67 http://128.1.164.196 http://download.bt.cn);
	i=1;
	if [ ! -f /bin/curl ];then
		if [ -f /usr/local/curl/bin/curl ];then
			ln -sf /usr/local/curl/bin/curl /bin/curl
		else
			yum install curl -y
		fi
	fi
	for node in ${nodes[@]};
	do
		start=`date +%s.%N`
		result=`curl -sS --connect-timeout 3 -m 60 $node/check.txt`
		if [ $result = 'True' ];then
			end=`date +%s.%N`
			start_s=`echo $start | cut -d '.' -f 1`
			start_ns=`echo $start | cut -d '.' -f 2`
			end_s=`echo $end | cut -d '.' -f 1`
			end_ns=`echo $end | cut -d '.' -f 2`
			time_micro=$(( (10#$end_s-10#$start_s)*1000000 + (10#$end_ns/1000 - 10#$start_ns/1000) ))
			time_ms=$(($time_micro/1000))
			values[$i]=$time_ms;
			urls[$time_ms]=$node
			i=$(($i+1))
		fi
	done
	j=5000
	for n in ${values[@]};
	do
		if [ $j -gt $n ];then
			j=$n
		fi
	done
	if [ $j = 5000 ];then
		NODE_URL='http://download.bt.cn';
	else
		NODE_URL=${urls[$j]}
	fi
	
}

echo '---------------------------------------------';
echo "Selected download node...";
get_node_url
download_Url=$NODE_URL
echo "Download node: $download_Url";
echo '---------------------------------------------';
setup_path=/www
port='8888'
if [ -f $setup_path/server/panel/data/port.pl ];then
	port=`cat $setup_path/server/panel/data/port.pl`
fi

startTime=`date +%s`

#数据盘自动分区
fdiskP(){
	
	for i in `cat /proc/partitions|grep -v name|grep -v ram|awk '{print $4}'|grep -v '^$'|grep -v '[0-9]$'|grep -e 'vd' -e 'sd' -e 'xv'`;
	do
		#判断/www是否被挂载
		isR=`df -P|grep $setup_path`
		if [ "$isR" != "" ];then
			echo 'Warning: The /www directory has been mounted.'
			return;
		fi
		#判断是否存在未分区磁盘
		isP=`fdisk -l /dev/$i |grep -v 'bytes'|grep "$i[1-9]*"`
		if [ "$isP" = "" ];then
				#开始分区
				fdisk -S 56 /dev/$i << EOF
n
p
1


wq
EOF

			sleep 5
			#检查是否分区成功
			checkP=`fdisk -l /dev/$i|grep "/dev/${i}1"`
			if [ "$checkP" != "" ];then
				#格式化分区
				mkfs.ext4 /dev/${i}1
				mkdir $setup_path
				#挂载分区
				sed -i "/\/dev\/${i}1/d" /etc/fstab
				echo "/dev/${i}1    $setup_path    ext4    defaults    0 0" >> /etc/fstab
				mount -a
				df -h
			fi
		else
			#判断是否存在Windows磁盘分区
			isN=`fdisk -l /dev/$i|grep -v 'bytes'|grep -v "NTFS"|grep -v "FAT32"`
			if [ "$isN" = "" ];then
				echo 'Warning: The Windows partition was detected. For your data security, Mount manually.';
				return;
			fi
			
			#挂载已有分区
			checkR=`df -P|grep "/dev/$i"`
			if [ "$checkR" = "" ];then
					mkdir $setup_path
					sed -i "/\/dev\/${i}1/d" /etc/fstab
					echo "/dev/${i}1    $setup_path    ext4    defaults    0 0" >> /etc/fstab
					mount -a
					df -h
			fi
			
			#清理不可写分区
			echo 'True' > $setup_path/checkD.pl
			if [ ! -f $setup_path/checkD.pl ];then
					sed -i "/\/dev\/${i}1/d" /etc/fstab
					mount -a
					df -h
			else
					rm -f $setup_path/checkD.pl
			fi
		fi
	done
}
#fdiskP

ln -sf bash /bin/sh
apt-get install ruby -y
apt-get update -y
apt-get install lsb-release -y
#apt-get install ntp ntpdate -y
#/etc/init.d/ntp stop
#update-rc.d ntp remove
#cat >>~/.profile<<EOF
#TZ='Asia/Shanghai'; export TZ
#EOF
#rm -rf /etc/localtime
#cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
#echo 'Synchronizing system time...'
#ntpdate 0.asia.pool.ntp.org
#apt-get upgrade -y
for pace in wget curl python python-dev python-imaging zip unzip openssl libssl-dev gcc libxml2 libxml2-dev libxslt zlib1g zlib1g-dev libjpeg-dev libpng-dev lsof libpcre3 libpcre3-dev cron;
do apt-get -y install $pace --force-yes; done
apt-get -y install python-pip python-dev

tmp=$(python -V 2>&1|awk '{print $2}')
pVersion=${tmp:0:3}

Install_setuptools()
{
	if [ ! -f "/usr/bin/easy_install" ];then
		wget -O setuptools-${setuptools_Ver}.zip https://github.com/pypa/setuptools/archive/v${setuptools_Ver}.zip -T 15
		unzip setuptools-${setuptools_Ver}.zip
		rm -f setuptools-${setuptools_Ver}.zip
		cd setuptools-${setuptools_Ver}
		python setup.py install
		cd ..
		rm -rf setuptools-${setuptools_Ver}
	fi
	
	if [ ! -f "/usr/bin/easy_install" ];then
		echo '=================================================';
		echo -e "\033[31msetuptools installation failed. \033[0m";
		exit;
	fi
}
Install_Pillow()
{
	isSetup=`python -m PIL 2>&1|grep package`
	if [ "$isSetup" = "" ];then
		wget -O Pillow-${pillow_Ver}.zip https://github.com/python-pillow/Pillow/archive/${pillow_Ver}.zip -T 15
		unzip Pillow-${pillow_Ver}.zip
		rm -f Pillow-${pillow_Ver}.zip
		cd Pillow-${pillow_Ver}
		python setup.py install
		cd ..
		rm -rf Pillow-${pillow_Ver}
	fi
	isSetup=`python -m PIL 2>&1|grep package`
	if [ "$isSetup" = "" ];then
		echo '=================================================';
		echo -e "\033[31mPillow installation failed. \033[0m";
		exit;
	fi
}

Install_psutil()
{
	isSetup=`python -m psutil 2>&1|grep package`
	if [ "$isSetup" = "" ];then
		wget -O psutil-${psutil_Ver}.tar.gz https://github.com/giampaolo/psutil/archive/release-${psutil_Ver}.tar.gz -T 15
		tar xvf psutil-${psutil_Ver}.tar.gz
		rm -f psutil-${psutil_Ver}.tar.gz pax_global_header
		cd psutil-release-${psutil_Ver}
		python setup.py install
		cd ..
		rm -rf psutil-release-${psutil_Ver}
	fi
	isSetup=`python -m psutil 2>&1|grep package`
	if [ "$isSetup" = "" ];then
		echo '=================================================';
		echo -e "\033[31mpsutil installation failed. \033[0m";
		exit;
	fi
}

Install_mysqldb()
{
	isSetup=`python -m MySQLdb 2>&1|grep package`
	if [ "$isSetup" = "" ];then
		wget -O MySQL-python-${MySQL-python_Ver}.zip https://github.com/farcepest/MySQLdb1/archive/MySQLdb-${MySQL-python_Ver}.zip -T 15
		unzip MySQL-python-${MySQL-python_Ver}.zip
		rm -f MySQL-python-${MySQL-python_Ver}.zip
		cd MySQLdb1-MySQLdb-${MySQL-python_Ver}
		python setup.py install
		cd ..
		rm -rf MySQLdb1-MySQLdb-${MySQL-python_Ver}
	fi
	
}

Install_chardet()
{
	isSetup=`python -m chardet 2>&1|grep package`
	if [ "$isSetup" = "" ];then
		wget -O chardet-${chardet_Ver}.tar.gz https://github.com/chardet/chardet/archive/${chardet_Ver}.tar.gz -T 15
		tar xvf chardet-${chardet_Ver}.tar.gz
		rm -f chardet-${chardet_Ver}.tar.gz
		cd chardet-${chardet_Ver}
		python setup.py install
		cd ..
		rm -rf chardet-${chardet_Ver} pax_global_header
	fi
	isSetup=`python -m chardet 2>&1|grep package`
	if [ "$isSetup" = "" ];then
		echo '=================================================';
		echo -e "\033[31mchardet installation failed. \033[0m";
		exit;
	fi
}

Install_webpy()
{
	isSetup=`python -m web 2>&1|grep package`
	if [ "$isSetup" = "" ];then
		wget -O webpy-${webpy_Ver}.tar.gz https://github.com/webpy/webpy/archive/webpy-${webpy_Ver}.tar.gz -T 10
		tar xvf webpy-${webpy_Ver}.tar.gz
		rm -f webpy-${webpy_Ver}.tar.gz
		cd webpy-webpy-${webpy_Ver}
		python setup.py install
		cd ..
		rm -rf webpy-webpy-${webpy_Ver} pax_global_header
	fi
	
	isSetup=`python -m web 2>&1|grep package`
	if [ "$isSetup" = "" ];then
		echo '=================================================';
		echo -e "\033[31mweb.py installation failed. \033[0m";
		exit;
	fi
}
pipArg=''


pip install setuptools
#pip install --upgrade pip $pipArg
pip install psutil chardet web.py virtualenv Pillow $pipArg


Install_Pillow
Install_psutil
if [  -f /www/server/mysql/bin/mysql ]; then
	pip install mysql-python
	Install_mysqldb
fi
Install_chardet
Install_webpy

mkdir -p $setup_path/server/panel/logs
mkdir -p $setup_path/server/panel/vhost/apache
mkdir -p $setup_path/server/panel/vhost/nginx
mkdir -p $setup_path/server/panel/vhost/rewrite
wget -O $setup_path/server/panel/certbot-auto https://git.io/fj0zs -T 15
chmod +x $setup_path/server/panel/certbot-auto


if [ -f '/etc/init.d/bt' ];then
	/etc/init.d/bt stop
fi

mkdir -p /www/server
mkdir -p /www/wwwroot
mkdir -p /www/wwwlogs
mkdir -p /www/backup/database
mkdir -p /www/backup/site

wget -O panel.zip https://git.io/fj0zZ -T 15
wget -O /etc/init.d/bt https://git.io/fj0zc -T 15
if [ -f "$setup_path/server/panel/data/default.db" ];then
	if [ -d "/$setup_path/server/panel/old_data" ];then
		rm -rf $setup_path/server/panel/old_data
	fi
	mkdir -p $setup_path/server/panel/old_data
	mv -f $setup_path/server/panel/data/default.db $setup_path/server/panel/old_data/default.db
	mv -f $setup_path/server/panel/data/system.db $setup_path/server/panel/old_data/system.db
	mv -f $setup_path/server/panel/data/aliossAs.conf $setup_path/server/panel/old_data/aliossAs.conf
	mv -f $setup_path/server/panel/data/qiniuAs.conf $setup_path/server/panel/old_data/qiniuAs.conf
	mv -f $setup_path/server/panel/data/iplist.txt $setup_path/server/panel/old_data/iplist.txt
	mv -f $setup_path/server/panel/data/port.pl $setup_path/server/panel/old_data/port.pl
fi

unzip -o panel.zip -d $setup_path/server/ > /dev/null

if [ -d "$setup_path/server/panel/old_data" ];then
	mv -f $setup_path/server/panel/old_data/default.db $setup_path/server/panel/data/default.db
	mv -f $setup_path/server/panel/old_data/system.db $setup_path/server/panel/data/system.db
	mv -f $setup_path/server/panel/old_data/aliossAs.conf $setup_path/server/panel/data/aliossAs.conf
	mv -f $setup_path/server/panel/old_data/qiniuAs.conf $setup_path/server/panel/data/qiniuAs.conf
	mv -f $setup_path/server/panel/old_data/iplist.txt $setup_path/server/panel/data/iplist.txt
	mv -f $setup_path/server/panel/old_data/port.pl $setup_path/server/panel/data/port.pl
	
	if [ -d "/$setup_path/server/panel/old_data" ];then
		rm -rf $setup_path/server/panel/old_data
	fi
fi

rm -f panel.zip

if [ ! -f $setup_path/server/panel/tools.py ];then
	echo -e "\033[31mERROR: Failed to download, please try again!\033[0m";
	echo '============================================'
	exit;
fi

rm -f $setup_path/server/panel/class/*.pyc
rm -f $setup_path/server/panel/*.pyc
python -m compileall $setup_path/server/panel
#rm -f $setup_path/server/panel/class/*.py
#rm -f $setup_path/server/panel/*.py

chmod 777 /tmp
chmod +x /etc/init.d/bt
update-rc.d bt defaults
chmod -R 600 $setup_path/server/panel
chmod +x $setup_path/server/panel/certbot-auto
chmod -R +x $setup_path/server/panel/script
echo "$port" > $setup_path/server/panel/data/port.pl
/etc/init.d/bt start
password=`cat /dev/urandom | head -n 16 | md5sum | head -c 8`
cd $setup_path/server/panel/
python tools.py username
username=`python tools.pyc panel $password`
cd ~
echo "$password" > $setup_path/server/panel/default.pl
chmod 600 $setup_path/server/panel/default.pl

isStart=`ps aux |grep 'python main.pyc'|grep -v grep|awk '{print $2}'`
if [ "$isStart" == '' ];then
	echo -e "\033[31mERROR: The BT-Panel service startup failed.\033[0m";
	echo '============================================'
	exit;
fi

if [ ! -f "/usr/bin/ufw" ];then
	apt-get install -y ufw
fi

if [ -f "/usr/sbin/ufw" ];then
	ufw allow 888,20,21,22,80,$port/tcp
	ufw allow 39000:40000/tcp
	ufw_status=`ufw status`
	echo y|ufw enable
	ufw default deny
	ufw reload
fi

pip install psutil chardet web.py psutil virtualenv $pipArg
if [ ! -d '/etc/letsencrypt' ];then

	mkdir -p /var/spool/cron
	if [ ! -f '/var/spool/cron/crontabs/root' ];then
		echo '' > /var/spool/cron/crontabs/root
		chmod 600 /var/spool/cron/crontabs/root
	fi
	isCron=`cat /var/spool/cron/crontabs/root|grep certbot.log`
	if [ "${isCron}" == "" ];then
		echo "30 2 * * * $setup_path/server/panel/certbot-auto renew >> $setup_path/server/panel/logs/certbot.log" >>  /var/spool/cron/crontabs/root
		chown 600 /var/spool/cron/crontabs/root
	fi
	service cron restart
	nohup $setup_path/server/panel/certbot-auto -n > /tmp/certbot-auto.log 2>&1 &
fi
if [[ "${deepinSys}" =~ eepin ]]; then
	address="localhost"
else
	address=`curl -sS --connect-timeout 10 -m 60 https://www.bt.cn/Api/getIpAddress`
	
	if [ "$address" == '0.0.0.0' ] || [ "$address" == '' ];then
		isHosts=`cat /etc/hosts|grep 'www.bt.cn'`
		if [ "$isHosts" == '' ];then
			echo "" >> /etc/hosts
			echo "125.88.182.170 www.bt.cn" >> /etc/hosts
			address=`curl -sS --connect-timeout 10 -m 60 https://www.bt.cn/Api/getIpAddress`
			if [ "$address" == '' ];then
				sed -i "/bt.cn/d" /etc/hosts
			fi
		fi
	fi
	
	ipCheck=`python -c "import re; print re.match('^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$','$address')"`
	if [ "$address" == "None" ];then
		address="SERVER_IP"
	fi
	if [ "$address" != "SERVER_IP" ];then
		echo "$address" > $setup_path/server/panel/data/iplist.txt
	fi
fi

curl -sS --connect-timeout 10 -m 60 https://www.bt.cn/Api/SetupCount?type=Linux\&o=$1 > /dev/null 2>&1
if [ $1 != "" ];then
	echo $1 > /www/server/panel/data/o.pl
	cd /www/server/panel
	python tools.py o
fi

echo -e "=================================================================="
echo -e "\033[32mCongratulations! Install succeeded!\033[0m"
echo -e "=================================================================="
echo -e "Bt-Panel: http://$address:$port"
echo -e "username: $username"
echo -e "password: $password"
echo -e "\033[33mWarning:\033[0m"
echo -e "\033[33mIf you cannot access the panel, \033[0m"
echo -e "\033[33mrelease the following port (8888|888|80|443|20|21) in the security group\033[0m"
echo -e "=================================================================="

endTime=`date +%s`
((outTime=($endTime-$startTime)/60))
echo -e "Time consumed:\033[32m $outTime \033[0mMinute!"
rm -f install.sh
