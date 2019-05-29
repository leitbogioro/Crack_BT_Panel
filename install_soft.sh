#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
mtype=$1
actionType=$2
name=$3
version=$4
. /www/server/panel/install/public.sh
serverUrl=$NODE_URL/install

if [ ! -f 'lib.sh' ]; then
    wget -O lib.sh $serverUrl/$mtype/lib.sh
fi

if [ ! -f ${name}'.sh' ]; then
    wget -O $name.sh $serverUrl/$mtype/$name.sh
fi
	
if [ "$actionType" == 'install' ]; then
    bash lib.sh
fi

bash $name.sh $actionType $version
