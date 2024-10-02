#!/bin/bash
#
# This script gets the RTSP stream URL for a Tuya camera and prints it to stdout.
#
# Usage:
# ./get_tuya_rtsp_stream.sh <device id> <client id> <client secret> <tuya api base url> [stream type]
#
# [stream type] can be "RTSP" or "HLS". Default is "RTSP" if not provided.
#
# Example of go2rtc.yaml:
# streams:
#   tuya_camera:
#     - echo:/config/scripts/get_tuya_rtsp_stream.sh <device id> <client id> <secret it> https://openapi.tuyaus.com HLS

set -euo pipefail

shopt -s inherit_errexit

readonly device_id="${1}"
readonly client_id="${2}"
readonly client_secret="${3}"
readonly tuya_base_url="${4}"
readonly stream_type="${5:-"RTSP"}"

readonly encoded_empty_body="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

t=$(date +%s%N | sed "s/......$//g")
readonly t

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

path="/v1.0/devices/${device_id}/stream/actions/allocate"
body=$(
  jq -c <<EOF
{
  "type": "${stream_type}"
}
EOF
)
encoded_body=$(echo -n "${body}" | openssl dgst -sha256 | sed "s/.*[ ]//g")
method="POST"
sign=$(
  echo -en "${client_id}${access_token}${t}${method}\n${encoded_body}\n\n${path}" |
    openssl dgst -sha256 -hmac "${client_secret}" |
    tr '[:lower:]' '[:upper:]' |
    sed "s/.* //g"
)

url=$(
  curl -fsSL --request "${method}" "${tuya_base_url}${path}" \
    --header "sign_method: HMAC-SHA256" \
    --header "client_id: ${client_id}" \
    --header "t: ${t}" \
    --header "mode: cors" \
    --header "Content-Type: application/json" \
    --header "sign: ${sign}" \
    --header "access_token: ${access_token}" \
    --data "${body}" |
    jq -er .result.url
)

echo -n "${url}"
