#!/bin/bash

echo "================================================="
echo "  NS Pulp Master CCTV Audit (Error Logging) v4.0 "
echo "================================================="

file_name="ns_pulp_cctv_inventory.csv"

# NAYA: Header mein sabse aakhiri column 'Status' add kar diya hai
echo "IP_Address,Make,Model_Number,Firmware_Version,Build_Date,MAC_Address,Serial_Number,Password_Used,Status" > $file_name

echo "Scanning started from ip_list.txt..."
echo "-------------------------------------------------"

for target_ip in $(cat ip_list.txt)
do
    echo -n "Scanning $target_ip... "
    
    # Bouncer 1: Ping Check
    if ping -c 1 -W 1 $target_ip > /dev/null; then
        
        auth_success=0 
        
        for pass in "Admin@123"
        do
            sys_raw=$(curl -m 3 -s --anyauth -u "admin:$pass" "http://$target_ip/cgi-bin/magicBox.cgi?action=getSystemInfo")
            model=$(echo "$sys_raw" | grep "deviceType=" | cut -d'=' -f2 | tr -d '\r')
            
            if [ -n "$model" ]; then
                auth_success=1 
                
                # Data nikalna
                soft_raw=$(curl -m 3 -s --anyauth -u "admin:$pass" "http://$target_ip/cgi-bin/magicBox.cgi?action=getSoftwareVersion")
                net_raw=$(curl -m 3 -s --anyauth -u "admin:$pass" "http://$target_ip/cgi-bin/configManager.cgi?action=getConfig&name=Network")
                
                serial=$(echo "$sys_raw" | grep "serialNumber=" | cut -d'=' -f2 | tr -d '\r')
                firmware=$(echo "$soft_raw" | grep "version=" | cut -d'=' -f2 | cut -d',' -f1 | tr -d '\r')
                build_date=$(echo "$soft_raw" | grep "version=" | cut -d',' -f2 | cut -d':' -f2 | tr -d '\r')
                mac_address=$(echo "$net_raw" | grep "PhysicalAddress=" | cut -d'=' -f2 | tr -d '\r')
                make="CP_Plus"
                
                # SUCCESS CONDITION: Data ke sath 'Success' status bhejna
                echo "$target_ip,$make,$model,$firmware,$build_date,$mac_address,$serial,$pass,Success" >> $file_name
                
                echo "[SUCCESS] (Pass: $pass)"
                break
            fi
        done
        
        # FAIL CONDITION: Agar API band hai ya saare password galat hain
        if [ $auth_success -eq 0 ]; then
            # N/A bhar kar aakhiri dabbe mein exact Error likh diya
            echo "$target_ip,N/A,N/A,N/A,N/A,N/A,N/A,N/A,API Locked or Auth Fail" >> $file_name
            echo "[API LOCKED / AUTH FAIL]"
        fi
        
    else
        # OFFLINE CONDITION: Agar camera network par hi nahi hai
        echo "$target_ip,N/A,N/A,N/A,N/A,N/A,N/A,N/A,Offline (Ping Fail)" >> $file_name
        echo "[OFFLINE/DOWN]"
    fi
done

echo "-------------------------------------------------"
echo "Mission Accomplished Boss! 🚀"
echo "Aapki smart Excel file taiyar hai: $file_name"
echo "================================================="
