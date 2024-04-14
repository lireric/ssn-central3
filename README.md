# ssn-central3
Armbian centered IoT devices control hub, based on MQTT broker and Lua

All used modules configured in ssn_conf.yaml (its default name, or use -c <another_config>)

Start: lua ssn_control.lua -l INFO

Each module is started in own OS process

Prerequisites:

wget http://repo.mosquitto.org/debian/mosquitto-repo.gpg.key
sudo apt-key add mosquitto-repo.gpg.key

apt install luarocks, gcc, mosquitto-dev, git, libmosquitto-dev

luarocks install lualogging lua-yaml bit32 compat53 luamqtt lua-mosquitto lua-tinyyaml

