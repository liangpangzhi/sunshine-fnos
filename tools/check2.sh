#!/bin/bash
docker run --rm --entrypoint /bin/sh sunshine-stream:latest -c "echo PATH=\$PATH; for f in /usr/bin/sway /usr/bin/pulseaudio /usr/bin/pactl /usr/bin/dbus-launch /usr/bin/chromium; do ls -l \$f 2>&1; done; echo ---; ls /usr/bin | grep -cE \".*\"" 2>&1
