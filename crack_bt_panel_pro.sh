#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# 颜色
blue='\033[0;34m'
yellow='\033[0;33m'
green='\033[0;32m'
red='\033[0;31m'
plain='\033[0m'

#检查是否为Root
[ $(id -u) != "0" ] && { echo -e "${red}[错误]${plain} 你必须以 root 用户执行此安装程序"; exit 1; }

echo ""
echo "欢迎安装宝塔面板Pro破解版！"
echo ""
echo -e "${red}[警告]"
echo -e "${plain}本程序系个人制作，具备宝塔面板5.9专业版的所有功能"
echo "如有侵权，请联系作者在第一时间处理"
echo "安装并试用后，请在24小时内卸载"
echo ""
echo -e "${yellow}[说明]"
echo -e "${plain}本脚本必须在完全干净的 CentOS/Debian/Ubuntu 系统上安装"
echo "如已安装更高版本的宝塔面板，请先卸载高版本再安装"
echo "如已安装其他种类的面板，或 LNMP 之类的运行环境、一键包，建议备份好数据，重装干净系统再安装"
echo "使用本脚本出现的任何不良后果，本人概不负责"
echo ""
echo -e "${blue}[支持]"
echo -e "${plain}zhihu: https://www.zhihu.com/people/deepdarkfantastic"
echo "email: net.core@outlook.com"
echo ""

#确认安装
while [ "$go" != 'y' ] && [ "$go" != 'n' ]
do
    read -p "确定要安装吗？(y/n): " go;
done
if [ "$go" = 'n' ];then
    exit;
fi

#检查系统信息
if [ -f /etc/redhat-release ] && [[ `grep -i 'centos' /etc/redhat-release` ]]; then
    OS='CentOS'
elif [ ! -z "`cat /etc/issue | grep bian`" ];then
    OS='Debian'
elif [ ! -z "`cat /etc/issue | grep Ubuntu`" ];then
    OS='Ubuntu'
else
    echo -e "${red}[错误]${plain} 你的操作系统不受支持，请选择在 Ubuntu/Debian/CentOS 操作系统上安装！"
    exit 1
fi

#禁用SELinux
if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
fi

#输出 centos 系统大版本号
System_CentOS=`rpm -q centos-release|cut -d- -f1`
CentOS_Version=`cat /etc/redhat-release|sed -r 's/.* ([0-9]+)\..*/\1/'`

#CentOS 6 专用 python
install_python_for_CentOS6() {
    py_for_centos="https://raw.githubusercontent.com/leitbogioro/SSR.Go/master/python_for_centos6.sh"
    py_intall="python_for_centos6.sh"
    yum install wget -y
    wget ${py_for_centos}
    if ! wget ${py_for_centos}; then
        echo -e "[${red}错误${plain}] ${py_file} 下载失败，请检测你的网络！"
        exit 1
    fi
    bash ${py_intall}
    rm -rf /root/${py_intall}
}

#CentOS 7 专用 pip 源
install_python_for_CentOS7() {
    pip_file="get-pip.py"
    pip_url="https://bootstrap.pypa.io/get-pip.py"
    yum install python -y
    curl ${pip_url} -o ${pip_file}
    if ! curl ${pip_url} -o ${pip_file}; then
        echo -e "[${red}错误${plain}] ${pip_file} 下载失败，请检测你的网络！"
        exit 1
    fi
    python ${pip_file}
    rm -rf /root/${pip_file}
}

install_btPanel_for_CentOS() {
    yum install -y wget && wget -O install.sh https://git.io/fj0zQ && bash install.sh
    wget -O update.sh https://git.io/fj0zD && bash update.sh pro
}

install_btPanel_for_APT() {
    wget -O install.sh https://git.io/fj0z5 && bash install.sh
    wget -O update.sh https://git.io/fj0zD && bash update.sh pro
}

#破解步骤
crack_bt_panel() {
    export Crack_file=/www/server/panel/class/common.py
    echo -e "${yellow}[注意] ${plain}破解执行中..."
    /etc/init.d/bt stop
    sed -i $'164s/panelAuth.panelAuth().get_order_status(None)/{\'status\': \True, \'msg\': {\'endtime\': 32503651199}}/g' ${Crack_file}
    touch /www/server/panel/data/userInfo.json
    /etc/init.d/bt restart
}

#定时重启宝塔面板
execute_bt_panel() {
    if ! grep '/etc/init.d/bt restart' /etc/crontab; then
        systemctl enable cron.service
        systemctl start cron.service
        echo "0  0    * * 0   root    /etc/init.d/bt restart" >> /etc/crontab
        /etc/init.d/cron restart
    fi
}

#开启 ssl
enable_ssl(){
    if [ ! -f /www/server/panel/data/ssl.pl ]; then
        echo "Ture" > /www/server/panel/data/ssl.pl
        /usr/bin/python /usr/local/bin/pip install pyOpenSSL==16.2
        /etc/init.d/bt restart
    fi
}

# 安装后清理
clean_up() {
    rm -rf crack_bt_panel_pro.sh
    rm -rf update.sh
    if [[ ${OS} == 'Ubuntu' ]] || [[ ${OS} == 'Debian' ]]; then
        apt-get autoremove -y
    fi
    # 删除各类残留
    rm -rf /www/server/panel/plugin/btyw /root/install_cjson.sh /root/.pip /root/.pydistutils.cfg
}

# 预安装组件
components(){
    cd /root
    wget -O lib.sh https://git.io/fjmak
    mv lib.sh /www/server/panel/install
    wget -O nginx.sh https://git.io/fj0O9
    mv nginx.sh /www/server/panel/install
    if [ -f /www/server/panel/install/install_soft.sh ]; then
        rm -rf install_soft.sh
        wget -O install_soft.sh https://git.io/fj03A
        mv install_soft.sh /www/server/panel/install
    fi
}

# 插件配置
vip_plugin(){
    # 默认安装所有付费高级插件
    cd /www/server/panel/plugin
    if [ ! -d "/masterslave" ]; then
        wget -O vip_plugin.zip https://git.io/fj0VQ
        unzip vip_plugin.zip
        rm -f vip_plugin.zip
    fi
    cd /root
}

#正式安装
if [[ ${OS} == 'CentOS' ]] && [[ ${CentOS_Version} -eq "7" ]]; then
    yum install epel-release wget curl nss fail2ban unzip lrzsz vim* -y
    yum update -y
    yum clean all
    install_btPanel_for_CentOS
    install_python_for_CentOS7
    crack_bt_panel
    #enable_ssl
    #vip_plugin
elif [[ ${OS} == 'CentOS' ]] && [[ ${CentOS_Version} -eq "6" ]]; then
    yum install epel-release wget curl nss fail2ban unzip lrzsz vim* -y
    yum update -y
    yum clean all
    install_btPanel_for_CentOS
    install_python_for_CentOS6
    crack_bt_panel
    #enable_ssl
    #vip_plugin
elif [[ ${OS} == 'Ubuntu' ]] || [[ ${OS} == 'Debian' ]]; then
    apt-get update
    apt-get install ca-certificates -y
    apt-get install sudo apt-transport-https vim vim-gnome libnet-ifconfig-wrapper-perl socat vim vim-gnome vim-gtk libnet-ifconfig-wrapper-perl socat lrzsz fail2ban wget curl unrar unzip cron dnsutils net-tools git git-svn make cmake gdb tig -y
    install_btPanel_for_APT
    crack_bt_panel
    components
    #enable_ssl
    #vip_plugin
    execute_bt_panel    
fi

clean_up

echo -e "${green}[完成] ${plain}宝塔面板破解版已安装成功！"
echo "按脚本提供的后台入口、账号、密码，登录宝塔面板并使用！"
