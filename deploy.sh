#!/bin/bash

VERSION=1.0

# Default location of apps
LOCATION="$HOME/apps"

# Usage message
usage() {
cat <<EOF

Usage:
-h | --help         print help
-l | --location     specify location
-e | --environment  specify environment variables as semi-colon separated pairs
-n | --name         specify app name
-i | --install      install application
-u | --uninstall    delete application
-f | --force        forcefully perform operations without sanity checks
-a | --action       specify action

List of available actions:
start           starts application, fails gracefully if already running
stop            stops application, fails gracefully if not running
status          prints current application status
log             prints latest log
error_log       prints latest error log
delete_logs     delete all logs
EOF
}

# Lazy evaluated properties
app_root() {
echo $LOCATION/$NAME
}

pid_file() {
echo $(app_root)/app.pid
}

app_file() {
echo $(app_root)/$NAME.jar
}

log_file_root() {
echo $(app_root)/logs/$NAME
}

log_file() {
echo $(log_file_root)/$NAME.log
}

std_err_file() {
echo $(app_root)/std.err
}

pid() {
cat $(pid_file)
}


is_running() {
if [ -e "$(pid_file)" ]; then
    [ $(ps -e -o pid | grep -Eo "^\s+$(pid)\$") ] && return 0
    rm -f "$(pid_file)"
fi

return 1
}


is_installed() {
    [ -e "$(app_file)" ]
}


start() {
if is_running && [ ! $FORCE ]; then
    echo $NAME is already running with PID $(pid)
    return 0
fi

if ! is_installed && [ ! $FORCE ]; then
    echo application "$(app_file)" not found
    return 1
fi

if [ ! -z "$ENVIRONMENT" ]; then
OLD_IFS=$IFS
IFS=$';\n'
for var in $ENVIRONMENT; do
    if [[ "$var" =~  ^[a-zA-Z]+.*=.+$ ]]; then
        declare -x "${var%%=*}=${var#*=}"
    fi
done
IFS=$OLD_IFS
fi

pushd $(app_root) > /dev/null

nohup java -jar "$(app_file)" >/dev/null 2>$(std_err_file) &
echo $! > "$(pid_file)"

popd > /dev/null

if is_running; then
    echo $NAME successfully started
    return 0
else
    echo FAILED to start $NAME
    return 1
fi
}


stop() {
if ! is_running; then
    echo $NAME is not running
    return 0
fi

if [ $FORCE ]; then
    kill -SIGKILL "$(pid)"
else
    kill "$(pid)"
fi

sleep 5

if ! is_running; then
    echo successfully stopped $NAME
    return 0
else
    echo FAILED to stop $NAME. It may still be running.
    return 1
fi

echo stop
}


status() {
if is_running; then
echo $NAME is currently RUNNING with PID $(pid)
else
echo $NAME is currently NOT RUNNING
fi
}


open_file() {
if [ ! -e "$1" ]; then
    echo Failed to open "$1"
    return 1
fi

is_running && less +F "$1" || less +G "$1"
}


log() {
if [ ! -e "$(log_file)" ]; then
echo no logs found
return 0
fi 

if [ $(find "$(log_file_root)" -type f | grep -E "\.log$" | wc -l) -gt 1 ]; then
    echo More log files found under "$(log_file_root)". Showing only "$(log_file)"
fi

open_file "$(log_file)" 
}


error_log() {
if [ ! -e "$(std_err_file)" ]; then
echo no error logs found
return 0
fi

open_file "$(std_err_file)" 
}


delete_logs() {
rm -rf "$(log_file_root)"
echo Done
}


# Handle input
while [ "$#" -gt 0 ]; do
    case "$1" in
        -h | --help )
            echo Meckeys JAR deployer - $VERSION
            usage
            exit 0
            ;;
        -l | --location )
            LOCATION="$2"
            shift
            ;;
        -e | --environment )
            ENVIRONMENT="$2"
            shift
            ;;
        -n | --name )
            NAME="$2"
            shift
            ;;
        -i | --install )
            PATH_TO_INSTALL="$2"
            shift
            ;;
        -u | --uninstall)
            UNINSTALL=true
            ;;
        -f | --force)
            FORCE=true
            ;;
        -a | --action )
            ACTION="$2"
            shift
            ;;
        * )
            echo Invalid argument "$1"
            usage
            exit 1
    esac
    shift
done


# Check if name is provided
if [ -z "${NAME+x}" ]; then
echo '-n | --name is required'
exit 1
fi


# When not uninstalling
if [ -z "${UNINSTALL+x}" ]; then

#check if atleast install/action is provided
if [ -z "${PATH_TO_INSTALL+y}${ACTION+z}" ]; then
echo 'atleast -i | --install, -u | --uninstall or -a | --action is required'
exit 1
fi

# When uninstall is used
else

# Check if uninstall and install are not used together
if [ ! -z "${PATH_TO_INSTALL+y}" ]; then
echo '-u | --uninstall and -i | --install cannot be used together'
exit 1
fi

# Check if uninstall and action are not used together
if [ ! -z "${ACTION+y}" ]; then
echo '-u | --uninstall and -a | --action cannot be used together'
exit 1
fi

fi



# Uninstall
if [ ! -z "${UNINSTALL+x}" ]; then
if is_running && [ ! $FORCE ]; then
echo $NAME is currently running. please stop it first.
exit 1
fi

if ! is_installed && [ ! $FORCE ]; then
echo $NAME is already not installed.
exit 0
fi

rm -f $(app_file)

echo Done
fi


# Install
if [ ! -z "${PATH_TO_INSTALL+x}" ]; then
if is_running && [ ! $FORCE ]; then
echo $NAME is currently running. please stop it first.
exit 1
fi

# Check if path is valid
if ! [[ -e "${PATH_TO_INSTALL}" && "${PATH_TO_INSTALL}" =~ \.jar$ ]]; then
echo invalid jar file
exit 1
fi

# Delete old jar
rm -f $(app_file)

# create new directories
mkdir -p "$(app_root)"

# copy file
cp "${PATH_TO_INSTALL}" "$(app_file)"

if is_installed; then
echo successfully installed!
else
echo failed to install
exit 1
fi

fi


# Parse action
if [[ ! -z "$ACTION" ]]; then
if [[ "start stop status log error_log delete_logs" =~ "$ACTION" ]]; then
"$ACTION"
exit $?
else
echo invalid action $ACTION
usage
exit 1
fi
fi