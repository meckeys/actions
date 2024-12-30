#!/bin/bash

VERSION=1.0

# Default location of apps
LOCATION="$HOME/apps"

# Usage message
usage() {
cat <<EOF

Usage:
-v | --version      get version
-h | --help         print help
-n | --name         specify app name
-a | --action       specify action
-e | --extra-args   extra command line args to be passed


List of available actions:
start           starts application, fails gracefully if already running
stop            stops application, fails gracefully if not running
status          prints current application status
EOF
}

# Lazy evaluated properties
app_root() {
echo $LOCATION/$APP_NAME
}

pid_file() {
echo $(app_root)/app.pid
}

app_file() {
echo $(app_root)/$APP_NAME.jar
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


start() {
if is_running; then
    echo $APP_NAME is already running with PID $(pid)
    return 0
fi

if [ ! -e "$(app_file)" ]; then
    echo application "$(app_file)" not found
    return 1
fi

nohup java "$EXTRA_ARGS" -jar "$(app_file)" >/dev/null 2>$(std_err_file) &
echo $! > "$(pid_file)"

if is_running; then
    echo $APP_NAME successfully started
    return 0
else
    echo FAILED to start $APP_NAME
    return 1
fi
}


stop() {
if ! is_running; then
    echo $APP_NAME is not running
    return 0
fi

kill "$(pid)"

sleep 5

if ! is_running; then
    echo successfully stopped $APP_NAME
    return 0
else
    echo FAILED to stop $APP_NAME. It may still be running.
    return 1
fi

echo stop
}


status() {
if is_running; then
    echo $APP_NAME is currently RUNNING with PID $(pid)
else
    echo $APP_NAME is currently NOT RUNNING
fi
}


# Handle input
while [ "$#" -gt 0 ]; do
    case "$1" in
        -v | --version )
            echo $VERSION
            exit 0
            ;;
        -h | --help )
            echo Meckeys JAR deployer - $VERSION
            usage
            exit 0
            ;;
        -n | --name )
            APP_NAME="$2"
            shift
            ;;
        -a | --action )
            ACTION="$2"
            shift
            ;;
        -e | --extra-args )
            EXTRA_ARGS="$2"
            shift
            ;;
        * )
            echo Invalid argument "$1"
            exit 1
    esac
    shift
done

if [ "${APP_NAME+x}${ACTION+y}" != 'xy' ]; then
echo '-n | --name and -a | --action are required'
exit 1
fi

# Parse action
if [[ "start stop status" =~ "$ACTION" ]]; then
"$ACTION"
exit $?
else
echo invalid action $ACTION
exit 1
fi
