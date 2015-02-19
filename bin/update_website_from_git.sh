#!/bin/bash

# to be called as an forced command from authorized_keys file of git2html user

echo "+----------------------------------------------------------------------+"
echo "| updating web pages from git repo                                     |"
echo "+----------------------------------------------------------------------+"
cd /opt/web/http_www.repaircafe-altdorf.de/git/repaircafe-altdorf.de/ && git pull && /opt/web/http_www.repaircafe-altdorf.de/git/repaircafe-altdorf.de/bin/build.sh
echo "------------------------------------------------------------------------"
