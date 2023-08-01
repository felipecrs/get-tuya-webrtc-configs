#!/bin/bash

set -euxo pipefail

shopt -s inherit_errexit

# client id / access id (get from https://iot.tuya.com/cloud/basic?toptab=project)
readonly client_id="$1"
# client secret / access secret (get from https://iot.tuya.com/cloud/basic?toptab=project)
readonly client_secret="$2"
# user id / uid (get from https://iot.tuya.com/cloud/basic?toptab=related&deviceTab=4)
readonly user_id="$3"
# the camera device id (get from https://iot.tuya.com/cloud/basic?toptab=related&deviceTab=all)
readonly device_id="$4"

# Get yours from https://developer.tuya.com/en/docs/iot/api-request?id=Ka4a8uuo1j4t4#title-1-Endpoints
readonly tuya_base_url="${TUYA_BASE_URL?}"

readonly encoded_empty_body="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

t=$(date +%s%N | sed "s/......$//g")

path="/v1.0/token?grant_type=1"
sign=$(
  echo -en "${client_id}${t}GET\n${encoded_empty_body}\n\n${path}" |
    openssl dgst -sha256 -hmac "${client_secret}" |
    tr '[:lower:]' '[:upper:]' |
    sed "s/.* //g"
)

access_token=$(
  curl -fsSL --request GET "${tuya_base_url}${path}" \
    --header "sign_method: HMAC-SHA256" \
    --header "client_id: ${client_id}" \
    --header "t: ${t}" \
    --header "mode: cors" \
    --header "Content-Type: application/json" \
    --header "sign: ${sign}" \
    --header "access_token: " |
    sed "s/.*\"access_token\":\"//g" | sed "s/\".*//g"
)

path="/v1.0/users/sp/devices/${device_id}/webrtc-configs"
sign=$(
  echo -en "${client_id}${access_token}${t}GET\n${encoded_empty_body}\n\n${path}" |
    openssl dgst -sha256 -hmac "${client_secret}" |
    tr '[:lower:]' '[:upper:]' |
    sed "s/.* //g"
)

webrtc_configs=$(
  curl -fsSL --request GET "${tuya_base_url}${path}" \
    --header "sign_method: HMAC-SHA256" \
    --header "client_id: ${client_id}" \
    --header "t: ${t}" \
    --header "mode: cors" \
    --header "Content-Type: application/json" \
    --header "sign: ${sign}" \
    --header "access_token: ${access_token}"
)

path="/v1.0/open-hub/access/config"
body=$(
  jq -c <<EOF
{
  "uid": "${user_id}",
  "link_id": "123456",
  "link_type": "mqtt",
  "topics": "ipc"
}
EOF
)
encoded_body=$(echo -n "${body}" | openssl dgst -sha256 | sed "s/.*[ ]//g")
sign=$(
  echo -en "${client_id}${access_token}${t}POST\n${encoded_body}\n\n${path}" |
    openssl dgst -sha256 -hmac "${client_secret}" |
    tr '[:lower:]' '[:upper:]' |
    sed "s/.* //g"
)

mqtt_configs=$(
  curl -fsSL --request POST "${tuya_base_url}${path}" \
    --header "sign_method: HMAC-SHA256" \
    --header "client_id: ${client_id}" \
    --header "t: ${t}" \
    --header "mode: cors" \
    --header "Content-Type: application/json" \
    --header "sign: ${sign}" \
    --header "access_token: ${access_token}" \
    --data "${body}"
)

# example mqtt_configs
# {
#   "result": {
#     "client_id": "cloud_de0d1775106ec558d9d466f1ffd51506",
#     "expire_time": 7200,
#     "password": "6dfce99168ae1871497f7d6d954871fd",
#     "sink_topic": { "ipc": "/av/moto/moto_id/u/{device_id}" },
#     "source_topic": { "ipc": "/av/u/b1c3de3f6d804998105340b5c0453c82" },
#     "url": "ssl://m1.tuyaus.com:8883",
#     "username": "cloud_b1c3de3f6d804998105340b5c0453c82"
#   },
#   "success": true,
#   "t": 1690170785990,
#   "tid": "98934c8d29d511ee8c70fe98ebe72f12"
# }

mqtt_client_id=$(echo "${mqtt_configs}" | jq -r ".result.client_id")
username=$(echo "${mqtt_configs}" | jq -r ".result.username")
password=$(echo "${mqtt_configs}" | jq -r ".result.password")
url=$(echo "${mqtt_configs}" | jq -r ".result.url" | sed "s,^ssl://,mqtts://${username}:${password}@,g")
moto_id=$(echo "${webrtc_configs}" | jq -r ".result.moto_id")
sink_topic=$(echo "${mqtt_configs}" | jq -r ".result.sink_topic.ipc")
sink_topic="${sink_topic//"{device_id}"/"${device_id}"}"
sink_topic="${sink_topic//"/moto_id/"/"/${moto_id}/"}"

auth=$(echo "${webrtc_configs}" | jq -r ".result.auth")
source_topic=$(echo "${mqtt_configs}" | jq -r ".result.source_topic.ipc")
from="${source_topic//"/av/u/"/""}"
t=$(date +%s%N | sed "s/......$//g")
body=$(
  jq -c <<EOF
{
  "protocol":302,
  "pv":"2.2",
  "t":${t},
  "data":{
    "header":{
      "from":"${from}",
      "to":"${device_id}",
      "sessionid":"00b00036521743319b4d4c01f1705c48",
      "sub_dev_id":"",
      "moto_id":"${moto_id}",
      "type":"offer"
    },
    "msg":{
      "sdp":"v=0 o=- 4529163812828363188 2 IN IP4 127.0.0.1 s=- t=0 0 a=group:BUNDLE 0 1 a=msid-semantic: WMS 1VpYoJaai0xSYjWhYxPHqySybB3PaQ6Y3wXP m=audio 9 UDP/TLS/RTP/SAVPF 111 103 104 9 0 8 106 105 13 110 112 113 126 c=IN IP4 0.0.0.0 a=rtcp:9 IN IP4 0.0.0.0 a=ice-ufrag:Q93I a=ice-pwd:P58s/ZyBRNVnuIxcrcmEmRG5 a=ice-options:trickle a=fingerprint:sha-256 E1:01:E0:B3:F1:97:7F:86:07:61:54:BE:42:5F:56:E8:84:58:76:E3:E4:22:94:F1:33:2A:A3:C2:FC:67:05:3E a=setup:actpass a=mid:0 a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level a=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time a=extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01 a=extmap:4 urn:ietf:params:rtp-hdrext:sdes:mid a=extmap:5 urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id a=extmap:6 urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id a=sendrecv a=msid:1VpYoJaai0xSYjWhYxPHqySybB3PaQ6Y3wXP 1c7d25a4-9948-4165-bf4d-62fc39b8b528 a=rtcp-mux a=rtpmap:111 opus/48000/2 a=rtcp-fb:111 transport-cc a=fmtp:111 minptime=10;useinbandfec=1 a=rtpmap:103 ISAC/16000 a=rtpmap:104 ISAC/32000 a=rtpmap:9 G722/8000 a=rtpmap:0 PCMU/8000 a=rtpmap:8 PCMA/8000 a=rtpmap:106 CN/32000 a=rtpmap:105 CN/16000 a=rtpmap:13 CN/8000 a=rtpmap:110 telephone-event/48000 a=rtpmap:112 telephone-event/32000 a=rtpmap:113 telephone-event/16000 a=rtpmap:126 telephone-event/8000 a=ssrc:724809951 cname:7UznE7uyn6JBJ4PA a=ssrc:724809951 msid:1VpYoJaai0xSYjWhYxPHqySybB3PaQ6Y3wXP 1c7d25a4-9948-4165-bf4d-62fc39b8b528 a=ssrc:724809951 mslabel:1VpYoJaai0xSYjWhYxPHqySybB3PaQ6Y3wXP a=ssrc:724809951 label:1c7d25a4-9948-4165-bf4d-62fc39b8b528 m=video 9 UDP/TLS/RTP/SAVPF 96 97 98 99 100 101 122 102 120 127 119 125 107 108 109 121 114 115 124 118 123 c=IN IP4 0.0.0.0 a=rtcp:9 IN IP4 0.0.0.0 a=ice-ufrag:Q93I a=ice-pwd:P58s/ZyBRNVnuIxcrcmEmRG5 a=ice-options:trickle a=fingerprint:sha-256 E1:01:E0:B3:F1:97:7F:86:07:61:54:BE:42:5F:56:E8:84:58:76:E3:E4:22:94:F1:33:2A:A3:C2:FC:67:05:3E a=setup:actpass a=mid:1 a=extmap:14 urn:ietf:params:rtp-hdrext:toffset a=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time a=extmap:13 urn:3gpp:video-orientation a=extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01 a=extmap:12 http://www.webrtc.org/experiments/rtp-hdrext/playout-delay a=extmap:11 http://www.webrtc.org/experiments/rtp-hdrext/video-content-type a=extmap:7 http://www.webrtc.org/experiments/rtp-hdrext/video-timing a=extmap:8 http://www.webrtc.org/experiments/rtp-hdrext/color-space a=extmap:4 urn:ietf:params:rtp-hdrext:sdes:mid a=extmap:5 urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id a=extmap:6 urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id a=recvonly a=rtcp-mux a=rtcp-rsize a=rtpmap:96 VP8/90000 a=rtcp-fb:96 goog-remb a=rtcp-fb:96 transport-cc a=rtcp-fb:96 ccm fir a=rtcp-fb:96 nack a=rtcp-fb:96 nack pli a=rtpmap:97 rtx/90000 a=fmtp:97 apt=96 a=rtpmap:98 VP9/90000 a=rtcp-fb:98 goog-remb a=rtcp-fb:98 transport-cc a=rtcp-fb:98 ccm fir a=rtcp-fb:98 nack a=rtcp-fb:98 nack pli a=fmtp:98 profile-id=0 a=rtpmap:99 rtx/90000 a=fmtp:99 apt=98 a=rtpmap:100 VP9/90000 a=rtcp-fb:100 goog-remb a=rtcp-fb:100 transport-cc a=rtcp-fb:100 ccm fir a=rtcp-fb:100 nack a=rtcp-fb:100 nack pli a=fmtp:100 profile-id=2 a=rtpmap:101 rtx/90000 a=fmtp:101 apt=100 a=rtpmap:122 VP9/90000 a=rtcp-fb:122 goog-remb a=rtcp-fb:122 transport-cc a=rtcp-fb:122 ccm fir a=rtcp-fb:122 nack a=rtcp-fb:122 nack pli a=fmtp:122 profile-id=1 a=rtpmap:102 H264/90000 a=rtcp-fb:102 goog-remb a=rtcp-fb:102 transport-cc a=rtcp-fb:102 ccm fir a=rtcp-fb:102 nack a=rtcp-fb:102 nack pli a=fmtp:102 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42001f a=rtpmap:120 rtx/90000 a=fmtp:120 apt=102 a=rtpmap:127 H264/90000 a=rtcp-fb:127 goog-remb a=rtcp-fb:127 transport-cc a=rtcp-fb:127 ccm fir a=rtcp-fb:127 nack a=rtcp-fb:127 nack pli a=fmtp:127 level-asymmetry-allowed=1;packetization-mode=0;profile-level-id=42001f a=rtpmap:119 rtx/90000 a=fmtp:119 apt=127 a=rtpmap:125 H264/90000 a=rtcp-fb:125 goog-remb a=rtcp-fb:125 transport-cc a=rtcp-fb:125 ccm fir a=rtcp-fb:125 nack a=rtcp-fb:125 nack pli a=fmtp:125 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f a=rtpmap:107 rtx/90000 a=fmtp:107 apt=125 a=rtpmap:108 H264/90000 a=rtcp-fb:108 goog-remb a=rtcp-fb:108 transport-cc a=rtcp-fb:108 ccm fir a=rtcp-fb:108 nack a=rtcp-fb:108 nack pli a=fmtp:108 level-asymmetry-allowed=1;packetization-mode=0;profile-level-id=42e01f a=rtpmap:109 rtx/90000 a=fmtp:109 apt=108 a=rtpmap:121 H264/90000 a=rtcp-fb:121 goog-remb a=rtcp-fb:121 transport-cc a=rtcp-fb:121 ccm fir a=rtcp-fb:121 nack a=rtcp-fb:121 nack pli a=fmtp:121 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=4d0015 a=rtpmap:114 H264/90000 a=rtcp-fb:114 goog-remb a=rtcp-fb:114 transport-cc a=rtcp-fb:114 ccm fir a=rtcp-fb:114 nack a=rtcp-fb:114 nack pli a=fmtp:114 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=640015 a=rtpmap:115 rtx/90000 a=fmtp:115 apt=114 a=rtpmap:124 red/90000 a=rtpmap:118 rtx/90000 a=fmtp:118 apt=124 a=rtpmap:123 ulpfec/90000 ",
      "auth":"${auth}",
      "mode":"webrtc",
      "stream_type":1
    }
  }
}
EOF
)
mosquitto_pub -L "${url}${sink_topic}" -i "${mqtt_client_id}" -m "${body}"

# Still failing here
mosquitto_sub -L "${url}${source_topic}" -i "${mqtt_client_id}"
