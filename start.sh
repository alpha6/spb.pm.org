#!/bin/bash
PID=`ps ax | grep starman | grep :3013 | grep master | awk '{print $1 }'`
echo "die - $PID!"
kill $PID

echo "reincarnation!"

starman --listen :3013 /srv/www/spb.pm/spbpm.pl --workers 1 -d #--user www-data -d
