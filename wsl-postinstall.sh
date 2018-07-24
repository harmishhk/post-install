#!/bin/bash -eux

# options for installation
opts=(update tools theme docker dev)

# set umask
umask 0022

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
wsl_update() {
  # fix for WLS-Ubuntu1804
  sudo cp -p  /bin/true /sbin/ebtables

  # now updating distro
  echod "performing update (all packages and kernel)"
  sudo apt-get update
  sudo apt-get -y upgrade
  sudo apt-get -y dist-upgrade
}

# function for installing tools
wsl_tools() {
  # install basic tools
  echod "installing basic tools"
  sudo apt-get -y install apache2 chrony curl gdebi htop openssh-server tmux tree vim wget

  # install editor/coding tools
  echod "installing programming tools"
  sudo apt-get -y install build-essential gdb llvm-dev clang

  # install image tools
  echod "installing image and additional tools"
  sudo apt-get -y install jpegoptim libimage-exiftool-perl

  # install git and git-lfs
  echod "installing git and related tools"
  sudo add-apt-repository -y ppa:git-core/ppa
  sudo apt-get update
  sudo apt-get -y install git git-svn gitk tig
  curl -s -o /tmp/git-lfs.sh https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh
  sudo bash /tmp/git-lfs.sh
  sudo apt-get -y install git-lfs
  git lfs install

  echod "installing conda"
  https://repo.anaconda.com/archive/Anaconda3-5.2.0-Linux-x86_64.sh
  wget -O /tmp/conda.sh https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
  bash /tmp/conda.sh -b -p $HOME/conda

  # install and setup zsh
  echod "installing and setting-up z-shell"
  sudo apt-get -y install zsh
  zsh --version
  git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
  sed -i -e 's/➜/➡/g' ~/.oh-my-zsh/themes/robbyrussell.zsh-theme
  sed -i -e 's/✗/⌧/g' ~/.oh-my-zsh/themes/robbyrussell.zsh-theme
}

wsl_theme() {
  # fonts
  echod "installing and setting up fonts"
  sudo apt-get -y install gconf2 unzip wget
  mkdir -p ~/.fonts/installed
  LATEST_FONTAWESOME_VERSION=$(curl -L -s -H 'Accept: application/json' https://github.com/FortAwesome/Font-Awesome/releases/latest | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
  wget -O ~/.fonts/fontawesome.zip https://github.com/FortAwesome/Font-Awesome/releases/download/$LATEST_FONTAWESOME_VERSION/fontawesome-free-$LATEST_FONTAWESOME_VERSION-desktop.zip
  unzip -d ~/.fonts ~/.fonts/fontawesome.zip
  wget -O ~/.fonts/selawik.zip https://github.com/Microsoft/Selawik/releases/download/1.01/Selawik_Release.zip
  unzip -d ~/.fonts ~/.fonts/selawik.zip
  LATEST_FIRACODE_VERSION=$(curl -L -s -H 'Accept: application/json' https://github.com/tonsky/firacode/releases/latest | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
  wget -O ~/.fonts/firacode.zip https://github.com/tonsky/firacode/releases/download/$LATEST_FIRACODE_VERSION/FiraCode_$LATEST_FIRACODE_VERSION.zip
  unzip -d ~/.fonts ~/.fonts/firacode.zip
  find ~/.fonts -name "* *" -print0 | sort -rz | while read -d $'\0' f; do mv -v "$f" "$(dirname "$f")/$(basename "${f// /_}")"; done
  find ~/.fonts -name "*.otf" -or -name "*.ttf" | xargs cp --target-directory=$HOME/.fonts/installed
  find ~/.fonts -mindepth 1 -maxdepth 1 -not -name "installed" -exec rm -rf {} +
  sudo fc-cache -f -v
}

wsl_docker() {
  sudo apt-get -y install wget tar
  echod "installing docker client"
  wget -O /tmp/go.tar.gz https://dl.google.com/go/go1.10.3.linux-amd64.tar.gz
  tar -xf /tmp/go.tar.gz -C /tmp
  PATH=$PATH:/tmp/go/bin
  go get -d github.com/jstarks/npiperelay
  WUser="$(powershell.exe '$env:UserName' | tr -d '\r')"
  GOOS=windows go build -o /mnt/c/Users/$WUser/AppData/Local/go/bin/npiperelay.exe github.com/jstarks/npiperelay
  sudo ln -s /mnt/c/Users/$WUser/AppData/Local/go/bin/npiperelay.exe /usr/local/bin/npiperelay.exe
  rm -rf ~/go
  sudo apt-get -y install socat docker.io
  sudo adduser ${USER} docker
  wget -O ~/docker-relay https://gist.githubusercontent.com/harmishhk/312d9d6fa281c971a591dc61416d993f/raw/ee421c7f8a7f749a9001712febe86924c1fd5e9d/docker-wsl-relay
  chmod +x ~/docker-relay

  echod "installing docker-machine"
  LATEST_DOCKERMACHINE_VERSION=$(curl -L -s -H 'Accept: application/json' https://github.com/docker/machine/releases/latest | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
  sudo wget -O /usr/local/bin/docker-machine https://github.com/docker/machine/releases/download/$LATEST_DOCKERMACHINE_VERSION/docker-machine-`uname -s`-`uname -m`
  sudo chmod +x /usr/local/bin/docker-machine

  echod "installing docker-compose"
  LATEST_DOCKERCOMPOSE_VERSION=$(curl -L -s -H 'Accept: application/json' https://github.com/docker/compose/releases/latest | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
  sudo wget -O /usr/local/bin/docker-compose https://github.com/docker/compose/releases/download/$LATEST_DOCKERCOMPOSE_VERSION/docker-compose-`uname -s`-`uname -m`
  sudo chmod +x /usr/local/bin/docker-compose
}

wsl_ros() {
  ROS_VERSION=melodic
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

wsl_dev() {
  # install dotfiles
  echod "installing dotfiles"
  git clone https://github.com/harmishhk/dotfiles ~/dotfiles
  source ~/dotfiles/install.sh

  # password less sudo-ing
  echod "==> enabling password-less sudo-ing"
  sudo mkdir -p /etc/sudoers.d
  sudo touch /etc/sudoers.d/$USER
  sudo sh -c "echo '$USER ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/$USER"
}

# now execute given options
for i in "${!opts[@]}"; do
  if [ -n "$(type -t wsl_${opts[$i]})" ] && [ "$(type -t wsl_${opts[$i]})" = function ]; then
    wsl_${opts[$i]}
  else
    echod "option ${opts[$i]} is invalid"
  fi
done

unset -f wsl_update
unset -f wsl_tools
unset -f wsl_theme
unset -f wsl_docker
unset -f wsl_ros
unset -f wsl_dev
