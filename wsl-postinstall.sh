#!/bin/bash -eux

# options for installation
opts=(update tools theme docker dev)

# set umask
umask 0022

# set-up logging
LOGFILE=/tmp/WSL-postinstall.txt
touch $LOGFILE
echod() {
  echo "" 2>&1 | tee -a $LOGFILE
  echo "==> $(date)" 2>&1 | tee -a $LOGFILE
  echo "==> $@" 2>&1 | tee -a $LOGFILE
}

# function for updating ubuntu installation
wsl_update() {
  echod "performing update (all packages and kernel)"
  sudo apt-get update
  sudo apt-get -y dist-upgrade
}

# function for installing tools
wsl_tools() {
  # install basic tools
  echod "installing basic tools"
  sudo apt-get -y install curl gdebi htop openssh-server tmux tree vim wget

  # install editor/coding tools
  echod "installing programming tools"
  sudo apt-get -y install build-essential gdb llvm-3.6-dev clang-3.6 pylint python-autopep8

  # install git and git-lfs
  echod "installing git and related tools"
  sudo add-apt-repository -y ppa:git-core/ppa
  sudo apt-get update
  sudo apt-get -y install git git-svn gitk tig
  curl -s -o /tmp/git-lfs.sh https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh
  sudo bash /tmp/git-lfs.sh
  sudo apt-get -y install git-lfs
  git lfs install

  # install and setup zsh
  echod "installing and setting-up z-shell"
  sudo apt-get -y install zsh
  zsh --version
  git clone git://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
  # sudo chsh $USER -s $(grep /zsh$ /etc/shells | tail -1)
}

wsl_theme() {
  echod "installing and setting up fonts"
  sudo add-apt-repository -y ppa:no1wantdthisname/ppa
  sudo apt-get update
  sudo apt-get -y install fontconfig-infinality unzip wget
  sudo ln -s /etc/fonts/infinality/conf.d /etc/fonts/infinality/styles.conf.avail/linux
  mkdir -p ~/.fonts
  wget -O ~/.fonts/fontawesome-webfont.ttf https://github.com/FortAwesome/Font-Awesome/raw/master/fonts/fontawesome-webfont.ttf
  wget -O ~/.fonts/inconsolata.zip http://www.fontsquirrel.com/fonts/download/Inconsolata
  unzip -d ~/.fonts ~/.fonts/inconsolata.zip
  wget -O ~/.fonts/selawik.zip https://github.com/Microsoft/Selawik/releases/download/1.01/Selawik_Release.zip
  unzip -d ~/.fonts ~/.fonts/selawik.zip
  file ~/.fonts/* | grep -vi 'ttf\|otf' | cut -d: -f1 | tr '\n' '\0' | xargs -0 rm
  sudo fc-cache -f -v
}

wsl_docker() {
  sudo apt-get -y install wget tar
  echod "installing docker from source"
  LATEST_DOCKER_VERSION=$(curl -L -s -H 'Accept: application/json' https://github.com/docker/docker/releases/latest | sed -e 's/.*"tag_name":"v\([^"]*\)".*/\1/')
  wget -O /tmp/docker.tgz https://get.docker.com/builds/Linux/x86_64/docker-$LATEST_DOCKER_VERSION.tgz
  tar xzvf /tmp/docker.tgz -C /tmp
  sudo mv /tmp/docker/docker /usr/local/bin/docker
  sudo chmod +x /usr/local/bin/docker
  # export DOCKER_HOST=tcp://127.0.0.1:2375

  echod "installing docker-machine"
  sudo apt-get -y install wget
  sudo wget -O /usr/local/bin/docker-machine https://github.com/docker/machine/releases/download/v0.10.0/docker-machine-`uname -s`-`uname -m`
  sudo chmod +x /usr/local/bin/docker-machine
}

wsl_ros() {
  ROS_VERSION=indigo
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
