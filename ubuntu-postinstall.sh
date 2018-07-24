#!/bin/bash -eux

# options for installation
opts=(update tools i3 theme docker dev)

# set-up logging
LOGFILE=$HOME/postinstall.txt
touch $LOGFILE
echod() {
  echo "" 2>&1 | tee -a $LOGFILE
  echo "" 2>&1 | tee -a $LOGFILE
  echo "==> $(date)" 2>&1 | tee -a $LOGFILE
  echo "==> $@" 2>&1 | tee -a $LOGFILE
  echo "" 2>&1 | tee -a $LOGFILE
}

# function for updating ubuntu installation
ubuntu_update() {
  echod "performing update (all packages and kernel)"
  sudo apt-get update
  sudo apt-get -y upgrade
  sudo apt-get -y dist-upgrade
}

# function for installing tools
ubuntu_tools() {
  # install basic tools
  echod "installing basic tools"
  sudo apt-get -y install apache2 chrony curl gdebi htop openssh-server tmux tree vim wget

  # install editor/coding tools
  echod "installing programming tools"
  sudo apt-get -y install build-essential gdb llvm-dev clang

  # install image tools
  echod "installing image and additional tools"
  sudo apt-get -y install geeqie gimp inkscape jpegoptim libimage-exiftool-perl

  # install git and git-lfs
  echod "installing git and related tools"
  sudo add-apt-repository -y ppa:git-core/ppa
  sudo apt-get update
  sudo apt-get -y install git git-svn gitk meld tig git-gui
  curl -s -o /tmp/git-lfs.sh https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh
  sudo bash /tmp/git-lfs.sh
  sudo apt-get -y install git-lfs
  git lfs install

  echod "installing conda"
  https://repo.anaconda.com/archive/Anaconda3-5.2.0-Linux-x86_64.sh
  wget -O /tmp/conda.sh https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
  bash /tmp/conda.sh -b -p $HOME/conda

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
  git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
  sed -i -e 's/➜/➡/g' ~/.oh-my-zsh/themes/robbyrussell.zsh-theme
  sed -i -e 's/✗/⌧/g' ~/.oh-my-zsh/themes/robbyrussell.zsh-theme
  sudo chsh $USER -s $(grep /zsh$ /etc/shells | tail -1)
}

# function to install i3 wm
ubuntu_i3() {
  echod " installing i3 window manager"
  sudo apt-get -y install i3
  touch ~/.Xresources
  grep -q '^Xft.dpi' ~/.Xresources && sed -i 's/^Xft.dpi.*/Xft.dpi: 192/' ~/.Xresources || echo 'Xft.dpi: 192' >> ~/.Xresources
  echo "i3" >> ~/.xsession

  # i3blocks and i3lock for i3wm
  echod "installing i3bocks for better i3 status bar"
  sudo apt-get -y install acpi rsync ruby-ronn i3blocks i3lock imagemagick scrot
  git clone https://github.com/vivien/i3blocks.git /tmp/i3blocks
  mkdir -p ~/.config/i3blocks/scripts
  cp /tmp/i3blocks/scripts/* ~/.config/i3blocks/scripts
  git clone https://github.com/guimeira/i3lock-fancy-multimonitor.git /tmp/i3lock-fancy-multimonitor
  rsync -r --exclude='.git' /tmp/i3lock-fancy-multimonitor ~/.config
  sed -i "s/^BLURTYPE=.*/BLURTYPE=\"0x8\"/g" ~/.config/i3lock-fancy-multimonitor/lock
  chmod a+x ~/.config/i3lock-fancy-multimonitor/lock

  # tools for i3wm
  echod "installing some i3 related tools"
  sudo apt-get -y install arandr compton lxappearance thunar
}

# function for theming gui components
ubuntu_theme() {
  # fonts
  echod "installing and setting up fonts"
  sudo apt-get -y install gconf2 unzip wget
  mkdir -p ~/.fonts/installed
  local LATEST_FONTAWESOME_VERSION=$(curl -L -s -H 'Accept: application/json' https://github.com/FortAwesome/Font-Awesome/releases/latest | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
  wget -O ~/.fonts/fontawesome.zip https://github.com/FortAwesome/Font-Awesome/releases/download/$LATEST_FONTAWESOME_VERSION/fontawesome-free-$LATEST_FONTAWESOME_VERSION-desktop.zip
  unzip -d ~/.fonts ~/.fonts/fontawesome.zip
  wget -O ~/.fonts/selawik.zip https://github.com/Microsoft/Selawik/releases/download/1.01/Selawik_Release.zip
  unzip -d ~/.fonts ~/.fonts/selawik.zip
  local LATEST_FIRACODE_VERSION=$(curl -L -s -H 'Accept: application/json' https://github.com/tonsky/firacode/releases/latest | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
  wget -O ~/.fonts/firacode.zip https://github.com/tonsky/firacode/releases/download/$LATEST_FIRACODE_VERSION/FiraCode_$LATEST_FIRACODE_VERSION.zip
  unzip -d ~/.fonts ~/.fonts/firacode.zip
  find ~/.fonts -name "* *" -print0 | sort -rz | while read -d $'\0' f; do mv -v "$f" "$(dirname "$f")/$(basename "${f// /_}")"; done
  find ~/.fonts -name "*.otf" -or -name "*.ttf" | xargs cp --target-directory=$HOME/.fonts/installed
  find ~/.fonts -mindepth 1 -maxdepth 1 -not -name "installed" -exec rm -rf {} +
  sudo fc-cache -f -v

  # wallpaper
  echod "setting-up bing wallpaper"
  sudo apt-get -y install curl feh gawk
  git clone https://github.com/harmishhk/bing-wallpaper ~/software/bing-wallpaper
  sh ~/software/bing-wallpaper/setup.sh ~/software/bing-wallpaper
  echo "~/software/bing-wallpaper/bing-wallpaper.sh 2>&1 > /dev/null" >> ~/.xprofile

  # terminal
  echod "setting-up terminal theme"
  sudo apt-get -y install git gnome-terminal python-pygments wget
  git clone https://github.com/aaron-williamson/base16-gnome-terminal.git ~/.config/base16-gnome-terminal
  chmod a+x ~/.config/base16-gnome-terminal/color-scripts/base16-tomorrow-night-256.sh
  ~/.config/base16-gnome-terminal/color-scripts/base16-tomorrow-night-256.sh
  git clone https://github.com/chriskempson/base16-shell.git ~/.config/base16-shell
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
  local ROS_VERSION=melodic
  echod "installing ros $ROS_VERSION"

  # setup source-list and keys
  sudo sh -c "echo 'deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main' > /etc/apt/sources.list.d/ros-latest.list"
  curl -fsSL "http://ha.pool.sks-keyservers.net/pks/lookup?op=get&search=0x421C365BD9FF1F717815A3895523BAEEB01FA116" > /tmp/roskey
  sudo apt-key add /tmp/roskey
  sudo apt-get update

  # install ros-$ROS_VERSION-desktop
  sudo apt-get -y install \
  ros-$ROS_VERSION-desktop \
  ros-$ROS_VERSION-perception \
  ros-$ROS_VERSION-joy \
  python-catkin-tools
  # ros-$ROS_VERSION-navigation \
  # ros-$ROS_VERSION-teleop-twist-joy \

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
