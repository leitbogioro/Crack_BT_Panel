# Crack_BT_Panel
<p>宝塔面板5.9.X Pro破解版一键脚本已完成，欢迎使用</p>
<p>网上主流的破解方法是导入其他已授权用户的配置信息，部分下载源并非来自宝塔官方渠道，安全性无法保障，本方法全部基于修改本地文件实现，安全绿色无后门。</p>
<p>本破解方法的原理是通过劫持宝塔面板的 common.py 里，第 164 行记录 release 的信息，将其延期到 2999 年，实现了永久破解的目的。</p>

## 使用须知
<p>本脚本必须在完全干净的 CentOS/Debian/Ubuntu 系统上安装</p>
<p>如已安装更高版本的宝塔面板，请先卸载高版本再安装</p>
<p>如已安装其他种类的面板，或 LNMP 之类的运行环境、一键包，建议备份好数据，重装干净系统再安装</p>

## 使用方法
<code>wget -O crack_bt_panel_pro.sh https://git.io/fprzD && bash crack_bt_panel_pro.sh</code>
