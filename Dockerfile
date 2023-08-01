FROM buildpack-deps:jammy-curl

RUN apt-get update && apt-get install --yes --no-install-recommends mosquitto-clients jq

COPY ./get_tuya_webrtc_configs.sh /app/

ENTRYPOINT ["/app/get_tuya_webrtc_configs.sh"]
