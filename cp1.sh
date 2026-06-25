
#!/bin/bash

echo "================================================="
echo "  NS Pulp Master CCTV Audit (Dual Engine) v5.0   "
echo "================================================="

file_name="ns_pulp_cctv_inventory.csv"

# Header File
echo "IP_Address,Make,Model_Number,Firmware_Version,Build_Date,MAC_Address,Serial_Number,Password_Used,Protocol,Status" > $file_name

echo "Scanning started from ip_list.txt..."
echo "-------------------------------------------------"

for target_ip in $(cat ip_list.txt)
do
    echo -n "Scanning $target_ip... "
    
    # Bouncer 1: Ping Check
    if ping -c 1 -W 1 $target_ip > /dev/null; then
        
        auth_success=0 
        
        for pass in "rnd@#890" "PurP0se2o23" "admin@123" "admin@890" "Admin@123"
        do
            # ==========================================
            # ENGINE 1: NORMAL CGI TEST
            # ==========================================
            sys_raw=$(curl -m 3 -s -k -L --anyauth -u "admin:$pass" "http://$target_ip/cgi-bin/magicBox.cgi?action=getSystemInfo")
            model=$(echo "$sys_raw" | grep "deviceType=" | cut -d'=' -f2 | tr -d '\r')
            
            if [ -n "$model" ]; then
                auth_success=1 
                
                soft_raw=$(curl -m 3 -s -k -L --anyauth -u "admin:$pass" "http://$target_ip/cgi-bin/magicBox.cgi?action=getSoftwareVersion")
                net_raw=$(curl -m 3 -s -k -L --anyauth -u "admin:$pass" "http://$target_ip/cgi-bin/configManager.cgi?action=getConfig&name=Network")
                
                serial=$(echo "$sys_raw" | grep "serialNumber=" | cut -d'=' -f2 | tr -d '\r')
                firmware=$(echo "$soft_raw" | grep "version=" | cut -d'=' -f2 | cut -d',' -f1 | tr -d '\r')
                build_date=$(echo "$soft_raw" | grep "version=" | cut -d',' -f2 | cut -d':' -f2 | tr -d '\r')
                mac_address=$(echo "$net_raw" | grep "PhysicalAddress=" | cut -d'=' -f2 | tr -d '\r')
                make="CP_Plus"
                
                # Save Data
                echo "$target_ip,$make,$model,$firmware,$build_date,$mac_address,$serial,$pass,CGI,Success" >> $file_name
                echo "[SUCCESS - CGI] (Pass: $pass)"
                break
            fi

            # ==========================================
            # ENGINE 2: ONVIF XML TEST (Agar CGI fail ho)
            # ==========================================
            onvif_sys=$(curl -m 3 -s -k --anyauth -u "admin:$pass" -X POST -H "Content-Type: application/soap+xml" -d '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:tds="http://www.onvif.org/ver10/device/wsdl"><s:Body><tds:GetDeviceInformation/></s:Body></s:Envelope>' "http://$target_ip/onvif/device_service")
            
            # Smart Kainchi (grep -oP) se XML Model nikalna
            onvif_model=$(echo "$onvif_sys" | grep -oP '(?<=<tds:Model>)[^<]+')

            if [ -n "$onvif_model" ]; then
                auth_success=1

                onvif_net=$(curl -m 3 -s -k --anyauth -u "admin:$pass" -X POST -H "Content-Type: application/soap+xml" -d '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:tds="http://www.onvif.org/ver10/device/wsdl"><s:Body><tds:GetNetworkInterfaces/></s:Body></s:Envelope>' "http://$target_ip/onvif/device_service")

                # Smart Kainchi for rest of the data
                serial=$(echo "$onvif_sys" | grep -oP '(?<=<tds:SerialNumber>)[^<]+')
                firmware=$(echo "$onvif_sys" | grep -oP '(?<=<tds:FirmwareVersion>)[^<]+')
                make=$(echo "$onvif_sys" | grep -oP '(?<=<tds:Manufacturer>)[^<]+')
                mac_address=$(echo "$onvif_net" | grep -oP '(?<=<tt:HwAddress>)[^<]+')
                build_date="N/A" # ONVIF direct build date nahi deta
                
                # Save Data
                echo "$target_ip,$make,$onvif_model,$firmware,$build_date,$mac_address,$serial,$pass,ONVIF,Success" >> $file_name
                echo "[SUCCESS - ONVIF] (Pass: $pass)"
                break
            fi
        done
        
        # FAIL CONDITION
        if [ $auth_success -eq 0 ]; then
            echo "$target_ip,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,API Locked / Auth Fail" >> $file_name
            echo "[API LOCKED / AUTH FAIL]"
        fi
        
    else
        # OFFLINE CONDITION
        echo "$target_ip,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,Offline (Ping Fail)" >> $file_name
        echo "[OFFLINE/DOWN]"
    fi
done

echo "-------------------------------------------------"
echo "Mission Accomplished Boss! 🚀"
echo "Aapki Dual-Engine Excel file taiyar hai: $file_name"
echo "================================================="
