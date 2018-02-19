#!/bin/bash -eux

# options for installation
opts=(update hyperv tools i3 theme docker dev)

# set-up logging
LOGFILE=/tmp/ubuntu-postinstall.txt
touch $LOGFILE
echod() {
  echo "" 2>&1 | tee -a $LOGFILE
  echo "==> $(date)" 2>&1 | tee -a $LOGFILE
  echo "==> $@" 2>&1 | tee -a $LOGFILE
}

# function for updating ubuntu installation
ubuntu_update() {
  echod "performing update (all packages and kernel)"
  sudo apt-get update
  sudo apt-get -y upgrade
  sudo apt-get -y dist-upgrade
}

# function for instlling hyperv additions
ubuntu_hyperv() {
  echod "installing hyperv related packages"
  sudo apt-get update
  sudo apt-get -y install gdebi wget
  sudo apt-get -y install \
    linux-virtual-lts-xenial \
    linux-tools-virtual-lts-xenial \
    linux-cloud-tools-virtual-lts-xenial

  echod "setting up remote desktop servers"
  wget -O /tmp/tigervnc.deb https://dl.bintray.com/tigervnc/stable/ubuntu-16.04LTS/amd64/tigervncserver_1.7.1-1ubuntu1_amd64.deb
  sudo gdebi -n /tmp/tigervnc.deb
  sudo apt-get install -y xrdp

  # fix for xrdp envornment variables
  sudo sh -c "sed -i '/. \/etc\/X11\/Xsession/i . \/etc\/environment\\n. ~\/.profile' /etc/xrdp/startwm.sh"

  # start i3 by default for rdp session
  echo "i3" > ~/.xsession

  # fix for us-intl keyboard with xrdp
  sudo mv /etc/xrdp/km-0409.ini /etc/xrdp/km-0409.ini.bak
  wget -O /tmp/km-0409.ini https://gist.githubusercontent.com/harmishhk/87a1d39c6f346287ea963cb609a09fa0/raw/55262e0963e566149cb486e40ebca4cae06e00ce/km-0409.ini
  sudo mv -f /tmp/km-0409.ini /etc/xrdp/km-0409.ini
  sudo chown xrdp:xrdp /etc/xrdp/km-0409.ini
}

# function for installing tools
ubuntu_tools() {
  # install basic tools
  echod "installing basic tools"
  sudo apt-get -y install htop openssh-server tmux tree vim wget curl gdebi

  # install editor/coding tools
  echod "installing programming tools"
  sudo apt-get -y install build-essential gdb llvm-dev clang pylint python-autopep8

  # install git and git-lfs
  echod "installing git and related tools"
  sudo add-apt-repository -y ppa:git-core/ppa
  sudo apt-get update
  sudo apt-get -y install git git-svn gitk meld tig git-gui
  curl -s -o /tmp/git-lfs.sh https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh
  sudo bash /tmp/git-lfs.sh
  sudo apt-get -y install git-lfs
  git lfs install

  # install vs-code and extensions
  local CODE_SYNCING_PERSONAL_ACCESS_TOKEN=token
  local CODE_SYNCING_GIST_ID=gistid
  echod "installing visual studio code editor and extensions"
  wget -O /tmp/vscode.deb "https://go.microsoft.com/fwlink/?LinkID=760868"
  sudo gdebi -n /tmp/vscode.deb
  local LATEST_SPELLCHECK_VERSION=$(curl -L -s -H 'Accept: application/json' https://github.com/harmishhk/vscode-spell-check/releases/latest | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
  wget -O /tmp/Spell.vsix https://github.com/harmishhk/vscode-spell-check/releases/download/$LATEST_SPELLCHECK_VERSION/Spell-$LATEST_SPELLCHECK_VERSION.vsix
  code --install-extension /tmp/Spell.vsix
  code --install-extension nonoroazoro.syncing
  local SYNCING_JSON=~/.config/Code/User/syncing.json
  mkdir -p $(dirname $SYNCING_JSON)
  echo "{" > $SYNCING_JSON
  echo "    \"token\": \""$CODE_SYNCING_PERSONAL_ACCESS_TOKEN"\"," >> $SYNCING_JSON
  echo "    \"id\": \""$CODE_SYNCING_GIST_ID"\"" >> $SYNCING_JSON
  echo "}" >> $SYNCING_JSON

  # install and setup zsh
  echod "installing and setting-up z-shell"
  sudo apt-get -y install zsh
  zsh --version
  git clone git://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
  sudo chsh $USER -s $(grep /zsh$ /etc/shells | tail -1)
}

# function to install i3 wm
ubuntu_i3() {
  echod " installing i3 window manager"
  sudo sh -c "echo 'deb http://debian.sur5r.net/i3/ $(lsb_release -c -s) universe' >> /etc/apt/sources.list.d/i3.list"
  sudo apt-get update
  sudo apt-get --allow-unauthenticated install sur5r-keyring
  sudo apt-get update
  sudo apt-get -y install i3
  local I3_LIGHTDM_CONF=/etc/lightdm/lightdm.conf.d/50-i3.conf
  sudo mkdir -p $(dirname $I3_LIGHTDM_CONF)
  sudo sh -c "echo '[SeatDefaults]' >> $I3_LIGHTDM_CONF"
  sudo sh -c "echo 'user-session=i3' >> $I3_LIGHTDM_CONF"

  # i3blocks for i3wm
  echod "installing i3bocks for better i3 status bar"
  sudo apt-get -y install acpi rsync ruby-ronn i3lock imagemagick scrot
  git clone https://github.com/vivien/i3blocks.git /tmp/i3blocks
  make -C /tmp/i3blocks clean debug
  sudo make -C /tmp/i3blocks install
  mkdir -p ~/.config/i3blocks/scripts
  cp /tmp/i3blocks/scripts/* ~/.config/i3blocks/scripts
  git clone https://github.com/guimeira/i3lock-fancy-multimonitor.git /tmp/i3lock-fancy-multimonitor
  rsync -r --exclude='.git' /tmp/i3lock-fancy-multimonitor ~/.config
  sed -i "s/^BLURTYPE=.*/BLURTYPE=\"0x8\"/g" ~/.config/i3lock-fancy-multimonitor/lock

  # tools for i3wm
  echod "installing some i3 related tools"
  sudo apt-get -y install arandr compton lxappearance thunar
}

# function for theming gui components
ubuntu_theme() {
  # fonts
  echod "installing and setting up fonts"
  sudo add-apt-repository -y ppa:no1wantdthisname/ppa
  sudo apt-get update
  sudo apt-get -y install fontconfig-infinality unzip wget
  sudo ln -s /etc/fonts/infinality/conf.d /etc/fonts/infinality/styles.conf.avail/linux
  mkdir -p ~/.fonts
  local LATEST_FONTAWESOME_VERSION=$(curl -L -s -H 'Accept: application/json' https://github.com/FortAwesome/Font-Awesome/releases/latest | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
  wget -O ~/.fonts/fontawesome.zip https://github.com/FortAwesome/Font-Awesome/releases/download/$LATEST_FONTAWESOME_VERSION/fontawesome-free-$LATEST_FONTAWESOME_VERSION.zip
  unzip -d ~/.fonts ~/.fonts/fontawesome.zip
  wget -O ~/.fonts/inconsolata.zip http://www.fontsquirrel.com/fonts/download/Inconsolata
  unzip -d ~/.fonts ~/.fonts/inconsolata.zip
  wget -O ~/.fonts/selawik.zip https://github.com/Microsoft/Selawik/releases/download/1.01/Selawik_Release.zip
  unzip -d ~/.fonts ~/.fonts/selawik.zip
  local LATEST_IOSEVKA_VERSION=$(curl -L -s -H 'Accept: application/json' https://github.com/be5invis/iosevka/releases/latest | sed -e 's/.*"tag_name":"v\([^"]*\)".*/\1/')
  wget -O ~/.fonts/iosevka.zip https://github.com/be5invis/Iosevka/releases/download/v$LATEST_IOSEVKA_VERSION/01-iosevka-$LATEST_IOSEVKA_VERSION.zip
  unzip -d ~/.fonts ~/.fonts/iosevka.zip
  local LATEST_FIRACODE_VERSION=$(curl -L -s -H 'Accept: application/json' https://github.com/tonsky/firacode/releases/latest | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
  wget -O ~/.fonts/firacode.zip https://github.com/tonsky/firacode/releases/download/$LATEST_FIRACODE_VERSION/FiraCode_$LATEST_FIRACODE_VERSION.zip
  unzip -d ~/.fonts ~/.fonts/firacode.zip
  find . -not -name "*.otf" -not -name "*.ttf" -not -type d | xargs rm
  sudo fc-cache -f -v
  echo "gsettings set org.gnome.desktop.interface font-name 'Selawik 9'" >> ~/.xprofile
  echo "gsettings set org.gnome.desktop.interface monospace-font-name 'Inconsolata Medium 12'" >> ~/.xprofile

  # gtk theme
  echod "installing numix theme"
  sudo add-apt-repository -y ppa:numix/ppa
  sudo apt-get update
  sudo apt-get -y install gnome-settings-daemon lxappearance numix-gtk-theme numix-icon-theme-circle
  echo "gsettings set org.gnome.desktop.interface gtk-theme 'Numix'" >> ~/.xprofile
  echo "gsettings set org.gnome.desktop.wm.preferences theme 'Numix'" >> ~/.xprofile
  echo "gsettings set org.gnome.desktop.interface icon-theme 'Numix-Circle'" >> ~/.xprofile
  echo "gconftool-2 --type=string --set /desktop/gnome/interface/gtk_theme 'Numix'" >> ~/.xprofile
  echo "gsettings set org.gnome.settings-daemon.plugins.cursor active false" >> ~/.xprofile

  # wallpaper
  echo "setting-up bing wallpaper"
  sudo apt-get -y install curl feh gawk
  git clone https://github.com/harmishhk/bing-wallpaper ~/software/bing-wallpaper
  sh ~/software/bing-wallpaper/setup.sh ~/software/bing-wallpaper
  echo "~/software/bing-wallpaper/bing-wallpaper.sh 2>&1 > /dev/null" >> ~/.xprofile

  # terminal
  echo "setting-up terminal theme"
  sudo apt-get -y install git gnome-terminal python-pygments wget
  wget -O ~/.Xresources https://raw.githubusercontent.com/chriskempson/base16-xresources/master/xresources/base16-tomorrow-night-256.Xresources
  git clone https://github.com/aaron-williamson/base16-gnome-terminal.git ~/.config/base16-gnome-terminal
  chmod a+x ~/.config/base16-gnome-terminal/color-scripts/base16-tomorrow-night-256.sh
  ~/.config/base16-gnome-terminal/color-scripts/base16-tomorrow-night-256.sh
  git clone https://github.com/chriskempson/base16-shell.git ~/.config/base16-shell
  gsettings set org.gnome.Terminal.Legacy.Settings default-show-menubar false
  local PUUID=$(gsettings get org.gnome.Terminal.ProfilesList default | cut -d "'" -f 2)
  gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PUUID/ audible-bell false
  gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PUUID/ font "Iosevka 11"
  gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PUUID/ login-shell true
  gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PUUID/ scrollback-unlimited true
  gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PUUID/ scrollbar-policy "never"
  gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PUUID/ use-system-font false
  gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PUUID/ use-theme-transparency false
}

# function to install and setup docker
ubuntu_docker() {
  sudo apt-get -y install wget tar
  echod "installing docker"
  sudo apt-get update
  sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg > /tmp/dockerkey
  sudo apt-key add /tmp/dockerkey
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt-get update
  sudo apt-get -y install docker-ce

  # run example docker container, making sure docker is working
  sudo docker run hello-world

  # create docker group and add user to it
  sudo groupadd docker
  sudo usermod -aG docker $USER

  echod "enabling user-namespace remapping for docker"
  sudo cp /lib/systemd/system/docker.service /etc/systemd/system/
  sudo sed -i "/^ExecStart/ s/$/ --userns-remap=$USER/" /etc/systemd/system/docker.service
  sudo sed -i "s/^$USER.*/$USER:$(id -g):65536/" /etc/subuid
  sudo sed -i "s/^$USER.*/$USER:$(id -g):65536/" /etc/subgid

  echod "installing docker-machine"
  local LATEST_DOCKERMACHINE_VERSION=$(curl -L -s -H 'Accept: application/json' https://github.com/docker/machine/releases/latest | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
  sudo wget -O /usr/local/bin/docker-machine https://github.com/docker/machine/releases/download/$LATEST_DOCKERMACHINE_VERSION/docker-machine-`uname -s`-`uname -m`
  sudo chmod +x /usr/local/bin/docker-machine

  echod "installing docker-compose"
  local LATEST_DOCKERCOMPOSE_VERSION=$(curl -L -s -H 'Accept: application/json' https://github.com/docker/compose/releases/latest | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
  sudo wget -O /usr/local/bin/docker-compose https://github.com/docker/compose/releases/download/$LATEST_DOCKERCOMPOSE_VERSION/docker-compose-`uname -s`-`uname -m`
  sudo chmod +x /usr/local/bin/docker-compose
}

# function to install ros
ubuntu_ros() {
  local ROS_VERSION=kinetic
  echod "installing ros $ROS_VERSION"

  # setup source-list and keys
  sudo sh -c "echo 'deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main' > /etc/apt/sources.list.d/ros-latest.list"
  sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-key 0xB01FA116
  sudo apt-get update --fix-missing

  # install ros-$ROS_VERSION-desktop
  sudo apt-get -y install \
  ros-$ROS_VERSION-desktop \
  ros-$ROS_VERSION-perception \
  ros-$ROS_VERSION-navigation \
  ros-$ROS_VERSION-joy \
  ros-$ROS_VERSION-teleop-twist-joy \
  python-catkin-tools

  ## setup rosdep
  sudo rosdep init
  rosdep update
}

# function for dev-settings
ubuntu_dev() {
  # install dotfiles
  echod "installing dotfiles"
  git clone https://github.com/harmishhk/dotfiles ~/dotfiles
  source ~/dotfiles/install.sh

  # install image tools
  echo "installing image and additional tools"
  sudo apt-get -y install chrony geeqie gimp inkscape jpegoptim libimage-exiftool-perl

  # password less sudo-ing
  echod "==> enabling password-less sudo-ing"
  sudo mkdir -p /etc/sudoers.d
  sudo touch /etc/sudoers.d/$USER
  sudo sh -c "echo '$USER ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/$USER"

  # add fstab entry for work_vdisk, and related symlinks
  echod "adding fstab entry for work_vdisk and symlinking"
  sudo sh -c "echo '/dev/sdb /mnt/work_vdisk auto defaults 0 0' >> /etc/fstab"
  ln -s /mnt/work_vdisk/work ~/work
  ln -s ~/work/ros ~/ros
  ln -s ~/work/writing ~/writing

  # workaround for networking bug with systemd
  sudo sed -i "s/timeout=[0-9]*/timeout=1/g" /lib/systemd/system/NetworkManager-wait-online.service
  sudo sed -i "/TimeoutStartSec/c\TimeoutStartSec=1sec" /lib/systemd/system/networking.service
}

# now execute given options
for i in "${!opts[@]}"; do
  if [ -n "$(type -t ubuntu_${opts[$i]})" ] && [ "$(type -t ubuntu_${opts[$i]})" = function ]; then
    ubuntu_${opts[$i]}
  else
    echod "option ${opts[$i]} is invalid"
  fi
done

# clean-up
unset -f ubuntu_update
unset -f ubuntu_hyperv
unset -f ubuntu_tools
unset -f ubuntu_i3
unset -f ubuntu_theme
unset -f ubuntu_docker
unset -f ubuntu_ros
unset -f ubuntu_dev
