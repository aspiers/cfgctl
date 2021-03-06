#!/bin/bash
#
# Bootstrap Environment using cfgctl

set -e

cvsroot_host=cvs.adamspiers.org
cvsroot_local_hostname=arctic
cvsroot_user=adam
cvsroot_user_at_host=$cvsroot_user@$cvsroot_host
export CVSROOT=$cvsroot_user_at_host:/home/adam/.CVSROOT
export CVS_RSH=ssh

meta=$HOME/.cvs/config/META
config=$meta/etc/config.map

if ! which cvs >/dev/null 2>&1; then
    echo 'cvs not found on $PATH; aborting!' >&2
    exit 1
fi

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

[ -d ~/.ssh ] || mkdir ~/.ssh
chmod 700 ~/.ssh

if ! [ -f "$HOME/.ssh/config" ]; then
    echo "~/.ssh/config does not exist."
    cat <<EOF > ~/.ssh/config
# be.sh-magic-cookie <- indicates can be automatically removed by be.sh
Host $CVSROOT_HOST
   ControlMaster auto

Host *
   ControlPath ~/.ssh/master-%r@%h:%p
EOF
    echo "Wrote ~/.ssh/config:"
    echo
    cat ~/.ssh/config
fi

echo "Executing ssh -NMf $cvsroot_user_at_host"
ssh -NMf $cvsroot_user_at_host
echo

echo "Checking passwordless ssh works ..."
cmd="ssh -n -o PasswordAuthentication=no $cvsroot_user_at_host hostname"
if [ "`$cmd`" != "$cvsroot_local_hostname" ]; then
    echo "$cmd didn't return $cvsroot_local_hostname; aborting." >&2
    exit 1
fi

if [ -d ~/.cfg ]; then
  echo "~/.cfg already exists!  Press Enter to continue anyway, or Ctrl-c to cancel..."
  read foo
fi

if [ -d ~/.cvs ]; then
  echo "~/.cvs already exists!  Press Enter to continue anyway, or Ctrl-c to cancel..."
  read foo
fi

mkdir -p ~/.cvs
cd ~/.cvs

for dir in config/dev-tools/cvs \
           config/{META,ANTIFOLD} \
           config/shell-env \
           config/shell-apps/{ssh,screen}
do
    if [ -d $dir ]; then
        echo "~/.cvs/$dir already exists; not checking out"
    else
        cvs checkout $dir
    fi
done

if ! [ -e $config ]; then
    echo "Press enter to edit $config ..."
    read foo
    ${EDITOR:-vi} $config
fi

echo "* Using config file $config"

# ~/bin probably doesn't exist yet, but it will be created early on
# in the below run, and various .cfg-post.d will rely on it being there.
export PATH=~/bin:$PATH

echo "Running $meta/bin/cfgctl cvs to set up .cvsrc ..."
$meta/bin/cfgctl cvs
echo

echo "Running $meta/bin/cfgctl META shell-env to install lib/libhooks.sh ..."
$meta/bin/cfgctl META shell-env
echo

echo "Running $meta/bin/cfgctl /ssh/ to retrieve all ssh config ..."
$meta/bin/cfgctl /ssh/
echo

if ! grep -q 'be.sh-magic-cookie' ~/.ssh/config; then
    echo "be.sh magic cookie missing from ~/.ssh/config; aborting!" >&2
    exit 1
fi

echo "Allowing cfgctl to rebuild ssh config from scratch ..."
echo "rm ~/.ssh/config"
rm ~/.ssh/config
echo
echo "Running $meta/bin/cfgctl /ssh/ to build config ..."
$meta/bin/cfgctl /ssh/ #--dry-run

echo "Running $meta/bin/cfgctl ..."
$meta/bin/cfgctl #--dry-run

#echo dsa > ~/.zshrc.local
