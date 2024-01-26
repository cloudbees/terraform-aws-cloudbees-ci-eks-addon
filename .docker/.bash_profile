PATH=/bp-agent/.asdf/shims:/home/bp-agent/.asdf/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
source /bp-agent/.asdf/asdf.sh
rm -rf .asdf/shims/* && asdf reshim
export PS1="\u \W:$ "