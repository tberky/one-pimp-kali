#!/bin/bash

# System update
system_update() {
    echo "Full system update:"
    sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y && sudo DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
    sudo timedatectl set-timezone Europe/Prague
    echo "System update finnished"
}

# Install tools
install_default() {
    echo "Installing default apps:"
    sudo apt install -y \
        realtek-rtl88xxau-dkms \
        autoconf \
        automake \
        neofetch \
        golang \
	jython \
	maven \
        powershell \
        xclip \
	remmina
    mkdir ~/Git
# Add path for Go binaries
    cat profile_additions.txt >> $HOME/.profile
    echo "Default apps installed"
}

# Install tools and DBs
install_tools() {
    echo "Installing tools and repos:"
    sudo apt install -y \
        seclists
    # Install golang packages
    go install github.com/projectdiscovery/cvemap/cmd/cvemap@latest
    # Git tools and packages
    git clone https://github.com/projectdiscovery/nuclei-templates.git $HOME/Git/nuclei-templates
    git clone https://github.com/peass-ng/PEASS-ng.git $HOME/Git/PEAS-ng
    echo "Tools installed"
    # Tools adjustments and preparations
    sudo msfdb init
}

# Install network tools
install_tools_network() {
    echo "Installing network tools:"
    sudo apt install -y \
        yersinia \
        zaproxy \
        nuclei \
        naabu \
        bettercap \
        sipvicious \
	    ssh-audit \
        freeradius
}

# Install wireless tools
install_tools_wireless() {
    echo "Installing wireless tools:"
    sudo apt install -y \
        eaphammer \
        horst \
        asleap \
        hostapd-mana \
	gpsd-clients \
	gpsd-tools \
	gpsd
    git clone https://github.com/Kismon/kismon.git $HOME/Git/kismon
# Add kali user to Kismet group
    sudo usermod -aG kismet kali
}

# Install web tools
install_tools_web() {
    echo "Installing web tools:"
    sudo apt install -y \
        gobuster \
        cyberchef \
        seclists \
        subfinder \
        httpx-toolkit \
        beef-xss
# Install Katana crawler
    go install github.com/projectdiscovery/katana/cmd/katana@latest
# add Burp Suite Pro in future?
}

#Install osint tools
install_tools_osint() {
    echo "Installing osint tools:"
    sudo apt update
    echo "Installing Bluto"
    sudo apt install python2.7
    curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py
    sudo runuser -u root -- python2.7 get-pip.py
    rm get-pip.py
    sudo runuser -u root -- pip2 install --upgrade setuptools
    sudo runuser -u root -- pip2 install bluto
    echo "Installing Amass 3.23.3"
    sudo apt remove amass -y
    wget https://github.com/owasp-amass/amass/releases/download/v3.23.3/amass_Linux_amd64.zip
    unzip amass_Linux_amd64.zip
    sudo mv amass_Linux_amd64/amass /usr/local/bin/
    rm -r amass*
    echo "Installing sublist3r"
    sudo apt install sublist3r -y
}

# SSH, RDP and Fail2Ban
remote_access() {
    echo "SSH keys reconfiguration"
    sudo mkdir /etc/ssh/old_keys
    sudo mv /etc/ssh/ssh_host_* /etc/ssh/old_keys
    sudo dpkg-reconfigure openssh-server
    echo "SSH keys reconfiguration done"
    echo "setup remote access with firewall"
    sudo apt install -y \
        xrdp \
        ufw \
        fail2ban
    sudo systemctl enable ssh
    sudo systemctl start ssh
    sudo systemctl enable xrdp
    sudo systemctl start xrdp
    # Instalation and setting up Fail2Ban
    sudo apt install fail2ban
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
    # add ufw with allowed SSH access
    sudo ufw default allow incoming
    sudo ufw default allow outgoing
    # nessus and greenbone deny
    sudo ufw deny 8834
    sudo ufw deny 9392
    sudo ufw allow OpenSSH # just sanity check if someone would change default incoming
    sudo ufw enable
    echo "firewall and remote access installed and configured"
}

# Install VSCode
vscode_install() {
    echo "VSCode installation"
    # MS apt repository and key manual installation
    sudo apt install -y \
        wget \
        gpg
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    rm -f packages.microsoft.gpg
    # Update the package cache and install the package using
    sudo apt install -y \
        apt-transport-https
    sudo apt clean -y && sudo apt autoclean -y && sudo apt autoremove -y && sudo apt update -y
    sudo apt install -y code # or code-insiders
    # Set vscode as default editor
    sudo update-alternatives --set editor /usr/bin/code
    echo "VSCode installed"
}

# Install Nessus
nessus_install() {
    echo "Installing Nessus"
    nessus_latest_deb=$(curl -s https://www.tenable.com/downloads/api/v1/public/pages/nessus | grep -Po 'Nessus-\d+\.\d+\.\d+-debian10_amd64\.deb' | head -n 1)
    sudo curl -o /tmp/$nessus_latest_deb --request GET https://www.tenable.com/downloads/api/v2/pages/nessus/files/$nessus_latest_deb
    sudo dpkg -i /tmp/$nessus_latest_deb
    sudo systemctl enable nessusd
    sudo systemctl start nessusd
    echo "Nessus Installed"
}

# Install Greenbone
greenbone_install() {
    echo "Updating (apt update && apt upgrade)"
    sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
    echo "Installation of GVM services"
    sudo apt install -y gvm*
    echo "Changing default ports of postgresql, so GVM uses postgresql 17"
    sudo sed -i 's/^port = 5432/port = 5433/' "/etc/postgresql/16/main/postgresql.conf"
    sudo sed -i 's/^port = 5433/port = 5432/' "/etc/postgresql/17/main/postgresql.conf"
    sudo systemctl restart postgresql
    echo "GVM installation"
    sudo gvm-setup
    echo "Updating GVM feeds"
    sudo runuser -u _gvm -- greenbone-nvt-sync --rsync
    sudo greenbone-scapdata-sync
    sudo greenbone-certdata-sync
    sudo greenbone-feed-sync --type GVMD_DATA
    echo "Starting and enabling GVM services"
    sudo systemctl enable gsad.service
    sudo systemctl start gsad.service
    sudo systemctl enable gvmd.service
    sudo systemctl start gvmd.service
    sudo systemctl enable ospd-openvas.service
    sudo systemctl start ospd-openvas.service
    echo "Creating user kali:kali"
    sudo runuser -u _gvm -- gvmd --create-user=kali --password=kali
    echo "Changing options to set access not only from localhost"
    sudo sed -i 's/127.0.0.1/0.0.0.0/' /usr/lib/systemd/system/greenbone-security-assistant.service
    sudo systemctl daemon-reload
}

# tmux configuration
tmux_config() {
    sudo apt update
    echo ".zshrc file additions"
    cat zshrc_additions.txt >> ~/.zshrc
    echo ".zshrc additions complete"
    echo "tmux configuration"
    sudo apt install -y xsel
    git clone https://github.com/mauzk0/one-tmux-conf.git $HOME/Git/one-tmux-conf
    ln -s ~/Git/one-tmux-conf/.tmux.conf ~/.tmux.conf
    echo "tmux configuration ready"
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        echo "Installation of TPM (Tmux Plugin Manager)..."
        git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm
    else
        echo "TPM already installed."
    fi

    # Add configuration to .tmux.conf, if it does not exist yet
    TMUX_CONF="$HOME/.tmux.conf"
    if ! grep -q "set -g @plugin 'tmux-plugins/tmux-resurrect'" "$TMUX_CONF"; then
        echo "Adding configuration of tmux-resurrect to .tmux.conf..."
        cat <<EOL >> "$TMUX_CONF"

    # Tmux Plugin Manager
    set -g @plugin 'tmux-plugins/tmux-resurrect'

    # Initialization TPM
    run '~/.tmux/plugins/tpm/tpm' 
EOL
        else
            echo "Configuration of tmux-resurrect already exists in .tmux.conf."
        fi

        # Plugin installation using TPM
        echo "\Installation of tmux-resurrect using TPM..."
        ~/.tmux/plugins/tpm/bin/install_plugins

        echo "Instalace tmux-resurrect dokončena!"
    }

    # clean
    clean() {
        sudo apt clean -y && sudo apt autoclean -y && sudo apt autoremove -y
    }

    do_everything() {
        system_update
        install_default
        install_tools
        install_tools_network
        install_tools_wireless
        install_tools_web
        install_tools_osint
	    remote_access
	    vscode_install
	    nessus_install
        greenbone_install
	    tmux_config
}


# Menu
while true; do
    clear
    echo "========== One-Kali-Setup Menu =========="
    echo "1) Installation of tools and system update"
    echo "2) Remote access configuration + firewall"
    echo "3) VSCode installation"
    echo "4) Nessus installation"
    echo "5) Greenbone installation"
    echo "6) TMUX configuration"
    echo "7) Everything"
    echo "8) Exit"
    echo "========================================"
    read -p "Choose an option (1-8): " choice

    case $choice in
        1)
            # Submenu for tool installation
            while true; do
                clear
                echo "========== Install Tools Menu =========="
                echo "1) System update only"
                echo "2) Install default tools"
                echo "3) Install network tools"
                echo "4) Install wireless tools"
                echo "5) Install web tools"
                echo "6) Install OSINT tools"
                echo "7) Install all tools"
                echo "8) Return to main menu"
                echo "========================================"
                read -p "Choose an option (1-8): " tool_choice

                case $tool_choice in
                    1)
                        system_update
                        ;;
                    2)
                        install_default
                        install_tools
                        ;;
                    3)
                        install_tools_network
                        ;;
                    4)
                        install_tools_wireless
                        ;;
                    5)
                        install_tools_web
                        ;;
                    6)
                        install_tools_osint
                        ;;
                    7)  
                        system_update
                        install_default
                        install_tools
                        install_tools_network
                        install_tools_wireless
                        install_tools_web
                        install_tools_osint
                        ;;
                    8)
                        break  # Return to main menu
                        ;;
                    *)
                        echo "Invalid option, try again."
                        ;;
                esac
                read -p "Press Enter to continue..."
            done
            ;;
        2)
            remote_access
            ;;
        3)
            vscode_install
            ;;
        4)
            nessus_install
            ;;
        5)
            greenbone_install
            ;;
        6)
            tmux_config
            ;;
        7)
            do_everything
            ;;
        8)
            echo "Cleaning..."
            clean
            echo "Exiting script."
            exit 0
            ;;
        *)
            echo "Invalid option, try again."
            ;;
    esac
    read -p "Press Enter to return to the menu..."
done
