# getYGGRatio

# Prerequist
## Flaresolvr (https://github.com/FlareSolverr/FlareSolverr)
You need a Flaresolvr available api, to bypass YGG CloudFlare Protection
The URL to your cloudFlare is need in the script

You can use an "ready to user" FlareSolvrr docker : https://hub.docker.com/r/flaresolverr/flaresolverr

## curl
Need curl to send Query

## jq
Need 'jq' utility for JSON easy parsing/filtering

## python with json.tool
Need python with json.tool package to PrettyPrint JSON

## perl with HTML::Entities
Need perl with HTML::Entities package to correctly decode HTML content page from YGG

## OPTIONNAL : mosquitto_pub
Need mosquitto client package to push information to MQTT broker

# Installation
## git clone
git clone https://github.com/warrenberberd/getYGGRatio.git
## TMPDIR
Create tmp dir in your HOMEDIR : mkdir ~/tmp
or
Modify "TMPDIR=~/tmp" in the script, with what you want
## Modifying Variable
you need to edit, at least, this variables : 

FLARESOLVR_URL="http://192.168.0.1:8191"        # Your FlareSolvrr API URL
YGG_LOGIN="YGG_LOGIN"                           # YGG Login
YGG_PASSWORD="YGG_PASSWORD"                     # YGG Password


# Example
$ ./getRatioYGG2MQTT.sh
[INFO] SessionID: 22e5ad20-a2e5-11eb-a502-f181adca5c60
[INFO] GET https://www.yggtorrent.li...
[INFO] Login ygg...
[INFO] GET Ratio...
[INFO] Cleaning session
Download: 1396379767275.52 (1.27To)
Upload:   871524026286.08 (811.67Go)
Ratio:    1.60
[INFO] Infos successfuly uploaded to MQTT
