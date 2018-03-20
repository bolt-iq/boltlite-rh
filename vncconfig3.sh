#!/bin/bash
userNum=1

#Step1: Find the available port(s) for VNC service
port=5901
session=1
count=0
ports=()
sessions=()
currentTimestamp=`date +%y-%m-%d-%H:%M:%S`
while [ "$count" -lt "$userNum" ]; do
    netstat -a | grep ":$port\s" >> /dev/null
    if [ $? -ne 0 ]; then
        ports[$count]=$port
        sessions[$count]=$session
        count=`expr $count + 1`
        echo $port" is available for VNC service"
    fi
    session=`expr $session + 1`
    port=`expr $port + 1`
done

#Step2: Set the VNC password

echo "Please set the VNC password for user bolt"
#type password in shell script
#expect "password:"
# Send the username, and then wait for a password prompt.
#send "password\r"
#expect "verify:"
# Send the password, and then wait for a shell prompt.
#send "password\r"
#expect "Would you like to enter a view-only password (y/n)?"
# Send the password, and then wait for a shell prompt.
#send "n\r"

#su - bolt -c vncpasswd
(echo -e "password/npassword/nn") | vncpasswd

#Step3: Write the VNC configuration
#Backup configuration file

vnc_conf="/etc/systemd/system/vncserver@:"${sessions[0]}".service"
vnc_conf_backup=$vnc_conf.vncconfig.$currentTimestamp
if [ -f "$vnc_conf" ]; then
    echo backup $vnc_conf to $vnc_conf_backup
    cp $vnc_conf $vnc_conf_backup
fi
echo "
[Unit]
Description=Remote desktop service (VNC)
After=syslog.target network.target

[Service]
Type=forking
# Clean any existing files in /tmp/.X11-unix environment
ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill %i > /dev/null 2>&1 || :'
ExecStart=/sbin/runuser -l bolt -c \"/usr/bin/vncserver %i -extension RANDR -geometry 1024x768\"
PIDFile=~bolt/.vnc/%H%i.pid
ExecStop=/bin/sh -c '/usr/bin/vncserver -kill %i > /dev/null 2>&1 || :'

[Install]
WantedBy=multi-user.target
" > $vnc_conf
chmod a+x $vnc_conf


#Step 4: Set the desktop enviroment

xstartupContent='#!/bin/sh
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
vncconfig -iconic &
startkde &
'


#Write configuration to files and backup files

vnc_desktop_conf=~bolt/.vnc/xstartup
vnc_desktop_conf_backup=$vnc_desktop_conf.vncconfig.$currentTimestamp
if [ -f "$vnc_desktop_conf" ]; then
    echo backup $vnc_desktop_conf to $vnc_desktop_conf_backup
    cp $vnc_desktop_conf $vnc_desktop_conf_backup
fi
echo "$xstartupContent" > $vnc_desktop_conf
chmod 755 $vnc_desktop_conf



#Step5:Start the VNC service
#Start the VNC service
systemctl.py daemon-reload

systemctl.py enable vncserver@:${sessions[0]}.service
systemctl.py start vncserver@:${sessions[0]}.service


#Step6: If default firewall is used, we will open the VNC ports


#Step7: Echo the information that VNC client can connect to

red='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${red}Display number for user bolt is ${sessions[0]}${NC}"
