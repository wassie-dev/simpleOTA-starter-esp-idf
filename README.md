# SimpleOTA Starter ESP-IDF

An ESP-IDF project that connects to Wi-Fi, checks in to [SimpleOTA](https://simpleota.com) and installs later updates over the air. You flash it once with `idf.py flash`, and after that each version tag builds and ships the next firmware, as long as the repository secrets and variable listed under CI are set.

## Start

1. Click **Use this template** and create your own repository.
2. Copy `sdkconfig.secrets.example` to `sdkconfig.secrets` and fill in your device token, Wi-Fi SSID, and Wi-Fi password.
3. Set the target with `idf.py set-target`. The default is `esp32`.
4. Flash once with `idf.py flash`. On a board that has run SimpleOTA or other firmware before, run `idf.py erase-flash` first, so an old build number left in NVS doesn't make the server treat the board as up to date.
5. Set `PROJECT_VER` in `CMakeLists.txt`, then tag `v` plus that version, for example `v1.0.0`.

## CI

Pull requests and pushes to main build one target with ESP-IDF v5.5.5 and xanderwasserman/simpleota 0.2.1.

A `v*` tag uploads that application binary and starts a rollout only when the `SIMPLEOTA_API_TOKEN` secret and the `SIMPLEOTA_PROJECT_ID` variable are set. If the API token or project ID is missing, the upload is skipped and the run stays green. If `SIMPLEOTA_WIFI_SSID`, `SIMPLEOTA_WIFI_PASSWORD`, or `SIMPLEOTA_DEVICE_TOKEN` is missing, or it is still a placeholder, the tag build fails and nothing is uploaded.

Set `SIMPLEOTA_CHIP` to the chip you ship, or leave it unset for `esp32`.

The device checks in on the client's interval (one hour), so a release can take that long or a reset to arrive.

## Help

See the [SimpleOTA documentation](https://wiki.simpleota.com/).

## License

MIT. See [LICENSE](LICENSE).
