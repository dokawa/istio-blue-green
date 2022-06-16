#!/usr/bin/env bash
IP=${1}
while true;do curl -s "$IP" --stderr - | grep -oP -e '(?<=--color:).*'; sleep 1; done
# while true;do curl -s http://192.168.59.100:30955/; sleep 1; done
