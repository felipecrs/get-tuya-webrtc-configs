> [!IMPORTANT]  
> This project is dead. It had only two scripts which are no longer relevant:
> - `get_tuya_webrtc_configs.sh` never worked, and its functionality is now being incorporated into go2rtc:
>   - https://github.com/AlexxIT/go2rtc/pull/1379
> - `get_tuya_stream_url.sh` had portability issues across Linux distributions. It has been rewritten in Python and it is now available at:
>   - [`hass-expose-camera-stream-source/scripts/get_tuya_stream_url.py`](https://github.com/felipecrs/hass-expose-camera-stream-source/blob/master/custom_components/expose_camera_stream_source/scripts/get_tuya_stream_url.py)

# get-tuya-webrtc-configs

This project is WIP. It's currently failing at the MQTT Subscription, any help is appreciated.

## Requirements

- Tuya API account
- IoT Live Stream subscription in your project
- `TUYA_BASE_URL`, e.g. `https://openapi.tuyaus.com`, get yours from <https://developer.tuya.com/en/docs/iot/api-request?id=Ka4a8uuo1j4t4#title-1-Endpoints>
- `TUYA_CLIENT_ID`, client id/access id, get yours from <https://iot.tuya.com/cloud/basic?toptab=project>
- `TUYA_CLIENT_SECRET`, client secret/access secret, get yours from <https://iot.tuya.com/cloud/basic?toptab=project>
- `TUYA_USER_ID`, user id/uid, get yours from <https://iot.tuya.com/cloud/basic?toptab=related&deviceTab=4>
- The camera device id, get yours from <https://iot.tuya.com/cloud/basic?toptab=related&deviceTab=all>

```console
docker run --rm --pull=always \
    --env TUYA_BASE_URL=https://openapi.tuyaus.com \
    --env TUYA_CLIENT_ID=<client id> \
    --env TUYA_CLIENT_SECRET=<client secret> \
    --env TUYA_USER_ID=<user id> \
    ghcr.io/felipecrs/get-tuya-webrtc-configs:latest <camera device id>
```

Or if you have the repository cloned:

```console
$ cp .env.example .env

# Edit .env with your data
$ nano .env

$ docker compose run --build --rm get-tuya-webrtc-configs <camera device id>
```
