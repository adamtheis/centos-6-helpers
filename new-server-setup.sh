#!/bin/bash
#this script was developed for speeding up the deployment of centOS 6 cloned virtual machines
#this script assumes iptables are installed and configured in the base image.
#this script assumes a sysadmin user account is present before joining and active directory controlled domain.
#First Run script to set network and hostname with iptables ssh access, Join Domain, Check and configure AIDE database
#
#
#clear the screen for nice menus
clear
#Define base files and prepare these files should already exist in the base image
hosts=/etc/hosts
resolv=/etc/resolv.conf
iptables=/etc/sysconfig/iptables
network=/etc/sysconfig/network
interface=/etc/sysconfig/network-scripts/ifcfg-eth0
passauth=/etc/pam.d/password-auth
#Setup for menu choice
echo "New Server Config for network and hostname with iptables ssh access, Join Domain, Check and configure AIDE database"
echo "Please Select from the following options"
echo ""
mainmenuoptions=("Network Config" "Domain Config" "AIDE Setup" "Quit")
mainmenuoptionsprompt='Please enter your choice or hit [ENTER] for menu: '

networkoptions=("Enter All" "Mac Address" "IP Address" "Subnet Mask" "Default Gateway" "Hostname" "View All" "Commit to Changes" "Back")
networkoptionsprompt='Select Network Component or [ENTER] for menu: '

domainoptions=("Edit Domain" "Join Domain" "View Domain" "Back")
domainoptionsprompt='Press [ENTER] for Menu to configure Domain options: '

aideoptions=("Check AIDE" "Reset AIDE" "Back")
aideoptionsprompt='Press [ENTER] for Menu to check or reset AIDE database: '

PS3=$mainmenuoptionsprompt
select mainopt in "${mainmenuoptions[@]}"
   do
    case $mainopt in
        "Network Config")
        clear
        #take care entering information the script has limited error correction and checking
        PS3=$networkoptionsprompt
        select networkopt in "${networkoptions[@]}"
                do
                case $networkopt in
                        "Enter All")
                        echo "Enter MAC address from virtual adapter in the form 11:22:33:44:55:66 and press [ENTER]: "
                        read macaddress
                        echo "Enter desired IP Addres in the form 192.168.0.1 and press [ENTER]: "
                        read ipaddress
                        echo "Enter subnet mask in the form 255.255.255.0 and press [ENTER]: "
                        read netmask
                        echo "Enter Default Gateway Address in the form 192.168.0.1 and press [ENTER]: "
                        read gwaddress
                        echo "enter HOSTNAME and press [ENTER]: "
                        read hostname
                        ;;
                        "MAC Address")
                        echo "Mac Address will be set to $macaddress     Enter new MAC Address in the format 11:22:33:44:55:66"
                        read macaddress
                        ;;
                        "IP Address")
                        echo "Current Address is $ipaddress       Enter new IP Address in the format 192.168.0.1"
                        read ipaddress
                        ;;
                        "Subnet Mask")
                        echo "Current Netmask is $netmask         Enter new Subnetmask in the format 255.255.255.0"
                        read netmask
                        ;;
                        "Default Gateway")
                        echo "Current Gateway address is $gwaddress       Enter new Default Gateway Address e.g. 192.168.0.1"
                        read gwaddress
                        ;;
                        "Hostname")
                        echo " Current Hostname is $hostname            Enter new HOSTNAME "
                        read hostname
                        ;;
                        "View All")
                        echo "
2) MAC Address     = $macaddress
3) IPAddress       = $ipaddress 
4) Subnet Mask     = $netmask
5) Default Gateway = $gwaddress
6) Hostname        = $hostname "
                        ;;
                        "Commit to Changes")
clear
                        echo "

The following data will be written to the relevant system files

MAC Address     = $macaddress
IPAddress       = $ipaddress 
Subnet Mask     = $netmask
Default Gateway = $gwaddress
Hostname        = $hostname 
"
                        echo "Now writing inputs to files"
                        #setup the network card ifcfg-eth0
                        echo 'DEVICE="eth0"' > $interface
                        echo 'HWADDR="'$macaddress'"' | tr '[:lower:]' '[:upper:]' >> $interface
                        echo 'NM_CONTROLLED="no"' >> $interface
                        echo 'ONBOOT="yes"' >> $interface
                        echo 'BOOTPROTO=static' >> $interface
                        echo 'IPADDR='$ipaddress >> $interface
                        echo 'NETMASK='$netmask >> $interface
                        echo 'GATEWAY='$gwaddress >> $interface

                        #set the hostname
                        echo 'NETWORKING=yes' > $network
                        echo 'HOSTNAME='$hostname >> $network
                        echo 'NETWORKING_IPV6=no' >> $network
                        echo 'IPV6INIT=no' >> $network
                        echo 'IPV6_AUTOCONF=no' >> $network

                        #Configure IPtables for ssh access
                        sed -i "s/THISIP/$ipaddress/g" $iptables

                        #restart the services
                        service iptables restart
                        service network restart
                        hostname $hostname
                        echo "data written to the following files"
                        echo $interface
                        cat $interface
                        echo ""
                        echo $network
                        cat $network
                        echo ""
                        echo $iptables
                        cat $iptables | grep eth0
                        echo ""
                        ;;

                        "Back")
                        clear
                        PS3=$mainmenuoptionsprompt
                        break
                        ;;
                        *) echo invalid option;;
                    esac
                   done
                ;;
        "Domain Config")
        clear
        #To join an active directory controlled domain
        PS3=$domainoptionsprompt
        select domainopt in "${domainoptions[@]}"
              do
               case $domainopt in

                "Edit Domain")
                echo "Enter Domain you wish to join and press [ENTER] :"
                read domain
                echo "Enter Windows Workgroup you wish to join and press [ENTER] :"
                read workgroup
                echo "Enter Domain Admin account to join to the domain with :"
                read domainadmin
                echo "Enter Primary Domain Controller FQDN :"
                read pdcfqdn
                echo "Enter Primary Domain Controller IP Address :"
                read pdcip
                REALM=$(echo $domain | tr '[:lower:]' '[:upper:]' )
;;

                "Join Domain")
                #configure the hosts file
                ip=$(ifconfig | gawk '
                    /^[a-z]/ {interface = $1}
                    interface == "eth0" && match($0, /^.*inet addr:([.0-9]+)/, a) {
                        print a[1]
                        exit
                    }
                ')
                hostname=${HOSTNAME?}
                if grep "$ip $hostname.$domain $hostname" $hosts
                        then
                            echo "Hosts file already configured, skipping this part."
                        else
                            sed  -i "1a\\${ip} ${hostname}"."${domain} ${hostname}" $hosts
                    fi
                sed -i "2a\\$pdcip $pdcfqdn" $hosts

                #configure resolv.conf file
                if grep "search $pdcfqdn" $resolv
                        then
                          echo "resolv.conf file already configured, skipping this part."
                        else
                          sed  -i "1a\\search $pdcfqdn" $resolv
                    fi
               
                 echo "Installing required software and then joining the domain"
                yum install -y pam_krb5 samba-winbind-krb5-locator krb5-libs samba nscd authconfig

                authconfig --enableshadow \
                --enablemd5 \
                --enablekrb5 \
                --krb5kdc=$domain \
                --krb5adminserver=$pdcfqdn \
                --krb5realm=$REALM \
                --enablekrb5kdcdns \
                --enablekrb5realmdns \
                --smbservers=$pdcfqdn \
                --smbworkgroup=$workgroup \
                --enablewinbind \
                --enablewinbindauth \
                --smbsecurity=ads \
                --smbrealm=$REALM \
                --winbindtemplateshell=/bin/bash \
                --enablewinbindusedefaultdomain \
                --enablewinbindoffline \
                --winbindjoin=$domainadmin \
                --enablecache \
                --enablelocauthorize \
                --enablepamaccess \
                --enablemkhomedir \
                --disablesysnetauth \
                --kickstart

                pamhomedir1="session optional pam_mkhomedir.so"                
                pamhomedir2="session optional pam_mkhomedir.so umask=0077"                
                sed -ir s/'auth        requisite     pam_succeed_if.so uid >= 500 quiet'/'auth        requisite     pam_succeed_if.so user ingroup linuxadmin debug'/g $passauth
                  if  grep "$pamhomedir1" "$passauth"
                        then
                           echo "homedir config already exist, skipping this part."
                        else
                            echo $pamhomedir2 >> $passauth
                     fi
                  if  grep "$pamhomedir2" "$passauth"
                        then
                           echo "homedir config already exist, skipping this part."
                        else
                            sed -ir "s/$pamhomedir1/$pamhomedir2/g" $passauth
                     fi 

                chkconfig winbind on
                chkconfig smb on
                service smb restart
                service winbind restart
                echo 'Removing "sysadmin" account, you will need been to be a member of the "linuxadmin" group in '$domain'
 to access this server through ssh, the root account is unaffected.'
                userdel        sysadmin
                echo "The domain has been joined you must Restart the server to use new settings for Active Directory ssh access"
                echo "Manually check the $hosts and $resolv files for errors as this will affect network operations"
                ;;

                "View Domain")
                echo "Domain details"
                echo "
Domain to Join            = $domain
Workgroup to Join         = $workgroup
Domain Admin Account      = $domainadmin
Primary Domain Controller = $pdcfqdn
REALM to Join             = $REALM
"
                ;;

                "Back")
                clear
                PS3=$mainmenuoptionsprompt
                break
                ;;
                *) echo invalid option;;
               esac
              done
                ;;

        "AIDE Setup")
        clear
        #auto configure the AIDE security setup
        PS3=$aideoptionsprompt
        select aideopt in "${aideoptions[@]}"
              do
               case $aideopt in

                "Check AIDE")
                clear
 #test aide config and db - should return no conflicts
                echo "Checking The AIDE Database, this may take a few more minutes"
                /usr/sbin/aide --check
                ;;

                "Reset AIDE")
                clear
                echo "Building The AIDE Database, this may take a few minutes"
                #AIDE config and db Setup
                #Generate a new database:
                /usr/sbin/aide --init

                #Install the newly-generated database:
                cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

                #test aide config and db - should return no conflicts
                echo "Checking The AIDE Database, this may take a few more minutes"
                /usr/sbin/aide --check
                ;;

                "Back")
                clear
                PS3=$mainmenuoptionsprompt
                break
                ;;
                *) echo invalid option;;
               esac
              done
                ;;

        "Quit")
        exit 0
        ;;
       *) echo invalid option;;
      esac
     done
        ;;

