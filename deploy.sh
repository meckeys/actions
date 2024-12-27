#!/bin/bash

LOCATION="$HOME/apps"

usage() {
cat <<EOF
-h | --help         print help
-l | --location     specify location
-n | --name         specify app name
-a | --action       specify command
                    start, stop, status, log, errlog
EOF
}

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

std_err_file() {
echo $(app_root)/std.err
}

pid() {
cat $(pid_file)
}

is_running() {
if [ -e "$(pid_file)" ]; then
    [ $(ps -e -o pid | egrep -o "^\s+$(pid)\$") ] && return 0
    rm -f "$(pid_file)"
fi

return 1
}

start() {
if is_running; then
    echo $NAME is already running with PID $(pid)
    return 0
fi

if [ ! -e "$(app_file)" ]; then
    echo "$(app_file)" not found!
    echo Abort
    return 1
fi


pushd $(app_root) > /dev/null

nohup java -jar "$(app_file)" >/dev/null 2>$(std_err_file) &
echo $! > "$(pid_file)"

popd > /dev/null

if is_running; then
    echo $NAME successfully started!
    return 0
else
    echo failed to start $NAME!
    return 1
fi
}

stop() {
if ! is_running; then
    echo $NAME is not running
    echo Abort
    return 0
fi

kill "$(pid)"
sleep 5

if ! is_running; then
    rm -f "$(pid_file)"
    echo successfully stopped $NAME!
    return 0
else
    echo failed to stop $NAME! It may still be running.
    return 1
fi

echo stop
}


status() {
if is_running; then
echo $NAME is currently RUNNING with PID $(pid).
else
echo $NAME is currently NOT RUNNING.
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
# TODO: work needs to be done
open_file "$(log_file_root)/$NAME.log" 
}

errlog() {
open_file "$(std_err_file)" 
}



# Handle args
while [ "$#" -gt 0 ]; do
    case "$1" in
        -h | --help )
            usage
            exit 0
            ;;
        -l | --location )
            LOCATION="$2"
            shift
            ;;
        -n | --name )
            NAME="$2"
            shift
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


if [ "${NAME+x}${ACTION+y}" != "xy" ]; then
echo name and action is mandatory
usage
exit 1
fi

if [[ "start stop status log errlog" =~ "$ACTION" ]]; then
eval $ACTION
if [ "$?" -eq 1 ]; then
echo FAIL
else
echo PASS
fi
exit $?
else
echo invalid action $ACTION
usage
exit 1
fi