#!/bin/bash

# Name:     CAconfig.sh
# Author:   Noah DaMetz
# Created:  04/01/2021
# Modified: 06/26/2021

# The purpose of this script is to simplify the process of creating
# and revoking certificates to be used with an OpenVPN server. This script
# assumes you have setup your OpenVPN server following the Digital Ocean OpenVPN guide.

# =============== VARIABLES ===============
EASYRSADIR=../easy-rsa
serverIP=127.0.0.1

# Text Colors
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'

prompt=">> "

# =============== MAIN BEGIN ===============

if [ "$EUID" -ne 0 ]; then
	echo "Please run this script with 'sudo'"
	exit 1
fi
echo -e "Welcome to the Easy-RSA\n"
echo "   ______ ___       ______ ____   _   __ ______ ____ ______ __  __ ____   ___   ______ ____ ____   _   __
  / ____//   |     / ____// __ \ / | / // ____//  _// ____// / / // __ \ /   | /_  __//  _// __ \ / | / /
 / /    / /| |    / /    / / / //  |/ // /_    / / / / __ / / / // /_/ // /| |  / /   / / / / / //  |/ / 
/ /___ / ___ |   / /___ / /_/ // /|  // __/  _/ / / /_/ // /_/ // _, _// ___ | / /  _/ / / /_/ // /|  /  
\____//_/  |_|   \____/ \____//_/ |_//_/    /___/ \____/ \____//_/ |_|/_/  |_|/_/  /___/ \____//_/ |_/   
                                                                                                         "
echo "   __  __ ______ ____ __     ____ ________  __
  / / / //_  __//  _// /    /  _//_  __/\ \/ /
 / / / /  / /   / / / /     / /   / /    \  / 
/ /_/ /  / /  _/ / / /___ _/ /   / /     / /  
\____/  /_/  /___//_____//___/  /_/     /_/   
                                              "


while true; do
	echo "Enter the IP address of the VPN server you are working with"
	read -p $prompt serverIP

	echo "Confirm (Y or N) that the entered IP ($serverIP) is correct"
	read -p $prompt userInput
	shopt -s nocasematch
	if [[ $userInput == "y" ]]; then
		break
	elif [[ $userInput == "n" ]]; then
		echo -e "${YELLOW}Please try again${NC}"
	else
		echo -e "${RED}unrecognized input${NC}"
	fi
done

while true; do
	echo -e "\n\n${BLUE}===================== Main Menu =====================${NC}"
	echo "(1) Sign a certificate for new client"
	echo "(2) Revoke a client certificate"
	echo "Any other input to quit"

	# Wait for menu selection.
	read -p $prompt MenuInput

	case $MenuInput in

		1)
			# Advise user to run the OpenVPNConfiguration scrip on the OpenVPN server first then wait for confirmation.
			echo "Please make sure to run the ./OpenVPNConfiguration script onf the OpenVPN server using the Create new client option first."
			read -p "Press enter to continue."

			# Get the same username used in the privious script from the user.
			echo "Please enter the same username that was used in the VPNConfig script"
			read -p $prompt Username

			# Check to make sure certificate request is in the /tmp directory.
			if [ ! -f /tmp/$Username.req ]; then
				echo -e "${RED}FILE MISSING ERROR - /tmp/$Username.req is missing${NC}"
				exit 2
			fi

			# Import and sign the client certificate request.
			$EASYRSADIR/easyrsa import-req /tmp/$Username.req $Username
			$EASYRSADIR/easyrsa sign-req client $Username

			# Copy signed client certificate back to the VPN server.
			scp $EASYRSADIR/pki/issued/$Username.crt user@${serverIP}:/tmp
			if [ $? -ne 0 ]; then
				echo -e "${RED}SECURE COPY ERROR - Secure copy to VPN server failed.${NC}"
				exit 3
			fi
			echo "The client certificate has been sign and sent back to the OpenVPN server."
			echo "Please return to the VPN server terminal window to continue the OpenVPNConfiguration script."
			;;
		2)
			# Get username to be revoked.
			echo "Please enter the username that needs to be revoked"
			read -p $prompt Username

			# Check to make sure certificate request is in the /tmp directory.
			if [ ! -f $EASYRSADIR/pki/issued/$Username.crt ]; then
				echo -e "${RED}FILE MISSING ERROR - $EASYRSADIR/pki/issued/$Username.crt is missing${NC}"
				exit 2
			fi

			# Revoke user and generate a new crl.pem file.
			$EASYRSADIR/easyrsa revoke $Username
			$EASYRSADIR/easyrsa gen-crl

			# Copy the new crl.pem file to the VPN server.
			scp $EASYRSADIR/pki/crl.pem user@${serverIP}:/tmp
			if [ $? -ne 0 ]; then
				echo -e "${RED}SECURE COPY ERROR - Secure copy to VPN server failed.${NC}"
			fi
			;;
		3)
			echo -e "${BLUE}=============== Advanced Options Menu ===============${NC}"
			echo "(1) retry secure copy after signing a request"
			echo "(2) retry secure copy after revoking a request"

			# Wait for user to select a menu item.
			read -p $prompt AdvancedMenuInput
			case $AdvancedMenuInput in

				1)
					# Get the same username used to sign the certificate.
					echo "Please enter the Username that your are creating a certificate for"
					read -p $prompt Username

					# Copy signed client certificate back to the VPN server.
					scp $EASYRSADIR/pki/issued/$Username.crt user@192.168.1.210:/tmp
					if [ $? -ne 0 ]; then
						echo "SECURE COPY ERROR - Secure copy to VPN server failed."
						exit 3
					fi
					;;
				2)
					# Copy the new crl.pem file to the VPN server.
					scp $EASYRSADIR/pki/crl.pem user@192.168.1.210:/tmp
					if [ $? -ne 0 ]; then
						echo "SECURE COPY ERROR - Secure copy to VPN server failed."
						exit 3
					fi
					;;
				*)
					echo "Good-bye!"
					exit 0
					;;
			esac
			;;
		*)
			echo -e "${RED}Unrecognized Input!${NC}"
			;;
	esac

	echo "Would you like to quit? (Y or N)"
	read -p $prompt userInput
	if [[ $userInput != "n" ]]; then
		break
	fi

done

echo "Good-bye!"
exit 0