#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

public_file=/www/server/panel/install/public.sh
publicFileMd5=$(md5sum ${public_file} 2>/dev/null|awk '{print $1}')
md5check="a70364b7ce521005e7023301e26143c5"
if [ "${publicFileMd5}" != "${md5check}"  ]; then
	wget -O Tpublic.sh http://download.bt.cn/install/public.sh -T 20;
	publicFileMd5=$(md5sum Tpublic.sh 2>/dev/null|awk '{print $1}')
	if [ "${publicFileMd5}" == "${md5check}"  ]; then
		\cp -rpa Tpublic.sh $public_file
	fi
	rm -f Tpublic.sh
fi
. $public_file

download_Url=$NODE_URL

Root_Path=`cat /var/bt_setupPath.conf`
Setup_Path=$Root_Path/server/php
php_path=$Root_Path/server/php
mysql_dir=$Root_Path/server/mysql
mysql_config="${mysql_dir}/bin/mysql_config"
Is_64bit=`getconf LONG_BIT`
run_path='/root'
apacheVersion=`cat /var/bt_apacheVersion.pl`

php_52="5.2.17"
php_53="5.3.29"
php_54="5.4.45"
php_55='5.5.38'
php_56='5.6.40'
php_70='7.0.33'
php_71='7.1.33'
php_72='7.2.33'
php_73='7.3.28'
php_74='7.4.20'
php_80='8.0.7'
opensslVersion="1.0.2u"
openssl111Version="1.1.1k"
nghttp2Version="1.42.0"
curlVersion="7.77.0"
libsodiumVer="1.0.18"

if [ "$2" == "5.2" ] || [ "${apacheVersion}" == "2.2" ];then
	wget -O php.sh $download_Url/install/0/old/php.sh -T 5
	bash php.sh $1 $2
	exit;
fi

if [ -z "${cpuCore}" ]; then
	cpuCore="1"
fi

#if [ ! -f "/etc/bt_lib.lock" ];then
#	wget -O lib.sh $download_Url/install/0/lib.sh
#	bash lib.sh
#	rm -f lib.sh
#fi

Error_Msg(){
	if [ "${actionType}" == "install" ];then
		AC_TYPE="安装"
	elif [ "${actionType}" == "update" ]; then
		AC_TYPE="升级"
	fi

	EN_CHECK=$(cat /www/server/panel/config/config.json |grep English)
	echo '========================================================'
	GetSysInfo
	echo -e "ERROR: php-${phpVersion} ${actionType} failed.";
	if [ "${EN_CHECK}" ];then
		echo -e "Please submit to https://forum.aapanel.com for help"
	else 
		echo -e "${AC_TYPE}失败，请截图以上报错信息发帖至论坛www.bt.cn/bbs求助"
	fi
	exit 1;
}

System_Lib(){
	if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ] ; then
		Centos8Check=$(cat /etc/redhat-release|grep ' 8.'|grep -i centos)
		CentosStream8Check=$(cat /etc/redhat-release |grep -i "Centos Stream"|grep 8)
		if [ "${Centos8Check}" ] || [ "${CentosStream8Check}" ];then
			yum config-manager --set-enabled PowerTools
			yum config-manager --set-enabled powertools
		fi
		Pack="gcc gcc-c++ libsodium-devel sqlite-devel oniguruma-devel libwebp-devel libvpx-devel openssl-devel"
	elif [ "${PM}" == "apt-get" ]; then
		Pack="gcc g++ libsodium-dev libonig-dev libsqlite3-dev libcurl4-openssl-dev libwebp-dev libvpx-dev"
	fi
	${PM} install ${Pack} -y
}

Service_Add(){
	\cp ${php_setup_path}/src/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm-${php_version}
	sed -i "s/# Provides:          php-fpm/# Provides:          php-fpm-"${php_version}"/g" /etc/init.d/php-fpm-${php_version}
	chmod +x /etc/init.d/php-fpm-${php_version}
	if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ]; then
		chkconfig --add php-fpm-${php_version}
		chkconfig --level 2345 php-fpm-${php_version} on

	elif [ "${PM}" == "apt-get" ]; then
		update-rc.d php-fpm-${php_version} defaults
	fi

	/etc/init.d/php-fpm-${php_version} start 
}

Service_Del(){
	if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ]; then
		chkconfig --del php-fpm-${php_version}
		chkconfig --level 2345 php-fpm-${php_version} off
	elif [ "${PM}" == "apt-get" ]; then
		update-rc.d php-fpm-${php_version} remove
	fi
	rm -f /etc/init.d/php-fpm-$php_version
}

Configure_Get(){
	name="php"
	i_path=/www/server/panel/install/$name

	i_args=$(cat $i_path/config.pl|xargs)
	i_make_args=""
	for i_name in $i_args
	do
		init_file=$i_path/$i_name/init.sh
		if [ -f $init_file ];then
			bash $init_file
		fi
		args_file=$i_path/$i_name/args.pl
		if [ -f $args_file ];then
			args_string=$(cat $args_file)
			i_make_args="$i_make_args $args_string"
		fi
	done
}

Install_Openssl_1_0_2()
{
	if [ ! -f "/usr/local/openssl/bin/openssl" ];then
		cd ${run_path}
		wget ${download_Url}/src/openssl-${opensslVersion}.tar.gz
		tar -zxf openssl-${opensslVersion}.tar.gz
		cd openssl-${opensslVersion}
		./config --openssldir=/usr/local/openssl zlib-dynamic shared
		make -j${cpuCore} 
		make install
		echo  "/usr/local/openssl/lib" > /etc/ld.so.conf.d/zopenssl.conf
		ldconfig
		cd ..
		rm -f openssl-${opensslVersion}.tar.gz
		rm -rf openssl-${opensslVersion}
	fi
}

Install_Openssl_1_1_1(){
	openssl111Check=$(openssl version |grep 1.1.1)
	if [ ! -f "/usr/local/openssl111/bin/openssl" ] && [ -z "${openssl111Check}" ];then
		cd ${run_path}
		wget https://www.openssl.org/source/openssl-${openssl111Version}.tar.gz -T 20
		tar -zxf openssl-${openssl111Version}.tar.gz
		rm -f openssl-${openssl111Version}.tar.gz
		cd openssl-${openssl111Version}
		./config --prefix=/usr/local/openssl111 --openssldir=/usr/local/openssl111 enable-md2 enable-rc5 sctp zlib-dynamic shared -fPIC
		make -j${cpuCore}
		make install
		[ $? -ne 0 ] && Error_Msg
		echo "/usr/local/openssl111/lib" >> /etc/ld.so.conf.d/zopenssl111.conf
		ldconfig
		cd ..
		rm -rf openssl-${openssl111Version} 
	fi
}
Install_Curl()
{
	if [ "${PM}" == "yum" ];then
		CURL_OPENSSL_LIB_VERSION=$(/usr/local/curl/bin/curl -V|grep -oE OpenSSL.*[0-9][a-z]|cut -f 2 -d "/")
		OPENSSL_LIB_VERSION=$(/usr/local/openssl/bin/openssl version|awk '{print $2}')
	fi
	if [ ! -f "/usr/local/curl/bin/curl" ] || [ "${CURL_OPENSSL_LIB_VERSION}" != "${OPENSSL_LIB_VERSION}" ];then
		wget https://curl.haxx.se/download/curl-${curlVersion}.tar.gz -T 20
		tar -zxf curl-${curlVersion}.tar.gz
		cd curl-${curlVersion}
		rm -rf /usr/local/curl	
		./configure --prefix=/usr/local/curl --enable-ares --without-nss --with-ssl=/usr/local/openssl
		make -j${cpuCore}
		make install
		cd ..
		rm -f curl-${curlVersion}.tar.gz
		rm -rf curl-${curlVersion}
	fi
}

Install_Curl_New(){
	if [ ! -f "/usr/local/curl_2/bin/curl" ];then
		wget https://curl.haxx.se/download/curl-${curlVersion}.tar.gz -T 20
		tar -zxf curl-${curlVersion}.tar.gz
		cd curl-${curlVersion}
		rm -rf /usr/local/curl_2
		./configure --prefix=/usr/local/curl_2 --enable-ldap --enable-ldaps --with-brotli --with-libssh2 --with-libssh --enable-ares --with-gssapi --without-nss --enable-smb --with-libidn2 --with-ssl=/usr/local/openssl111
		[ $? -ne 0 ] && Error_Msg
		make -j${cpuCore}
		make install
		cd ..
		rm -f curl-${curlVersion}.tar.gz
		rm -rf curl-${curlVersion}
	fi
}

Install_Curl2(){
	LibCurlVer=$(/usr/local/curl/bin/curl -V|grep curl|awk '{print $2}'|cut -d. -f2)
	if [[ "${LibCurlVer}" -le "60" ]]; then
		if [ ! -f "/usr/local/curl2/bin/curl" ];then
			curlVer="7.64.1"
			wget ${download_Url}/src/curl-${curlVer}.tar.gz
			tar -xvf curl-${curlVer}.tar.gz
			cd curl-${curlVer}
			./configure --prefix=/usr/local/curl2 --enable-ares --without-nss --with-ssl=/usr/local/openssl
			make -j${cpuCore}
			make install
			cd ..
			rm -rf curl*
		fi
	fi
}

Install_Icu4c(){
	cd ${run_path}
	icu4cVer=$(/usr/bin/icu-config --version)
	if [ ! -f "/usr/bin/icu-config" ] || [ "${icu4cVer:0:2}" -gt "60" ];then
		wget -O icu4c-60_3-src.tgz ${download_Url}/src/icu4c-60_3-src.tgz
		tar -xvf icu4c-60_3-src.tgz
		cd icu/source
		./configure --prefix=/usr/local/icu
		make -j${cpuCore}
		make install
		[ -f "/usr/bin/icu-config" ] && mv /usr/bin/icu-config /usr/bin/icu-config.bak 
		ln -sf /usr/local/icu/bin/icu-config /usr/bin/icu-config
		echo "/usr/local/icu/lib" > /etc/ld.so.conf.d/zicu.conf
		ldconfig
		cd ../../
		rm -rf icu
		rm -f icu4c-60_3-src.tgz 
	fi
}
Install_Libzip(){
	if [ "${PM}" == "yum" ];then
		el=$(cat /etc/redhat-release|grep -iE 'CentOS|Red Hat'|grep -Eo '([0-9]+\.)+[0-9]+'|grep -Eo '^[0-9]')
		if [ "${el}" == "7" ];then
			rpm -q libzip5-devel > /dev/null
			if [ "$?" -ne "0" ];then
				mkdir libzip
				cd libzip
				wget -O libzip5-1.5.2.rpm ${download_Url}/rpm/remi/${el}/libzip5-1.5.2.rpm
				wget -O libzip5-devel-1.5.2.rpm ${download_Url}/rpm/remi/${el}/libzip5-devel-1.5.2.rpm
				wget -O libzip5-tools-1.5.2.rpm ${download_Url}/rpm/remi/${el}/libzip5-tools-1.5.2.rpm
				yum install * -y
				cd ..
				rm -rf libzip
			fi
		else
			libzipVerCheck=$(yum list libzip|grep libzip|awk 'NR==1 {printf("%d",$2)}')
			if [ "${libzipVerCheck}" -ge "1" ];then
				yum install -y libzip-devel
			fi
		fi
	elif [ "${PM}" == "apt-get" ];then
		apt-get install libzip-dev -y
	fi
	autoconfVer=$(autoconf -V|grep 'GNU Autoconf'|awk '{print $4}'|grep -oE .[0-9]+|grep -oE [0-9]+)
	if [ "${autoconfVer}" -lt "69" ]; then
		wget ${download_Url}/src/autoconf-2.69.tar.gz
		tar -xvf autoconf-2.69.tar.gz
		cd autoconf-2.69
		./configure --prefix=/usr
		make && make install
		cd ..
		rm -rf autoconf*
	fi

}
Install_Onig(){
	onigCheck=$(pkg-config --list-all|grep onig)
	if [ -z "${onigCheck}" ];then
		cd ${run_path}
		onigVer="6.9.6"
		wget -O onig-${onigVer}.tar.gz ${download_Url}/src/onig-${onigVer}.tar.gz
		tar  -xvf onig-${onigVer}.tar.gz
		cd onig-${onigVer}
		./configure --prefix=/usr/local/onig
		make -j${cpuCore}
		make install
		cd ..
		rm -rf onig-${onigVer}*
	fi
}
Install_Libsodium(){
	if [ ! -f "/usr/local/libsodium/lib/libsodium.so" ];then
		cd ${run_path}
		wget https://download.libsodium.org/libsodium/releases/libsodium-${libsodiumVer}.tar.gz -T 20
		tar -xvf libsodium-${libsodiumVer}.tar.gz
		rm -f libsodium-${libsodiumVer}.tar.gz
		cd libsodium-${libsodiumVer}
		./configure --prefix=/usr/local/libsodium
		make -j${cpuCore}
		make install
		cd ..
		rm -f libsodium-${libsodiumVer}.tar.gz
		rm -rf libsodium-stable
	fi
	if [ "${php_version}" == "73" ];then
		if [ "${PM}" == "apt-get" ]; then
			GET_LIBSODIUM_VER=$(dpkg -l |grep libsodium-dev|awk '{print $3}'|cut -d '.' -f3|cut -d '-' -f1)
			if [ "${GET_LIBSODIUM_VER}" -lt "15" ];then
				apt-get remove -y libsodium-dev
			fi
		fi
	fi
}

Create_Fpm(){
	cat >${php_setup_path}/etc/php-fpm.conf<<EOF
[global]
pid = ${php_setup_path}/var/run/php-fpm.pid
error_log = ${php_setup_path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi-${php_version}.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
user = www
group = www
pm = dynamic
pm.status_path = /phpfpm_${php_version}_status
pm.max_children = 30
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 10
request_terminate_timeout = 100
request_slowlog_timeout = 30
slowlog = var/log/slow.log
EOF
}

Set_PHP_FPM_Opt()
{
	MemTotal=`free -m | grep Mem | awk '{print  $2}'`
	if [[ ${MemTotal} -gt 1024 && ${MemTotal} -le 2048 ]]; then
		sed -i "s#pm.max_children.*#pm.max_children = 50#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.start_servers.*#pm.start_servers = 5#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 5#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 10#" ${php_setup_path}/etc/php-fpm.conf
	elif [[ ${MemTotal} -gt 2048 && ${MemTotal} -le 4096 ]]; then
		sed -i "s#pm.max_children.*#pm.max_children = 80#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.start_servers.*#pm.start_servers = 5#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 5#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 20#" ${php_setup_path}/etc/php-fpm.conf
	elif [[ ${MemTotal} -gt 4096 && ${MemTotal} -le 8192 ]]; then
		sed -i "s#pm.max_children.*#pm.max_children = 150#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.start_servers.*#pm.start_servers = 10#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 10#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 30#" ${php_setup_path}/etc/php-fpm.conf
	elif [[ ${MemTotal} -gt 8192 && ${MemTotal} -le 16384 ]]; then
		sed -i "s#pm.max_children.*#pm.max_children = 200#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.start_servers.*#pm.start_servers = 15#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 15#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 30#" ${php_setup_path}/etc/php-fpm.conf
	elif [[ ${MemTotal} -gt 16384 ]]; then
		sed -i "s#pm.max_children.*#pm.max_children = 300#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.start_servers.*#pm.start_servers = 20#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 20#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 50#" ${php_setup_path}/etc/php-fpm.conf
	fi
	#backLogValue=$(cat ${php_setup_path}/etc/php-fpm.conf |grep max_children|awk '{print $3*1.5}')
	#sed -i "s#listen.backlog.*#listen.backlog = "${backLogValue}"#" ${php_setup_path}/etc/php-fpm.conf	
	sed -i "s#listen.backlog.*#listen.backlog = 8192#" ${php_setup_path}/etc/php-fpm.conf
}

Set_Phpini(){

	sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${php_setup_path}/etc/php.ini
	sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${php_setup_path}/etc/php.ini
	sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${php_setup_path}/etc/php.ini
	sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${php_setup_path}/etc/php.ini
	sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=1/g' ${php_setup_path}/etc/php.ini
	sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${php_setup_path}/etc/php.ini
	sed -i 's/;sendmail_path =.*/sendmail_path = \/usr\/sbin\/sendmail -t -i/g' ${php_setup_path}/etc/php.ini
	sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,putenv,chroot,chgrp,chown,shell_exec,popen,proc_open,pcntl_exec,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,imap_open,apache_setenv/g' ${php_setup_path}/etc/php.ini
	sed -i 's/display_errors = Off/display_errors = On/g' ${php_setup_path}/etc/php.ini
	sed -i 's/error_reporting =.*/error_reporting = E_ALL \& \~E_NOTICE/g' ${php_setup_path}/etc/php.ini

	if [ "${php_version}" = "52" ]; then
		sed -i "s#extension_dir = \"./\"#extension_dir = \"${php_setup_path}/lib/php/extensions/no-debug-non-zts-20060613/\"\n#" ${php_setup_path}/etc/php.ini
		sed -i 's#output_buffering =.*#output_buffering = On#' ${php_setup_path}/etc/php.ini
		sed -i 's/; cgi.force_redirect = 1/cgi.force_redirect = 0;/g' ${php_setup_path}/etc/php.ini
		sed -i 's/; cgi.redirect_status_env = ;/cgi.redirect_status_env = "yes";/g' ${php_setup_path}/etc/php.ini
	fi

	if [ "${php_version}" -ge "56" ]; then
		if [ -f "/etc/pki/tls/certs/ca-bundle.crt" ];then
			crtPath="/etc/pki/tls/certs/ca-bundle.crt"
		elif [ -f "/etc/ssl/certs/ca-certificates.crt" ]; then
			crtPath="/etc/ssl/certs/ca-certificates.crt"
		fi
		sed -i "s#;openssl.cafile=#openssl.cafile=${crtPath}#" ${php_setup_path}/etc/php.ini
		sed -i "s#;curl.cainfo =#curl.cainfo = ${crtPath}#" ${php_setup_path}/etc/php.ini
	fi

	sed -i 's/expose_php = On/expose_php = Off/g' ${php_setup_path}/etc/php.ini
	
}

Ln_PHP_Bin()
{
	rm -f /usr/bin/php*
	rm -f /usr/bin/pear
	rm -f /usr/bin/pecl

    ln -sf ${php_setup_path}/bin/php /usr/bin/php
    ln -sf ${php_setup_path}/bin/phpize /usr/bin/phpize
    ln -sf ${php_setup_path}/bin/pear /usr/bin/pear
    ln -sf ${php_setup_path}/bin/pecl /usr/bin/pecl
    ln -sf ${php_setup_path}/sbin/php-fpm /usr/bin/php-fpm
}

Pear_Pecl_Set()
{
 	if [ "${php_version}" -le "73" ];then
		pear config-set php_ini ${php_setup_path}/etc/php.ini
		pecl config-set php_ini ${php_setup_path}/etc/php.ini
	fi
}

Install_Composer()
{
	if [ ! -f "/usr/bin/composer" ];then
		wget -O /usr/bin/composer ${download_Url}/install/src/composer.phar -T 20;
		chmod +x /usr/bin/composer
		if [ "${download_Url}" == "http://$CN:5880" ];then
			composer config -g repo.packagist composer https://packagist.phpcomposer.com
		fi
	fi
}

Download_Src(){
	php_setup_path="/www/server/php/${php_version}"
	mkdir -p ${php_setup_path}
	if [ "${actionType}" == "install" ];then
		/etc/init.d/php-fpm-$php_version stop
		rm -rf ${php_setup_path}/*
	fi
	
	cd ${php_setup_path}
	rm -rf ${php_setup_path}/src

	wget -O src.tar.gz https://www.php.net/distributions/php-${phpVersion}.tar.gz -T 20
	tar -xvf src.tar.gz
	mv php-${phpVersion} src

	if [ "${php_version}" == "53" ];then
		rm -rf /patch
		mkdir -p /patch
		cd src
		wget -O /patch/php-5.3-multipart-form-data.patch ${download_Url}/src/patch/php-5.3-multipart-form-data.patch -T20
		patch -p1 < /patch/php-5.3-multipart-form-data.patch
	fi
}

Install_Configure(){
	aarch64Check=$(uname -a|grep aarch64)
	if [ "${aarch64Check}" ];then
		CONFIGURE_BUILD_TYPE="--build=arm-linux"
	fi

	if [ "${php_version}" -ge "73" ];then
		Install_Libzip
		Install_Onig
		Install_Libsodium
		Install_Curl2
		if [ -f "/usr/local/curl2/bin/curl" ]; then
			withCurl="/usr/local/curl2"
		else
			withCurl="/usr/local/curl"
		fi

		if [ -f "/usr/local/openssl111/bin/openssl" ];then
			 curlOpensslLIB=$(/usr/local/curl/bin/curl -V|grep -oE OpenSSL/1.1.1[a-Z]|cut -d '/' -f 2)
			 opensslVersion=$(/usr/local/openssl111/bin/openssl version|awk '{print $2}')
			 if [ "${curlOpensslLIB}" == "${opensslVersion}" ];then
			 	withOpenssl="/usr/local/openssl111"
			 else
			 	withOpenssl="/usr/local/openssl"
			 fi
		else
			withOpenssl="/usr/local/openssl"
		fi

		if [ "${php_version}" = "80" ];then
			opensslCheck=$(openssl version |grep 1.1.1)
			if [ -z "${opensslCheck}" ]; then
				if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ] ; then
					yum install lksctp-tools-devel brotli-devel libssh2-devel -y
				elif [ "${PM}" == "apt-get" ]; then
					apt-get install libsctp-dev libbrotli-dev libssh2-1-dev -y
				fi
				Install_Openssl_1_1_1
				Install_Curl_New
				withOpenssl="/usr/local/openssl111"
				withCurl="/usr/local/curl_2"
			else
				withOpenssl=""
				withCurl=""
			fi
		fi
	fi

	cd ${php_setup_path}/src
	if [ "${php_version}" == "53" ]; then
		./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-magic-quotes --enable-safe-mode --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --disable-fileinfo ${CONFIGURE_BUILD_TYPE} ${i_make_args}
	elif [ "${php_version}" -le "56" ];then
		[ "${php_version}" -gt "54" ] && ENABLE_OPCACHE="--enable-opcache" ENABLE_WEBP="--with-vpx-dir"
		./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --disable-fileinfo --enable-intl ${ENABLE_WEBP} ${ENABLE_OPCACHE} ${CONFIGURE_BUILD_TYPE} ${i_make_args}
	elif [ "${php_version}" -le "72" ]; then
		[ "${php_version}" -ge "72" ] && ENABLE_MCRYPT="--with-mcrypt"
		./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --disable-fileinfo --enable-opcache --with-webp-dir=/usr ${ENABLE_MCRYPT} ${i_make_args}
	elif [ "${php_version}" == "73" ]; then
		./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=${withCurl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd --with-openssl=${withOpenssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc  --enable-soap --with-gettext --disable-fileinfo --enable-opcache --with-sodium=/usr/local/libsodium --with-webp-dir=/usr ${i_make_args}
	elif [ "${php_version}" == "74" ] || [ "${php_version}" == "80" ]; then
		ALI_OS=$(cat /etc/redhat-release |grep "Alibaba Cloud Linux release 3")
		if [ -z "${onigCheck}" ] || [ "${ALI_OS}" ];then
			export PKG_CONFIG_PATH="/usr/local/onig/lib/pkgconfig:/usr/local/libsodium/lib/pkgconfig:$PKG_CONFIG_PATH"
		fi

		if [  "${withOpenssl}" ];then
			export CFLAGS="-I${withOpenssl}/include -I${withCurl}/include"
			export LIBS="-L${withOpenssl}/lib -L${withCurl}/lib"
		fi

		./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype --with-jpeg --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd --with-openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc  --enable-soap --with-gettext --disable-fileinfo --enable-opcache --with-sodium=/usr/local/libsodium --with-webp ${i_make_args}
	fi

	if [ "${Is_64bit}" = "32" ];then
		sed -i 's/lcrypt$/lcrypt -lresolv/' Makefile
	fi

	make ZEND_EXTRA_LIBS='-liconv' -j${cpuCore}
}

Install_PHP(){
	if [ "${actionType}" == "update" ]; then
		/etc/init.d/php-fpm-${php_version} stop
		sleep 2
		make install
		[ $? -ne 0 ] && Error_Msg
		sleep 1
		/etc/init.d/php-fpm-${php_version} start
		echo "${phpVersion}" > ${php_setup_path}/version.pl
		rm -f ${php_setup_path}/version_check.pl
		rm -f ${Setup_Path}/src.tar.gz 
		rm -rf ${php_setup_path}/src/Zend 
		exit 0;
	fi
	make install

	[ ! -f "${php_setup_path}/bin/php" ] && Error_Msg
	
	mkdir -p ${php_setup_path}/etc
	\cp php.ini-production ${php_setup_path}/etc/php.ini
}

Install_Zip_ext(){
	cd ${php_setup_path}/src/ext/zip
	${php_setup_path}/bin/phpize
	./configure --with-php-config=${php_setup_path}/bin/php-config
	make && make install
	cd ../../

	if [ "${php_version}" == "73" ];then
		extFile="/www/server/php/73/lib/php/extensions/no-debug-non-zts-20180731/zip.so"
	elif [ "${php_version}" == "74" ]; then
		extFile="/www/server/php/74/lib/php/extensions/no-debug-non-zts-20190902/zip.so"
	elif [ "${php_version}" == "80" ]; then
		extFile="/www/server/php/80/lib/php/extensions/no-debug-non-zts-20200930/zip.so"
	fi

	if [ -f "${extFile}" ];then
		echo "extension = zip.so" >> ${php_setup_path}/etc/php.ini
	fi
}

Install_Zend(){
	mkdir -p /usr/local/zend/php${php_version}
	if [ "${php_version}" -lt "70" ];then
		echo "Install ZendGuardLoader for PHP ${version}"
		echo "unavailable now."
		echo "Write ZendGuardLoader to php.ini..."
		wget -O php-ZendGuardLoader.tar.gz ${download_Url}/src/php-ZendGuardLoader.tar.gz
		tar -xvf php-ZendGuardLoader.tar.gz > /dev/null
		mv zend/ZendGuardLoader-${php_version}-${Is_64bit}.so /usr/local/zend/php${php_version}/ZendGuardLoader.so
		rm -f php-ZendGuardLoader.tar.gz
		rm -rf zend
			cat >>${php_setup_path}/etc/php.ini<<EOF
;eaccelerator

;ionCube

;opcache

[Zend ZendGuard Loader]
zend_extension=/usr/local/zend/php${php_version}/ZendGuardLoader.so
zend_loader.enable=1
zend_loader.disable_licensing=0
zend_loader.obfuscation_level_support=3
zend_loader.license_path=

;xcache
EOF
	else
		echo ";ionCube" >> ${php_setup_path}/etc/php.ini
		echo ";opcache" >> ${php_setup_path}/etc/php.ini
	fi
}

Download_Conf(){
	if [ ! -f "/www/server/nginx/conf/enable-php-${php_version}.conf" ];then
		wget -O /www/server/nginx/conf/enable-php-${php_version}.conf ${download_Url}/conf/enable-php-${php_version}.conf
	fi
}

SetPHPMyAdmin()
{
	if [ -f "/www/server/nginx/sbin/nginx" ]; then
		webserver="nginx"
	fi
	PHPVersion=""
	for phpV in 52 53 54 55 56 70 71 72 73 74 80
	do
		if [ -f "/www/server/php/${phpV}/bin/php" ]; then
			PHPVersion=${phpV}
		fi
	done

	[ -z "${PHPVersion}" ] && PHPVersion="00"
	if [ "${webserver}" == "nginx" ];then
		sed -i "s#$Root_Path/wwwroot/default#$Root_Path/server/phpmyadmin#" $Root_Path/server/nginx/conf/nginx.conf
		rm -f $Root_Path/server/nginx/conf/enable-php.conf
		\cp $Root_Path/server/nginx/conf/enable-php-$PHPVersion.conf $Root_Path/server/nginx/conf/enable-php.conf
		sed -i "/pathinfo/d" $Root_Path/server/nginx/conf/enable-php.conf
		/etc/init.d/nginx reload
	else
		sed -i "s#$Root_Path/wwwroot/default#$Root_Path/server/phpmyadmin#" $Root_Path/server/apache/conf/extra/httpd-vhosts.conf
		sed -i "0,/php-cgi/ s/php-cgi-\w*\.sock/php-cgi-${PHPVersion}.sock/" $Root_Path/server/apache/conf/extra/httpd-vhosts.conf
		/etc/init.d/httpd reload
	fi
}
Remove_Src(){
	cd ${php_setup_path}/src
	ls |grep -v ext|xargs rm -rf
	cd ext
	find -name tests|xargs rm -rf
}
Uninstall_PHP()
{
	if [ -f "/www/server/php/${php_version}/rpm.pl" ];then
		yum remove -y bt-php${php_version}
		[ ! -f "/www/server/php/${php_version}/bin/php" ] && exit 0;
	fi

	if [ -f "/www/server/php/${php_version}/deb.pl" ];then
		apt-get remove -y bt-php${php_version}
	fi

	/etc/init.d/php-fpm-$php_version stop

	rm -rf $php_path/$php_version

	if [ -f "$Root_Path/server/phpmyadmin/version.pl" ];then
		SetPHPMyAdmin
	fi

	for phpV in 52 53 54 55 56 70 71 72 73 74 80
	do
		if [ -f "/www/server/php/${phpV}/bin/php" ]; then
			rm -f /usr/bin/php
			ln -sf /www/server/php/${phpV}/bin/php /usr/bin/php
		fi
	done
}

actionType=$1
version=$2
php_version=${2/./}
if [ "$actionType" == 'install' ] || [ "$actionType" == 'update' ] ;then
	phpVersion=$(eval echo '$'{php_${php_version}})
	System_Lib
	Install_Openssl_1_0_2
	Install_Curl
	Install_Icu4c
	Configure_Get
	Download_Src
	Install_Configure
	Install_PHP
	if [ "${php_version}" -ge "73" ];then
		Install_Zip_ext
	fi 
	Ln_PHP_Bin
	Create_Fpm
	Set_PHP_FPM_Opt
	Set_Phpini
	Download_Conf
	Install_Zend
	Pear_Pecl_Set
	Install_Composer
	Service_Add
	Remove_Src
elif [ "$actionType" == 'uninstall' ];then
	Uninstall_PHP
	Service_Del
fi
