#!/bin/sh
cd /usr/local/lib/lua/5.1/
lua mqttPersist.lua -c /opt/ssn-central/ssn_kokorino.yaml -l INFO
