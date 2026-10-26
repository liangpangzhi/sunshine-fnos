#!/bin/bash
docker run --rm --entrypoint /bin/sh sunshine-stream:latest -c "ls -l /start.sh /etc/sway/sunshine-sway.conf 2>&1; echo ---; head -3 /start.sh 2>&1; echo ---; ls / | head -20; echo ---; which bash chromium sway" 2>&1 | tail -30
