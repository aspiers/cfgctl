#!/bin/bash

set -e

META=$HOME/.cvs/config/META
export CVSROOT=adam@cvs.adamspiers.org:/home/adam/.CVSROOT
CONFIG=$META/etc/config.map
export CVS_RSH=ssh

${EDITOR:-vi} ~/.zdotuser
${EDITOR:-vi} ~/.localhost-nickname

echo "Setting ZDOTDIR to $HOME"
export ZDOTDIR=$HOME

if [ -z "$PERL5LIB" ]; then
    export PERL5LIB=$HOME/lib/perl5
else
    export PERL5LIB=$HOME/lib/perl5:$PERL5LIB
fi
echo "exported PERL5LIB=$PERL5LIB"

echo "Press Enter if ssh is set up ..."
read

if [ -d ~/.cfg ]; then
  echo "~/.cfg already exists!  Press Enter to continue anyway, or Ctrl-c to cancel..."
  read
fi

if [ -d ~/.cvs ]; then
  echo "~/.cvs already exists!  Press Enter to continue anyway, or Ctrl-c to cancel..."
  read
fi

mkdir -p ~/.cvs
cd ~/.cvs

for dir in config/dev-tools/{cvs,arch} \
           config/{META,ANTIFOLD} \
           config/shell-env \
           config/shell-apps/{ssh,screen,emacs}
do
    if ! [ -d $dir ]; then
        cvs checkout $dir
    fi
done

if ! [ -e $CONFIG ]; then
    echo "Press enter to edit $CONFIG ..."
    read foo
    ${EDITOR:-vi} $CONFIG
fi

echo "* Using config file $CONFIG"

echo "Running $META/bin/cfgctl ..."
$META/bin/cfgctl #--dry-run

#echo dsa > ~/.zshrc.local
