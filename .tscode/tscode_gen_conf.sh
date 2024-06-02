#!/bin/bash

if [ ! -f ~/.tscode/config.conf ]; then
    echo "debug=0" > ~/.tscode/config.conf
    echo "website=https://google.com" >> ~/.tscode/config.conf
    echo "editor=nano" >> ~/.tscode/config.conf
    echo "browser=links" >> ~/.tscode/config.conf
    echo "top=vtop" >> ~/.tscode/config.conf
    echo "Config file is generated."
else
    for var in "${valid_variables[@]}"; do
        if ! grep -q "^$var=" ~/.tscode/config.conf; then
            echo "debug=0" > ~/.tscode/config.conf
            echo "website=https://google.com" >> ~/.tscode/config.conf
            echo "editor=nano" >> ~/.tscode/config.conf
            echo "browser=links" >> ~/.tscode/config.conf
            echo "top=vtop" >> ~/.tscode/config.conf
            echo "Config file is fixed."
            break
        fi
    done
fi