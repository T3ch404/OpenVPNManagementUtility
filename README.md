# OpenVPNManagementUtility
These two scripts are designed to make building and removing OpenVPN clients easier. They work under the assumption that you built your VPN and CA server according to the Digital Ocean guild here: https://www.digitalocean.com/community/tutorials/how-to-set-up-and-configure-an-openvpn-server-on-ubuntu-20-04

<h2>Setup and Usage</h2>
There are two scripts in the github project. One of them is for the VPN server and the other is for the CA server. Run the following commands on the appropriate server in order to get up and running.

<b>Run on both servers</b>

<code>git clone https://github.com/T3ch404/OpenVPNManagementUtility.git</code>

<b>Run on the OpenVPN server</b>

<pre>
cp OpenVPNManagementUtility/OpenVPNConfiguration.sh easy-rsa/
cd easy-rsa/
chmod +x OpenVPNConfiguration.sh
sudo ./OpenVPNConfiguration.sh
</pre>

<b>Run on the CA server</b>

<pre>
cp OpenVPNManagementUtility/CAconfig.sh easy-rsa/
cd easy-rsa/
chmod +x CAconfig.sh
sudo ./CAconfig.sh
</pre>

These scripts must be run with sudo from the ~/Easy-rsa directory that was created while building the OpenVPN server. It doesn't matter which script is run first as it will walk you through each step of the selected process.
