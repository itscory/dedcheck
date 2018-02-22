#!/usr/bin/env bash
# Made by Corey Stewart
# Version 1.2
# Purpose: To display VPS/dedicated server information and identify common server issues.

# Lets define some colors!
RED='\033[0;41m'
NC='\033[0m' # No Color
color=${NC}

# Server details
echo -ne "\n"
echo "Hostname: $(hostname)"
echo "Main IP: $(hostname -i)"

# Check cPanel license
if [[ $(/usr/local/cpanel/cpkeyclt) = *"Update succeeded"* ]]
then dedcheck_cpanellicensestatus=Active
else dedcheck_cpanellicensestatus="${RED}Invalid${NC}"
fi
echo -e "cPanel License: $dedcheck_cpanellicensestatus"

# Number of IPs in use.
echo "IPs:" $(/usr/local/cpanel/scripts/ipusage |wc -l)

# Number of cPanel accounts
echo "cPanel Accounts: $(cat /etc/trueuserdomains |wc -l)"

# EasyApache version
# Color red if it is 3, because that's good to know.
if [ -d /etc/cpanel/ea4 ]
then eaversion="EasyApache 4"
color=${NC}
else eaversion="EasyApache 3"
color=${RED}
fi
echo -e "${color}EA Version: $eaversion${NC}"

# What firewall is running?
if [ -s /etc/csf ]
then firewall=CSF
else if [ -s /etc/apf ]
then firewall=APF
else firewall=UNKNOWN
fi
fi
echo "Firewall: $firewall"
echo -ne "\n"

# CPU load and count
echo "------Load------"
# Make red if load is greater than nproc
dedcheck_load=$(uptime | grep -ohe 'load average[s:][: ].*' | awk '{ print $3 }' |sed 's|[,]||g')
# Make the load an integer
dedcheck_load=$( printf "%.0f" $dedcheck_load )
color=${NC}
if [ $dedcheck_load -gt $(nproc) ]
then color=${RED}
fi
echo -e "${color}Load: $(uptime | awk -F'[a-z]:' '{ print $2}')${NC}"
color=${NC}
echo "CPUs: $(nproc)"
echo -ne "\n"

# Figure out what the mail ip is
echo "------Exim------"
# If the mailips file is not empty, then whatever is in there is the mail IP.
if [ -s /etc/mailips ]
then mailip=$(grep "*:" /etc/mailips |awk '{print $2}')
# Otherwise, it is the main IP of the server.
else mailip=$(hostname -i)
fi
echo "Mail IP: $mailip"

# rDNS of the mail ip
# This will turn red if the rDNS of the mail IP does not match the hostname, which should concern you.
rdns=$(dig @ns1.inmotionhosting.com -x $mailip +short)
if ! [ "$(hostname)." == "$rdns" ]
then color=${RED}
else color=${NC}
fi
echo -e "${color}rDNS: $(dig @ns1.inmotionhosting.com -x $mailip +short)${NC}"

# Exim queue
# This will turn red if the queue is greater than 100
isspamming=1 #FOR TESTING! CHANGE TO 0 BEFORE RELEASE!
queue=$(exim -bpc)
if [ $queue -gt 100 ]
then color=${RED}
isspamming=1
else color=${NC}
fi
echo -e "${color}Queue: $(exim -bpc)${NC}"
echo -ne "\n"
# Display top dovecot senders if server is spamming.
if [ "$isspamming" == "1" ]
then echo "------Dovecot emails sent since $(head -1 /var/log/exim_mainlog |awk '{print $1}')------"
grep "A=dovecot_login" /var/log/exim_mainlog | awk -F"A=dovecot_login:" {'print $2'} | cut -f1 -d' ' | sort | uniq -c | sort -n | awk {'print $1, " unique emails sent by " , $2'}
echo -ne "\n"
fi

# Display disk usage
echo "------Disk------"
# We need some red color when disk space is higher than 95%. This is going to be a little tricky.
# We want to set the internal field separator to what it was before after we're done with it.
dedcheck_oldIFS=$IFS
IFS=$'\n'
# Disk space
dedcheck_dfhead=$(df -h |grep --color=never ^Filesystem)
dedcheck_devdisks=$(df -h |grep --color=never ^/dev)
echo $dedcheck_dfhead
for i in $dedcheck_devdisks
do if [ $(echo $i |awk '{print $5}' | tr -d '%') -gt '90' ]
then color=${RED}
else color=${NC}
fi
echo -e "${color}$i${NC}"
done
echo -ne "\n"
# Inodes
dedcheck_idfhead=$(df -ih |grep --color=never ^Filesystem)
dedcheck_idevdisks=$(df -ih |grep --color=never ^/dev)
echo $dedcheck_idfhead
for i in $dedcheck_idevdisks
do if [ $(echo $i |awk '{print $5}' | tr -d '%') -gt '90' ]
then color=${RED}
else color=${NC}
fi
echo -e "${color}$i${NC}"
done
IFS=$dedcheck_oldIFS
echo -ne "\n"

# Service check
for service in httpd exim cpanel mysql named dovecot
do if ! (( $(ps -ef | grep -v grep | grep -c $service) > 0 ))
then echo -e "${RED} ! ! ! $service is DOWN ! ! ! ${NC}"
fi
done

# Custom services
# Slack me if you can think of any other concerning services to add.
for service in nginx varnish redis memcache
do if (( $(ps -ef | grep -v grep | grep -c $service) > 0 ))
then echo -e "${RED} ! ! ! $service is RUNNING ! ! ! ${NC}"
fi
done
echo -ne "\n"
