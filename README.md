# SimpleOTA Starter ESP-IDF

This is an ESP-IDF project that joins your Wi-Fi, checks in to [SimpleOTA](https://simpleota.com), and installs later firmware over the air. You flash the board once from USB. After that, a version tag on GitHub builds the next firmware and can upload it, and the board installs that build by itself.

The firmware uses the [xanderwasserman/simpleota](https://components.espressif.com/components/xanderwasserman/simpleota) component at version 0.2.1. This starter does not sign firmware. The release workflow uploads the application binary unsigned, and the release action records that as security `basic`, which is what the Actions summary shows.

## Before you start

You need all of the following.

1. An ESP32 board with 4 MB of flash. The partition table is two 1700 KB application slots, and the project sets the flash size to 4 MB. A board with less flash cannot use this table.
2. A USB cable that connects the board to your computer.
3. A [SimpleOTA](https://simpleota.com) account.
4. ESP-IDF, with `idf.py` available in the terminal you use for the steps below. This repository's CI builds with ESP-IDF v5.5.5, and that is the tested version. Install it with [Espressif's get-started guide for v5.5.5](https://docs.espressif.com/projects/esp-idf/en/v5.5.5/esp32/get-started/index.html).

## Create your repository

1. On this repository's GitHub page, click **Use this template** and create your own repository.
2. Clone that repository and move into it. The later commands assume this directory is your current directory.

```bash
git clone https://github.com/YOUR_USER/YOUR_REPO.git
cd YOUR_REPO
```

## Set up SimpleOTA

Create one project, then collect three values. You will put the device token in `sdkconfig.secrets` and in GitHub. You will put the API token and the project id in GitHub only. The [first project](https://wiki.simpleota.com/getting-started/first-project/) guide is the source for creating the project and reading the project id. The [device tokens](https://wiki.simpleota.com/guides/device-tokens/) guide is the source for the device token. The [tokens](https://wiki.simpleota.com/dashboard/tokens/) page is the source for the API token's scopes.

### Create the project

1. Sign in and open the dashboard.
2. Click **Projects**, then **New project**.
3. Give the project a name. SimpleOTA generates the slug from the name. Use **Edit** next to that field if you want a different slug. A lowercase hyphenated slug is the form the docs recommend, for example `office-thermostat`.
4. Save.

The name and the slug cannot be renamed later. Deleting the project and creating it again is the only way to change them, and that deletes the project's devices, artifacts, and build counter.

### Copy the project id

Open the project. Under the project name is **Project ID**, a UUID, with a copy button. Copy it. This is the value for the `SIMPLEOTA_PROJECT_ID` repository variable. Store it as a variable. The slug is a label for people, and API calls address the project by this UUID.

### Create the device token

This firmware sends the board's Wi-Fi station MAC as its device id. The client writes that MAC in lowercase hexadecimal with colons, in the form `aa:bb:cc:dd:ee:ff`. A device token works for exactly one device id, and it cannot register a device that does not already exist. Create the device row before the first flash, and enter that MAC as the device id.

The ESP-IDF 5.5 line installs esptool 4. The ESP-IDF v5.5.5 environment must be loaded first (`. $IDF_PATH/export.sh`, or the ESP-IDF terminal on Windows) before you run `esptool.py` or `idf.py`, as described in [Espressif's get-started guide for v5.5.5](https://docs.espressif.com/projects/esp-idf/en/v5.5.5/esp32/get-started/index.html). Print the address programmed into the chip:

```bash
esptool.py -p PORT read_mac
```

Replace `PORT` with the board's serial port. The command prints the base MAC. With Espressif's default MAC allocation, the Wi-Fi station MAC this firmware sends is that same address. Rewrite it in lowercase with colons before you paste it into Add device.

1. Open the project.
2. In the **Devices** card, click **Add device**.
3. Enter the MAC as the device id. Do not enter hardware metadata. The board reports its chip and framework on its first check-in.
4. Submit the form.
5. Copy the raw token from the yellow alert box immediately. It is shown once and cannot be retrieved again.

The token starts with `soto_dev_`. It is the value for `CONFIG_EXAMPLE_SIMPLEOTA_TOKEN` in `sdkconfig.secrets`, and for the `SIMPLEOTA_DEVICE_TOKEN` repository secret. This starter compiles that one token into the firmware, so the firmware you flash and the firmware CI builds both authenticate as this device.

If the device row already exists, the same guide describes a second place to issue the token: open the device from the Devices list, and on the device detail page, in the **Authentication** section, click **Issue token** (or **Rotate token** if one already exists). Copy the raw token from the yellow alert box. A brand new board has not checked in yet, so **Add device** is the path that gives you a token before the first flash.

### Create the API token

The upload uses a project API token that includes the `api` scope. A project token's scopes are checkboxes, and a new token defaults to `device` only. The `device` scope can only check for updates. The `api` scope is the one that can upload firmware and manage deployments. Leave this token off the board. The device token above is what the firmware uses.

1. Open the project.
2. On the **Project API tokens** card, click **Issue token**.
3. Include the `api` scope, and give the token a name you will recognize later, such as `ci-upload`.
4. Copy the token immediately. It is shown once. SimpleOTA stores only a hash.

The token starts with `soto_proj_`. It is the value for the `SIMPLEOTA_API_TOKEN` repository secret.

## Choose the chip

This starter accepts these chip names:

`esp32`, `esp32s2`, `esp32s3`, `esp32c3`, `esp32c6`, `esp32h2`

The default is `esp32`. Pick the name that matches your board, and pass it to the `idf.py set-target` command in the flash section after `sdkconfig.secrets` is filled in.

Use the same chip name for the `SIMPLEOTA_CHIP` repository variable in the GitHub section below. The board reports the chip family it was compiled for. A tag build compiles `SIMPLEOTA_CHIP`, or `esp32` when that variable is empty, and the upload is labeled with that chip. The local target and `SIMPLEOTA_CHIP` have to be the chip on the board you ship. If they differ, the rollout is for a different chip than the one you flashed.

## Add local secrets

The project reads Wi-Fi credentials and the device token from `sdkconfig.secrets`. That file is gitignored. Copy the example and replace the three placeholders:

```bash
cp sdkconfig.secrets.example sdkconfig.secrets
```

The example contains these lines:

```
CONFIG_EXAMPLE_WIFI_SSID="your-ssid"
CONFIG_EXAMPLE_WIFI_PASSWORD="your-password"
CONFIG_EXAMPLE_SIMPLEOTA_TOKEN="your-device-token"
```

| Option | What to put in the quotes |
| --- | --- |
| `CONFIG_EXAMPLE_WIFI_SSID` | The Wi-Fi network name. In menuconfig this option is **Wi-Fi SSID**. |
| `CONFIG_EXAMPLE_WIFI_PASSWORD` | The Wi-Fi password. In menuconfig this option is **Wi-Fi password**. |
| `CONFIG_EXAMPLE_SIMPLEOTA_TOKEN` | The device token from the yellow alert box. In menuconfig this option is **SimpleOTA device token**. |

Fill in this file before the `idf.py set-target` command in the flash section. ESP-IDF applies `sdkconfig.defaults` and `sdkconfig.secrets` when it creates `sdkconfig`, and it does not re-read them after that. If you change `sdkconfig.secrets` later, delete `sdkconfig` and run `idf.py set-target` again with the same chip.

`scripts/secrets.sh` is what a release build uses to accept or reject this file. Blank lines are allowed. A comment line is allowed when the first character that is not whitespace is `#`. Every other line must be one of the three options above, with the value wrapped in double quotes. The script rejects anything else:

- A line that is not one `CONFIG_...=` setting is rejected with `sdkconfig.secrets contains a line other than the Wi-Fi SSID, Wi-Fi password, and device token options.`
- Any other `CONFIG_` name is rejected with `sdkconfig.secrets must not set <name>.`
- A value that is not wrapped in double quotes is rejected with `sdkconfig.secrets has a malformed <name> line.`
- An empty value, or a value that is only spaces, is rejected with `sdkconfig.secrets sets a blank <name>.`
- A value that is still `your-ssid`, `your-password`, or `your-device-token` is rejected with `sdkconfig.secrets uses a placeholder value.`
- A file that omits any of the three options is rejected with `sdkconfig.secrets does not set the Wi-Fi and device token options.`

If a release check runs and the file is not there, the script stops with `Release build is missing sdkconfig.secrets.` Running the script without `write` or `check` prints `Usage: secrets.sh write|check`. The workflow calls `write` on a tag. `scripts/build.sh` calls `check` on a release build.

A normal local `idf.py build` does not run that script. A tag build does. Fill in real values now so the first flash and the later release use the same credentials.

## Flash over USB

Do this once for the board. Replace `esp32` with the chip you chose, and replace `PORT` with the board's serial port.

1. Set the target. `sdkconfig.secrets` has to exist before this command:

```bash
idf.py set-target esp32
```

`idf.py set-target` writes `sdkconfig`, and that file is gitignored, so the choice stays on your machine.

2. Build:

```bash
idf.py build
```

3. If this board has run other firmware before, erase it before flashing:

```bash
idf.py -p PORT erase-flash
```

`idf.py flash` writes the bootloader, the partition table, the OTA data, and the app, and it leaves the rest of the flash alone. An older layout can leave a SimpleOTA build number in NVS. The server then treats the board as already running that build, and it will not offer the update you just flashed. `idf.py erase-flash` clears the chip so the new table and a build number of 0 start clean. A board that has never been flashed can skip the erase.

4. Flash the firmware and open the serial monitor:

```bash
idf.py -p PORT flash monitor
```

This first flash is the one that installs the bootloader, the rollback setting inside that bootloader, and the partition table from `partitions.csv`. Over-the-air updates cannot change those. Later updates only replace the application in the inactive slot. The table has two slots, `ota_0` and `ota_1`. A serial flash boots `ota_0`, and updates alternate between the two.

A healthy boot logs these lines. Timestamps in the real monitor are omitted here. `my-network` is whatever SSID you configured. The version is `PROJECT_VER` from `CMakeLists.txt`. On a board you erased, the build number is 0. The `device=` value is the Wi-Fi station MAC this firmware will check in as, and it has to be the device id you entered for the token.

```
wifi: connecting to my-network ...
wifi: got IP
simpleota: init: device=aa:bb:cc:dd:ee:ff chip=esp32 build=0 keys=0 interval=3600s
example: version 1.0.0, build 0 ; OTA task started
simpleota: check: no update (no_active_deployment)
```

`chip=` is the target you built. `keys=0` means this build has no pinned signing key. `interval=3600s` is the hourly check. The words in parentheses on the last line are the server's status. Before a rollout exists, one status the server returns is `no_active_deployment`. That check runs in the background, so it can show up just before or just after the version line.

The program waits until Wi-Fi has an IP address before it starts the client. Leave the board powered if you want to watch the first release arrive. Quit the monitor with Ctrl+].

## Add the GitHub secrets and variables

The workflow file is `.github/workflows/firmware.yml`. It reads four repository secrets and two repository variables. In your repository, open **Settings**, then **Secrets and variables**, then **Actions**. Add secrets on the **Secrets** tab. Add variables on the **Variables** tab.

`SIMPLEOTA_PROJECT_ID` and `SIMPLEOTA_CHIP` are variables. The workflow reads them with `vars`, not `secrets`. If you add either one on the Secrets tab, the variable the workflow reads is empty. An empty chip builds `esp32`. An empty project id skips the upload when the API token is set.

| Name | Kind | Required | What it does | Where to get it | Example |
| --- | --- | --- | --- | --- | --- |
| `SIMPLEOTA_WIFI_SSID` | Secret | Required on a version tag | Wi-Fi network name compiled into the tag build | The network the board should join | `my-network` |
| `SIMPLEOTA_WIFI_PASSWORD` | Secret | Required on a version tag | Wi-Fi password compiled into the tag build | That network's password | the real password |
| `SIMPLEOTA_DEVICE_TOKEN` | Secret | Required on a version tag | Device token compiled into the tag build | The `soto_dev_` token from **Add device** | `soto_dev_...` |
| `SIMPLEOTA_API_TOKEN` | Secret | Required only to upload | Project token the release action uses to upload and start the rollout | **Project API tokens**, **Issue token**, with the `api` scope | `soto_proj_...` |
| `SIMPLEOTA_PROJECT_ID` | Variable | Required only to upload | Project UUID the release action uploads into | **Project ID** on the project page | a UUID |
| `SIMPLEOTA_CHIP` | Variable | Optional | Chip the tag build, pull requests, and pushes to `main` compile | The same chip you passed to `idf.py set-target` | `esp32s3` |

On a pull request, and on a push to `main`, the workflow copies `sdkconfig.secrets.example` and builds that. It does not need the Wi-Fi secrets, the device token, or the API token. It still uses `SIMPLEOTA_CHIP` when that variable is set.

On a tag whose name starts with `v`, the workflow writes `sdkconfig.secrets` from `SIMPLEOTA_WIFI_SSID`, `SIMPLEOTA_WIFI_PASSWORD`, and `SIMPLEOTA_DEVICE_TOKEN`, then builds. Tag builds take their Wi-Fi settings from the GitHub secrets `SIMPLEOTA_WIFI_SSID` and `SIMPLEOTA_WIFI_PASSWORD`. These must match the network the board uses, or the OTA image will not reconnect. If any of those three is missing, the build fails with `Missing secret <name>.` and nothing is uploaded. The same failure happens when a secret contains a newline (`Secret <name> contains a newline.`) or is still a placeholder from the example file (`Secret <name> is still a placeholder.`). The placeholders are the strings `your-ssid`, `your-password`, and `your-device-token`, and any of the three secrets is rejected when its value is any of those strings.

If `SIMPLEOTA_CHIP` is empty or unset, the build uses `esp32`. If it is any other name than the six chips listed above, the build fails with `Unsupported SIMPLEOTA_CHIP '<value>'. Supported chips: esp32, esp32s2, esp32s3, esp32c3, esp32c6, esp32h2.`

If `SIMPLEOTA_API_TOKEN` is empty, the tag still builds, the job stays green, and the job summary heading is `SimpleOTA upload skipped`. The paragraph under it says: `The SIMPLEOTA_API_TOKEN secret is not set. This tag built the firmware and did not upload it or start a rollout.`

If the API token is set and `SIMPLEOTA_PROJECT_ID` is empty, the job also stays green, and the summary uses that same heading. The paragraph says: `SIMPLEOTA_API_TOKEN is set, but the SIMPLEOTA_PROJECT_ID repository variable is empty. The release action requires both, so nothing was uploaded.` That second check runs only when the API token is present. If both are missing, the summary mentions only the API token.

When both are set, the workflow uploads `build/simpleota_starter.bin` and starts a rollout. It does not pass a signing key, so the uploaded build is unsigned. The release action records this as security `basic`, which is what the Actions summary shows. A successful tag run uses the job summary heading `SimpleOTA release`. The table under it lists Build, Version, Security (`basic`), and Channel (`stable` at 100%).

## Cut a release

The version the device reports is `PROJECT_VER` in `CMakeLists.txt`. The workflow reads whatever version string is inside `set(PROJECT_VER "...")`, and it recognizes the line only when the quotes and the spaces match that form. The file starts as:

```
set(PROJECT_VER "1.0.0")
```

1. Change the version inside the quotes. Keep the rest of the line as it is. For this example the new version is `1.0.1`:

```
set(PROJECT_VER "1.0.1")
```

2. Commit that change, tag it, and push the tag. The tag is the letter `v` followed immediately by the same version text. `v1.0.1` matches `1.0.1`.

```bash
git add CMakeLists.txt
git commit -m "Release 1.0.1"
git tag v1.0.1
git push origin HEAD
git push origin v1.0.1
```

Pushing the `v1.0.1` tag is what starts the release. The workflow compares the tag, with that one leading `v` removed, to `PROJECT_VER`. Those two texts have to be identical, so the tag must be `v` followed by the version string you set. A tag pushed while the file still says `1.0.0` fails the Build job with `Tag v1.0.1 does not match PROJECT_VER 1.0.0.` and nothing is uploaded. If the `PROJECT_VER` line is missing, or it is no longer `set(PROJECT_VER "...")` with your version string in the quotes, the job fails with `PROJECT_VER was not found in CMakeLists.txt.`

Watch the run on GitHub under the **Actions** tab. The workflow is named **Firmware**, and the job is named **Build**. A green run on a pull request, or on a push to `main`, only means that chip compiled. The upload runs on the tag. Open the tag's job summary to see whether the upload ran or was skipped.

## The over-the-air update

A tag run that had both the API token and the project id uploads the binary and starts the rollout. That image takes its Wi-Fi settings from `SIMPLEOTA_WIFI_SSID` and `SIMPLEOTA_WIFI_PASSWORD`, and those secrets have to match the network the board uses, or the image will not reconnect. The release action sends it to the channel named `stable`, at 100 percent. Devices belong to `stable` by default.

To see what was uploaded, open the project and switch on **Advanced** mode. That toggle is at the top right of the project. Advanced mode shows firmware artifacts and deployments. The uploaded build is listed on the **Firmware artifacts** page, with its build number, version label, framework, and chip family. The rollout is listed on the **Deployments** page. The project page also keeps a summary card for deployments, and an active rollout stays on that card. Open the deployment detail page to see its check-in counts, including how many confirmed and how many failed or rolled back. Those cards refresh on their own.

The device checks in when it starts, which includes a reset, and then about once an hour. The first check runs after Wi-Fi has an IP address. If the rollout is already active, resetting the board is the way to make it look immediately, instead of waiting for the hour.

While the monitor is open, a download logs these lines. The build number is the one SimpleOTA assigned. The byte counts are how much of the image has been written and how big the image is. Progress from this project is logged at each new 10 percent mark, through `downloading: 100%`.

```
example: update available: build 2
example: downloading: 10% (17000/170000 bytes)
example: downloading: 100% (170000/170000 bytes)
```

There is no separate "checksum ok" line. The component compares the SHA-256 checksum after the download. When it matches, the next line is `simpleota: update to build 2 flashed`, and the board reboots. This project does not print its own reboot line. When the checksum does not match, the monitor shows `simpleota: checksum mismatch: got <hex> want <hex>`, then `simpleota: update failed: checksum_mismatch`, and `example: update failed: checksum_mismatch`. The board stays on the firmware it was already running.

On the next boot the new image is a trial. The component prints the trial first, then this project echoes it, then the version line:

```
simpleota: trial boot of build 2 ; confirm within 300 s
example: trial boot of build 2 (unconfirmed)
example: version 1.0.1, build 2 ; OTA task started
```

The new image confirms itself on the first successful check-in after that trial boot. The monitor then shows:

```
simpleota: trial image confirmed (build 2)
example: build 2 confirmed
```

The bootloader rollback setting from the first USB flash is what makes that trial safe. A new image gets exactly one attempt until it is confirmed. If it crashes or loses power before confirmation, the next boot returns to the previous application, which is still in the other OTA slot. The component also waits 300 seconds, the window in the trial line above, for the new image to finish a successful check-in. If the image stays running but never confirms in that window, the monitor shows `simpleota: confirm_timeout: rolling back to build <previous>`, and the board reboots into the previous application. After a rollback the previous build number is restored, so a later fixed release can be offered again. The boot that comes back logs `simpleota: rollback detected (confirm_timeout): running 0x<addr> but new image was at 0x<addr>`.

## Troubleshooting

These are the failures the scripts and the workflow print.

`sdkconfig.secrets is missing. Copy sdkconfig.secrets.example to sdkconfig.secrets and fill it in.` `scripts/build.sh` stops when the file is not there. Copy the example, as in the local secrets section. The project also lists that file in `SDKCONFIG_DEFAULTS`, so `idf.py` cannot configure the project until the file exists.

When `scripts/secrets.sh` rejects the file, the message is one of the lines under Add local secrets. That section is the description of those errors.

The three secret errors below quote `SIMPLEOTA_WIFI_SSID` and use the same wording for `SIMPLEOTA_WIFI_PASSWORD` and `SIMPLEOTA_DEVICE_TOKEN`, and the check-in line that quotes HTTP 401 uses the same wording for HTTP 403.

`Missing secret SIMPLEOTA_WIFI_SSID.` The tag build stops, and nothing is uploaded. Add the missing secret on the **Secrets** tab. An empty secret produces this line too.

`Secret SIMPLEOTA_WIFI_SSID contains a newline.` One of the three release secrets contains a line break. Enter it as a single line.

`Secret SIMPLEOTA_WIFI_SSID is still a placeholder.` The secret's value is `your-ssid`, `your-password`, or `your-device-token`. Replace it with the real network name, password, or device token.

`Unsupported SIMPLEOTA_CHIP 'esp32c2'. Supported chips: esp32, esp32s2, esp32s3, esp32c3, esp32c6, esp32h2.` The chip variable is not one of those six names. Fix `SIMPLEOTA_CHIP` on the **Variables** tab, or remove it to build `esp32`. This check runs for tags, pull requests, and pushes to `main`.

`PROJECT_VER was not found in CMakeLists.txt.` The version line is missing, or it is no longer `set(PROJECT_VER "...")` with the version string you set inside the quotes. Put the line back in that shape. The version string is whatever you set, and the tag must be `v` followed by that string.

`Tag v1.2.0 does not match PROJECT_VER 1.0.0.` The tag must be `v` followed by the version string you set. In this example the tag and that string differ, so the job stops and nothing is uploaded. Delete the bad tag, or make the version string and the tag the same text, then push the matching tag.

The job summary heading `SimpleOTA upload skipped` means the tag compiled and was not uploaded. Read the paragraph under it. It names either a missing `SIMPLEOTA_API_TOKEN` secret or an empty `SIMPLEOTA_PROJECT_ID` variable. The job is green on purpose in both cases. A successful tag run instead shows the heading `SimpleOTA release`, and that table lists Build, Version, Security (`basic`), and Channel (`stable` at 100%).

`wifi: disconnected; retrying` The board cannot join the network compiled into this firmware. A USB flash uses `sdkconfig.secrets`. A tag build uses `SIMPLEOTA_WIFI_SSID` and `SIMPLEOTA_WIFI_PASSWORD`. The version line does not appear until `wifi: got IP`, and the monitor waits until that happens. Check the SSID and password, then flash again.

`simpleota: server rejected the token (HTTP 401). Check your project token.` The check-in was refused. The wording "Check your project token" is generic. The firmware always uses the device token (`soto_dev_`), never a `soto_proj_` API token. The device token does not match this device, or it was copied wrong. The `device=` value in the init line is the id the token has to be issued for.

`example: update failed: checksum_mismatch` The download did not match the checksum, so the board stayed on its current firmware. The component logs `simpleota: checksum mismatch:` and `simpleota: update failed: checksum_mismatch` on the same failure. Other failures use the same `example: update failed:` line with a different reason.

## Help

See the [SimpleOTA documentation](https://wiki.simpleota.com/).

## License

MIT. See [LICENSE](LICENSE).
