#!/bin/bash
#
# This is a Shell script for VPS initialization and
# LAMP (Linux + Apache + MariaDB + PHP) installation
#
# Supported OS:
# Enterprise Linux 8 (CentOS 8, RHEL 8, Rocky Linux 8, AlmaLinux 8, Oracle Linux 8)
# Enterprise Linux 9 (CentOS 9, RHEL 9, Rocky Linux 9, AlmaLinux 9, Oracle Linux 9)
#
# Copyright (C) 2013 - 2025 Teddysun <i@teddysun.com>
#
trap _exit INT QUIT TERM

cur_dir="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"

_red() {
    printf '\033[1;31;31m%b\033[0m' "$1"
}

_green() {
    printf '\033[1;31;32m%b\033[0m' "$1"
}

_yellow() {
    printf '\033[1;31;33m%b\033[0m' "$1"
}

_printargs() {
    printf -- "%s" "[$(date)] "
    printf -- "%s" "$1"
    printf "\n"
}

_info() {
    _printargs "$@"
}

_warn() {
    printf -- "%s" "[$(date)] "
    _yellow "$1"
    printf "\n"
}

_error() {
    printf -- "%s" "[$(date)] "
    _red "$1"
    printf "\n"
    exit 2
}

_exit() {
    printf "\n"
    _red "$0 has been terminated."
    printf "\n"
    exit 1
}

_exists() {
    local cmd="$1"
    if eval type type >/dev/null 2>&1; then
        eval type "$cmd" >/dev/null 2>&1
    elif command >/dev/null 2>&1; then
        command -v "$cmd" >/dev/null 2>&1
    else
        which "$cmd" >/dev/null 2>&1
    fi
    local rt=$?
    return ${rt}
}

_error_detect() {
    local cmd="$1"
    _info "${cmd}"
    if ! eval "${cmd}" 1>/dev/null; then
        _error "Execution command (${cmd}) failed, please check it and try again."
    fi
}

check_sys() {
    local value="$1"
    local release=''
    if [ -f /etc/redhat-release ]; then
        release="rhel"
    elif grep -Eqi "debian" /etc/issue; then
        release="debian"
    elif grep -Eqi "ubuntu" /etc/issue; then
        release="ubuntu"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
        release="rhel"
    elif grep -Eqi "debian" /proc/version; then
        release="debian"
    elif grep -Eqi "ubuntu" /proc/version; then
        release="ubuntu"
    elif grep -Eqi "centos|red hat|redhat" /proc/version; then
        release="rhel"
    fi
    if [ "${value}" == "${release}" ]; then
        return 0
    else
        return 1
    fi
}

get_char() {
    SAVEDSTTY=$(stty -g)
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2>/dev/null
    stty -raw
    stty echo
    stty "${SAVEDSTTY}"
}

get_opsy() {
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

get_rhelversion() {
    if check_sys rhel; then
        local version
        local code=$1
        local main_ver
        version=$(get_opsy)
        main_ver=$(echo "${version}" | grep -oE "[0-9.]+")
        if [ "${main_ver%%.*}" == "${code}" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

get_debianversion() {
    if check_sys debian; then
        local version
        local code=$1
        local main_ver
        version=$(get_opsy)
        main_ver=$(echo "${version}" | grep -oE "[0-9.]+")
        if [ "${main_ver%%.*}" == "${code}" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

get_ubuntuversion() {
    if check_sys ubuntu; then
        local version
        local code=$1
        version=$(get_opsy)
        if echo "${version}" | grep -q "${code}"; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

version_ge() {
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"
}

check_kernel_version() {
    local kernel_version
    kernel_version=$(uname -r | cut -d- -f1)
    if version_ge "${kernel_version}" 4.9; then
        return 0
    else
        return 1
    fi
}

check_bbr_status() {
    local param
    param=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    if [[ "${param}" == "bbr" ]]; then
        return 0
    else
        return 1
    fi
}

# Check user
[ ${EUID} -ne 0 ] && _red "This script must be run as root!\n" && exit 1

# Check OS
if ! get_rhelversion 8 && ! get_rhelversion 9; then
    _error "Not supported OS, please change OS to Enterprise Linux 8 or Enterprise Linux 9 and try again."
fi

# Choose MariaDB version
while true; do
    _info "Please choose a version of the MariaDB:"
    _info "$(_green 1). MariaDB 10.11"
    _info "$(_green 2). MariaDB 11.4"
    read -r -p "[$(date)] Please input a number: (Default 1) " mariadb_version
    [ -z "${mariadb_version}" ] && mariadb_version=1
    case "${mariadb_version}" in
    1)
        mariadb_ver="10.11"
        break
        ;;
    2)
        mariadb_ver="11.4"
        break
        ;;
    *)
        _info "Input error! Please only input a number 1 2"
        ;;
    esac
done
_info "---------------------------"
_info "MariaDB version = $(_red "${mariadb_ver}")"
_info "---------------------------"

# Set MariaDB root password
_info "Please input the root password of MariaDB:"
read -r -p "[$(date)] (Default password: Teddysun.com):" db_pass
if [ -z "${db_pass}" ]; then
    db_pass="Teddysun.com"
fi
_info "---------------------------"
_info "Password = $(_red "${db_pass}")"
_info "---------------------------"

# Choose PHP version
while true; do
    _info "Please choose a version of the PHP:"
    _info "$(_green 1). PHP 7.4"
    _info "$(_green 2). PHP 8.0"
    _info "$(_green 3). PHP 8.1"
    _info "$(_green 4). PHP 8.2"
    _info "$(_green 5). PHP 8.3"
    _info "$(_green 6). PHP 8.4"
    read -r -p "[$(date)] Please input a number: (Default 4) " php_version
    [ -z "${php_version}" ] && php_version=4
    case "${php_version}" in
    1)
        php_ver="7.4"
        break
        ;;
    2)
        php_ver="8.0"
        break
        ;;
    3)
        php_ver="8.1"
        break
        ;;
    4)
        php_ver="8.2"
        break
        ;;
    5)
        php_ver="8.3"
        break
        ;;
    6)
        php_ver="8.4"
        break
        ;;
    *)
        _info "Input error! Please only input a number 1 2 3 4 5 6"
        ;;
    esac
done
_info "---------------------------"
_info "PHP version = $(_red "${php_ver}")"
_info "---------------------------"

_info "Press any key to start...or Press Ctrl+C to cancel"
char=$(get_char)

_info "Initialization start"
_error_detect "rm -f /etc/localtime"
_error_detect "ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime"
_error_detect "yum install -yq yum-utils epel-release"
_error_detect "yum-config-manager --enable epel"
if get_rhelversion 8; then
    yum-config-manager --enable powertools >/dev/null 2>&1 || yum-config-manager --enable PowerTools >/dev/null 2>&1
    _info "Set enable PowerTools Repository completed"
    _error_detect "yum install -yq https://dl.lamp.sh/linux/rhel/el8/x86_64/teddysun-release-1.0-1.el8.noarch.rpm"
fi
if get_rhelversion 9; then
    _error_detect "yum-config-manager --enable crb"
    _info "Set enable CRB Repository completed"
    echo "set enable-bracketed-paste off" >>/etc/inputrc
    _error_detect "yum install -y https://dl.lamp.sh/linux/rhel/el9/x86_64/teddysun-release-1.0-1.el9.noarch.rpm"
fi
_error_detect "yum makecache"
_error_detect "yum install -yq vim tar zip unzip net-tools bind-utils screen git virt-what wget whois firewalld mtr traceroute iftop htop jq tree"
_error_detect "yum install -yq libnghttp2 libnghttp2-devel"
# Replaced local curl from teddysun linux Repository
_error_detect "yum install -yq curl libcurl libcurl-devel"
if [ -s "/etc/selinux/config" ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
    sed -i 's@^SELINUX.*@SELINUX=disabled@g' /etc/selinux/config
    setenforce 0
    _info "Disable SElinux completed"
fi
if [ -s "/etc/motd.d/cockpit" ]; then
    rm -f /etc/motd.d/cockpit
    _info "Delete /etc/motd.d/cockpit completed"
fi
if systemctl status firewalld >/dev/null 2>&1; then
    default_zone="$(firewall-cmd --get-default-zone)"
    firewall-cmd --permanent --add-service=https --zone="${default_zone}" >/dev/null 2>&1
    firewall-cmd --permanent --add-service=http --zone="${default_zone}" >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1
    sed -i 's@AllowZoneDrifting=yes@AllowZoneDrifting=no@' /etc/firewalld/firewalld.conf
    _error_detect "systemctl restart firewalld"
    _info "Set firewall completed"
else
    _warn "firewalld looks like not running, skip setting up firewall"
fi

if check_kernel_version; then
    if ! check_bbr_status; then
        sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
        sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
        cat >>/etc/sysctl.conf <<EOF
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 2500000
EOF
        sysctl -p >/dev/null 2>&1
        _info "Set bbr completed"
    fi
fi

if systemctl status systemd-journald >/dev/null 2>&1; then
    sed -i 's/^#\?Storage=.*/Storage=volatile/' /etc/systemd/journald.conf
    sed -i 's/^#\?SystemMaxUse=.*/SystemMaxUse=16M/' /etc/systemd/journald.conf
    sed -i 's/^#\?RuntimeMaxUse=.*/RuntimeMaxUse=16M/' /etc/systemd/journald.conf
    _error_detect "systemctl restart systemd-journald"
    _info "Set systemd-journald completed"
fi

echo
netstat -nxtulpe
echo
_info "Initialization completed"
sleep 3
clear
_info "LAMP (Linux + Apache + MariaDB + PHP) installation start"
_info "Apache installation start"
_error_detect "yum install -y httpd mod_ssl mod_http2 mod_session mod_lua pcre"
_info "Apache installation completed"

_info "Setting up Apache"
_error_detect "mkdir -p /data/www/default"
_error_detect "mkdir -p /data/wwwlog"
_error_detect "mkdir -p /etc/httpd/conf.d/vhost"
_error_detect "mkdir -p /etc/httpd/ssl"
_error_detect "cp -f ${cur_dir}/conf/httpd.conf /etc/httpd/conf/httpd.conf"
_error_detect "cp -f ${cur_dir}/conf/httpd-info.conf /etc/httpd/conf.d/"
_error_detect "cp -f ${cur_dir}/conf/ssl.conf /etc/httpd/conf.d/"
_error_detect "cp -f ${cur_dir}/conf/vhosts.conf /etc/httpd/conf.d/"
_error_detect "cp -f ${cur_dir}/conf/welcome.conf /etc/httpd/conf.d/"

_error_detect "cp -f ${cur_dir}/conf/favicon.ico /data/www/default/"
_error_detect "cp -f ${cur_dir}/conf/index.html /data/www/default/"
_error_detect "cp -f ${cur_dir}/conf/lamp.png /data/www/default/"
cat >/etc/httpd/conf.d/vhost/_default.conf <<EOF
<VirtualHost _default_:80>
ServerName localhost
DocumentRoot /data/www/default
<Directory /data/www/default>
    SetOutputFilter DEFLATE
    Options FollowSymLinks
    AllowOverride All
    Order Deny,Allow
    Allow from All
    DirectoryIndex index.html index.htm index.php
</Directory>
</VirtualHost>
EOF
_error_detect "chown -R apache:apache /data/www /data/wwwlog"
_info "Apache setup completed"

_info "MariaDB installation start"
_error_detect "wget -qO mariadb_repo_setup.sh https://downloads.mariadb.com/MariaDB/mariadb_repo_setup"
_error_detect "chmod +x mariadb_repo_setup.sh"
_info "./mariadb_repo_setup.sh --mariadb-server-version=mariadb-${mariadb_ver}"
./mariadb_repo_setup.sh --mariadb-server-version=mariadb-${mariadb_ver} >/dev/null 2>&1
_error_detect "rm -f mariadb_repo_setup.sh"
_error_detect "yum config-manager --disable mariadb-maxscale"
_error_detect "yum install -y MariaDB-common MariaDB-server MariaDB-client MariaDB-shared MariaDB-backup"
mariadb_cnf="/etc/my.cnf.d/server.cnf"
_info "MariaDB installation completed"

_info "Setting up MariaDB"
lnum=$(sed -n '/\[mysqld\]/=' "${mariadb_cnf}")
[ -n "${lnum}" ] && sed -i "${lnum}ainnodb_buffer_pool_size = 100M\nmax_allowed_packet = 1024M\nnet_read_timeout = 3600\nnet_write_timeout = 3600" "${mariadb_cnf}"
lnum=$(sed -n '/\[mariadb\]/=' "${mariadb_cnf}" | tail -1)
[ -n "${lnum}" ] && sed -i "${lnum}acharacter-set-server = utf8mb4\n\n\[client-mariadb\]\ndefault-character-set = utf8mb4" "${mariadb_cnf}"
_error_detect "systemctl start mariadb"
sleep 3
/usr/bin/mariadb -e "grant all privileges on *.* to root@'127.0.0.1' identified by \"${db_pass}\" with grant option;"
/usr/bin/mariadb -e "grant all privileges on *.* to root@'localhost' identified by \"${db_pass}\" with grant option;"
/usr/bin/mariadb -uroot -p"${db_pass}" 2>/dev/null <<EOF
drop database if exists test;
delete from mysql.db where user='';
delete from mysql.db where user='PUBLIC';
delete from mysql.user where user='';
delete from mysql.user where user='mysql';
delete from mysql.user where user='PUBLIC';
flush privileges;
exit
EOF
# Install phpMyAdmin
_error_detect "wget -qO pma.tar.gz https://dl.lamp.sh/files/pma.tar.gz"
_error_detect "tar zxf pma.tar.gz -C /data/www/default/"
_error_detect "rm -f pma.tar.gz"
_info "/usr/bin/mariadb -uroot -p 2>/dev/null < /data/www/default/pma/sql/create_tables.sql"
/usr/bin/mariadb -uroot -p"${db_pass}" 2>/dev/null </data/www/default/pma/sql/create_tables.sql
_info "MariaDB setup completed"

_info "PHP installation start"
php_conf="/etc/php-fpm.d/www.conf"
php_ini="/etc/php.ini"
php_fpm="php-fpm"
php_sock="unix//run/php-fpm/www.sock"
sock_location="/var/lib/mysql/mysql.sock"
if get_rhelversion 8; then
    _error_detect "yum install -yq https://rpms.remirepo.net/enterprise/remi-release-8.rpm"
fi
if get_rhelversion 9; then
    _error_detect "yum install -yq https://rpms.remirepo.net/enterprise/remi-release-9.rpm"
fi
_error_detect "yum module reset -yq php"
_error_detect "yum module install -yq php:remi-${php_ver}"
_error_detect "yum install -yq php-common php-fpm php-cli php-bcmath php-embedded php-gd php-imap php-mysqlnd php-dba php-pdo php-pdo-dblib"
_error_detect "yum install -yq php-pgsql php-odbc php-enchant php-gmp php-intl php-ldap php-snmp php-soap php-tidy php-opcache php-process"
_error_detect "yum install -yq php-pspell php-shmop php-sodium php-ffi php-brotli php-lz4 php-xz php-zstd php-pecl-rar"
_error_detect "yum install -yq php-pecl-imagick-im7 php-pecl-zip php-pecl-mongodb php-pecl-grpc php-pecl-yaml php-pecl-uuid composer"
_info "PHP installation completed"

_info "Setting up PHP"
sed -i "s@^user.*@user = apache@" "${php_conf}"
sed -i "s@^group.*@group = apache@" "${php_conf}"
sed -i "s@^listen.acl_users.*@listen.acl_users = apache,nginx@" "${php_conf}"
sed -i "s@^;php_value\[opcache.file_cache\].*@php_value\[opcache.file_cache\] = /var/lib/php/opcache@" "${php_conf}"
sed -i "s@^disable_functions.*@disable_functions = passthru,exec,shell_exec,system,chroot,chgrp,chown,proc_open,proc_get_status,ini_alter,ini_alter,ini_restore@" "${php_ini}"
sed -i "s@^max_execution_time.*@max_execution_time = 300@" "${php_ini}"
sed -i "s@^max_input_time.*@max_input_time = 300@" "${php_ini}"
sed -i "s@^post_max_size.*@post_max_size = 128M@" "${php_ini}"
sed -i "s@^upload_max_filesize.*@upload_max_filesize = 128M@" "${php_ini}"
sed -i "s@^expose_php.*@expose_php = Off@" "${php_ini}"
sed -i "s@^short_open_tag.*@short_open_tag = On@" "${php_ini}"
sed -i "s#mysqli.default_socket.*#mysqli.default_socket = ${sock_location}#" "${php_ini}"
sed -i "s#pdo_mysql.default_socket.*#pdo_mysql.default_socket = ${sock_location}#" "${php_ini}"
_info "PHP setup completed"

_error_detect "cp -f ${cur_dir}/conf/lamp /usr/bin/"
_error_detect "chmod 755 /usr/bin/lamp"
_error_detect "systemctl daemon-reload"
_error_detect "systemctl start ${php_fpm}"
_error_detect "systemctl start httpd"
sleep 3
_error_detect "systemctl restart ${php_fpm}"
_error_detect "systemctl restart httpd"
sleep 1
_info "systemctl enable mariadb"
systemctl enable mariadb >/dev/null 2>&1
_info "systemctl enable ${php_fpm}"
systemctl enable "${php_fpm}" >/dev/null 2>&1
_info "systemctl enable httpd"
systemctl enable httpd >/dev/null 2>&1
pkill -9 gpg-agent
_info "systemctl status mariadb"
systemctl --no-pager -l status mariadb
_info "systemctl status ${php_fpm}"
systemctl --no-pager -l status "${php_fpm}"
_info "systemctl status httpd"
systemctl --no-pager -l status httpd
echo
netstat -nxtulpe
echo
_info "LAMP (Linux + Apache + MariaDB + PHP) installation completed"
