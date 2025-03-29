#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: tscodeconf <variable> <value>"
    exit 1
fi

valid_variables=("debug" "website" "editor" "browser" "top")
if [[ ! " ${valid_variables[@]} " =~ " ${1} " ]]; then
    echo "Invalid variable. Choose between debug, website, editor, browser, top."
    exit 1
fi

case $1 in
    "debug")
        if [[ $2 -ne 0 && $2 -ne 1 ]]; then
            echo "Invalid value for debug. Choose between 0 and 1."
            exit 1
        fi
        ;;
    "editor")
        valid_values=("nano" "vim" "ranger")
        if [[ ! " ${valid_values[@]} " =~ " ${2} " ]]; then
            echo "Invalid value for editor. Choose between nano, vim, ranger."
            exit 1
        fi
        ;;
    "browser")
        valid_values=("carbonyl" "links" "lynx" "elinks")
        if [[ ! " ${valid_values[@]} " =~ " ${2} " ]]; then
            echo "Invalid value for browser. Choose between carbonyl, links, lynx, elinks."
            exit 1
        fi
        ;;
    "top")
        valid_values=("vtop" "htop" "gtop" "top")
        if [[ ! " ${valid_values[@]} " =~ " ${2} " ]]; then
            echo "Invalid value for top. Choose between vtop, htop, gtop, top."
            exit 1
        fi
        ;;
esac

declare "$1=$2"

~/.tscode/tscode_gen_conf.sh

sed -i "/^$1=/d" ~/.tscode/config.conf

echo "$1=$2" >> ~/.tscode/config.conf

grep "^$1=" ~/.tscode/config.conf