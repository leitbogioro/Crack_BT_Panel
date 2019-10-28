#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

Remove_Bt(){
	if [ ! -f "/etc/init.d/bt" ] || [ ! -d "/www/server/panel" ]; then
		echo -e "此服务器没有安装宝塔！"
		echo -e "This server does not install bt-panel"
		exit;
	fi

	if [ -f "/etc/init.d/bt_syssafe" ]; then
		echo -e "此服务器装有宝塔系统加固可能导致无法正常卸载，请在面板卸载后再执行卸载命令！"
		exit;
	fi

	if [ -f "/etc/init.d/bt_tamper_proof" ]; then
		echo -e "此服务器装有宝塔网站防篡改可能导致无法正常卸载，请在面板卸载后再执行卸载命令！"
		exit;
	fi

	/etc/init.d/bt stop
	if [ -f "/usr/sbin/chkconfig" ];then
		chkconfig --del bt
	elif [ -f "/usr/sbin/update-rc.d" ];then
		update-rc.d -f bt remove
	fi
	rm -rf /www/server/panel
	rm -f /etc/init.d/bt 
	echo -e "宝塔面板已卸载成功"
	echo -e "bt-panel uninstall success"
}
Remove_Rpm(){
	echo -e "查询已安装rpm包.."
	echo -e "Find installed packages"
	for lib in libiconv-1.14 libmcrypt-2.5.8 mcrypt-2.6.8 mhash-0.9.9.9 bt-nginx bt-httpd bt-mysql bt-curl bt-AliSQL AliSQL-master bt-mariadb bt-php-5.2 bt-php-5.3 bt-php-5.4 bt-php-5.5 bt-php-5.6 bt-php-7.0 bt-php-7.1
	do
		rpm -qa |grep ${lib} > ${lib}.pl
		libRpm=`cat ${lib}.pl`
		if [ "${libRpm}" != "" ]; then
			rpm -e ${libRpm} --nodeps > /dev/null 2>&1
			echo -e ${lib} "\033[32mclean\033[0m"
		fi
		rm -f ${lib}.pl
	done
	yum remove bt-openssl* -y
	yum remove bt-php* -y
	echo -e "清理完毕"
	echo -e "Clean over"
}

Remove_Service(){
	servicePath="/www/server"

	for service in nginx httpd mysqld pure-ftpd tomcat redis memcached mongodb pgsql tomcat tomcat7 tomcat8 tomcat9 php-fpm-52 php-fpm-53 php-fpm-54 php-fpm-55 php-fpm-56 php-fpm-70 php-fpm-71 php-fpm-72 php-fpm-73
	do
		if [ -f "/etc/init.d/${service}" ]; then
			/etc/init.d/${service} stop
			if [ -f "/usr/sbin/chkconfig" ];then
				chkconfig  --del ${service}
			elif [ -f "/usr/sbin/update-rc.d" ];then
				update-rc.d -f ${service} remove
			fi

			if [ "${service}" = "mysqld" ]; then
			 	rm -rf ${servicePath}/mysql
			 	rm -f /etc/my.cnf
			elif [ "${service}" = "httpd" ]; then
				rm -rf ${servicePath}/apache
			elif [ "${service}" = "memcached" ]; then
				rm -rf /usr/local/memcached
			elif [ -d "${servicePath}/${service}" ]; then
				rm -rf ${servicePath}/${service}
			fi 
			rm -f /etc/init.d/${service}
			echo -e ${service} "\033[32mclean\033[0m"
		fi
	done


	[ -d "${servicePath}/php" ] && rm -rf ${servicePath}/php
	if [ -d "${servicePath}/phpmyadmin" ]; then
		rm -rf ${servicePath}/phpmyadmin
		echo -e "phpmyadmin" "\033[32mclean\033[0m"
	fi

	if [ -d "${servicePath}/nvm" ]; then
		source /www/server/nvm/nvm.sh
		pm2 stop all
		rm -rf ${servicePath}/nvm
		sed -i "/NVM/d" /root/.bash_profile
		sed -i "/NVM/d" /root/.bashrc
		echo -e "node.js" "\033[32mclean\033[0m"
	fi

	if [ -f /opt/gitlab/embedded/service/gitlab-rails/Gemfile ];then
		gitlab-ctl stop
		yum remove gitlab-ce -y
		rm -rf /opt/gitlab
		rm -rf /var/opt/gitlab
		rm -rf /etc/gitlab
		rm -rf /www/server/panel/plugin/gitlab
		echo -e "gitlab" "\033[32mclean\033[0m"
	fi

	echo "清除面板运行环境完毕"
}
Remove_Data(){
	rm -rf /www/server/data
	rm -rf /www/wwwlogs
	rm -rf /www/wwwroot
}
 
#echo -e "What you want to do ?(Default:1)"
echo "1) 卸载宝塔"  
echo "2) 卸载宝塔及运行环境"
#echo "3) 卸载宝塔及运行环境并清除所有站点相关数据"
echo "*请检查安全类软件是否关闭，否正可能导致无法正常卸载 "
echo "=================================================" 
read -p "请选择你要进行的操作(1-2 默认:1): " action; 

case $action in
	'1')
		Remove_Bt
		;;
	'2')
		if [ -f "/usr/bin/yum" ] && [ -f "/usr/bin/rpm" ]; then
			Remove_Rpm
		fi
		Remove_Service
		Remove_Bt
		;;
	*)
		Remove_Bt
		;;
esac
