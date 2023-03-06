#!/bin/bash

# to be called as an forced command from authorized_keys file of git2html user

echo "+----------------------------------------------------------------------+"
echo "| updating web pages from git repo                                     |"
echo "+----------------------------------------------------------------------+"
cd /opt/web/http_www.fuerstenschlag-verein.de/git/fuerstenschlag-verein.de/ && git pull && /opt/web/http_www.fuerstenschlag-verein.de/git/fuerstenschlag-verein.de/bin/build.sh
echo "------------------------------------------------------------------------"
