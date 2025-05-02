# ospf-latensy-cost-autocalc - linux

Response service similar to the one in the folder above, but for linux+frr, works independently. See the general README for parameters and script purpose.

## install
1. It is highly recommended to run the service under a non-root user, but with the `frr`, `frrvty` groups:
  - `sudo usermod -aG frr,frrvty $USER` \
then re-login to the session
2. Install dependencies
  - `sudo apt install python3-pip -y && pip install ping3 -y`
3. Create the script file
  - `nano ospf-latensy-cost-autocalc.py`  
paste the contents of the file with the same name and make it executable  
  - `chmod +x ospf-latensy-cost-autocalc.py`
4. Create the service
  - `systemctl edit --force --full --user ospf-latensy-cost-autocalc.service`  
paste the contents of the file with the same name
5. Create the timer
  - `systemctl edit --force --full --user ospf-latensy-cost-autocalc.timer`  
paste the contents of the file with the same name
6. Start the service
  - `systemctl enable --now --user ospf-latensy-cost-autocalc.timer`  
check status  
  - `systemctl status --user ospf-latensy-cost-autocalc.service`