#!/usr/bin/env bash
IMAGE_NAME=itorres/tv3dl
function exec_build {
    docker build -t itorres/tv3dl .
}
function exec_run {
    docker run --rm -ti -v $(pwd):/usr/src/app ${IMAGE_NAME} bash
}

while getopts ":b" opt; do
    case $opt in
        b)
            exec_build
    esac
done
docker images | grep -q ${IMAGE_NAME} || exec_build
exec_run
