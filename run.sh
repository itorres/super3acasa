#!/usr/bin/env bash
IMAGE_NAME=itorres/tv3dl
COMMAND=/usr/src/app/tv3dl.py
VOLUME=$(awk -F ': ' '/base:/ {print $2}' config.yaml)
function exec_build {
    docker build -t itorres/tv3dl .
}
function exec_run {
    docker run --rm -ti -v $VOLUME:$VOLUME -v $(pwd):/usr/src/app ${IMAGE_NAME} $COMMAND
}

while getopts ":bc" opt; do
    case $opt in
        c)
            exec_build
	    ;;
	b)
	    COMMAND=bash
	    ;;
    esac
done
docker images | grep -q ${IMAGE_NAME} || exec_build
exec_run
