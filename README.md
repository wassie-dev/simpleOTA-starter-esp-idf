# SimpleOTA Starter ESP-IDF

## What this repo is

This repository is a GitHub template for starting your own ESP-IDF project with [SimpleOTA](https://simpleota.com), a hosted service that delivers firmware updates to ESP32 boards over Wi-Fi. Rather than working in this repository directly, you click **Use this template** to make your own copy, add your SimpleOTA and Wi-Fi settings, and flash the board once over USB. From then on, pushing a version tag ships new firmware.

Your copy comes with three pieces that already work together:

- `main/` is an ESP-IDF application that joins your Wi-Fi and uses the [simpleota](https://components.espressif.com/components/xanderwasserman/simpleota) component to check SimpleOTA for new firmware, install it, and confirm it after the board restarts.
- `.github/workflows/firmware.yml` builds the project on every push to `main` and every pull request, and when you push a tag such as `v1.0.1` it uploads that build to your SimpleOTA project with [simpleOTA-actions](https://github.com/wassie-dev/simpleOTA-actions).
- `scripts/build.sh` builds the same firmware on your computer for the first USB flash.

The firmware uses the [xanderwasserman/simpleota](https://components.espressif.com/components/xanderwasserman/simpleota) component at version 0.2.1. This starter does not sign firmware, so the release workflow uploads the application binary unsigned and the release action records it as security `basic`, which is what the Actions summary shows.

## Before you start

You need all of the following.

1. An ESP32 board with 4 MB of flash, because the project sets the flash size to 4 MB and the partition table holds two 1700 KB application slots, which a board with less flash cannot use.
2. A USB cable that connects the board to your computer.
3. A [SimpleOTA](https://simpleota.com) account.
4. ESP-IDF, with `idf.py` available in the terminal you use for the steps below. This repository's CI builds with ESP-IDF v5.5.5, which is the tested version, and [Espressif's get-started guide for v5.5.5](https://docs.espressif.com/projects/esp-idf/en/v5.5.5/esp32/get-started/index.html) covers the install.

## Create your repository

1. On this repository's GitHub page, click **Use this template** and create your own repository.
2. Clone that repository and move into it, since every later command assumes it is your current directory.

```bash
git clone https://github.com/YOUR_USER/YOUR_REPO.git
cd YOUR_REPO
```

## Set up SimpleOTA

Create one project, then collect three values: the device token, which goes in `sdkconfig.secrets` and in GitHub, and the API token and project ID, which go in GitHub only. The [first project](https://wiki.simpleota.com/getting-started/first-project/) guide covers creating the project and finding its ID, the [device tokens](https://wiki.simpleota.com/guides/device-tokens/) guide covers the device token, and the [tokens](https://wiki.simpleota.com/dashboard/tokens/) page explains the API token's scopes.

### Create the project

1. Sign in and open the dashboard.
2. Click **Projects**, then **New project**.
3. Give the project a name, and SimpleOTA generates the slug from it. If you want a different slug, use **Edit** next to that field; the docs recommend a lowercase hyphenated form such as `office-thermostat`.
4. Save.

You cannot change the name or the slug later, because the only way to do that is to delete the project and create it again, which also deletes the project's devices, artifacts, and build counter.

### Copy the project ID

Open the project and copy the **Project ID**, the UUID under the project name, with its copy button. It goes in the `SIMPLEOTA_PROJECT_ID` repository variable (a variable, not a secret), because API calls address the project by this UUID and the slug is only a label for people.

### Create the device token

This firmware sends the board's Wi-Fi station MAC as its device id, written in lowercase hexadecimal with colons like `aa:bb:cc:dd:ee:ff`. A device token works for exactly one device id and cannot register a device that does not exist yet, so create the device row before the first flash and enter that MAC as the device id.

The ESP-IDF 5.5 line installs esptool 4, and you need to load the ESP-IDF v5.5.5 environment (`. $IDF_PATH/export.sh`, or the ESP-IDF terminal on Windows) before you run `esptool.py` or `idf.py`, as [Espressif's get-started guide for v5.5.5](https://docs.espressif.com/projects/esp-idf/en/v5.5.5/esp32/get-started/index.html) describes. Then print the address programmed into the chip:

```bash
esptool.py -p PORT read_mac
```

Replace `PORT` with the board's serial port. The command prints the base MAC, which under Espressif's default MAC allocation is the same Wi-Fi station MAC this firmware sends, so rewrite it in lowercase with colons before you paste it into Add device.

1. Open the project.
2. In the **Devices** card, click **Add device**.
3. Enter the MAC as the device id and leave out hardware metadata, since the board reports its chip and framework on its first check-in.
4. Submit the form.
5. Copy the raw token from the yellow alert box right away, because it is shown once and cannot be retrieved again.

The token starts with `soto_dev_` and is the value for `CONFIG_EXAMPLE_SIMPLEOTA_TOKEN` in `sdkconfig.secrets` and for the `SIMPLEOTA_DEVICE_TOKEN` repository secret. This starter compiles that one token into the firmware, so the firmware you flash and the firmware CI builds both authenticate as this device.

If the device row already exists, the device tokens guide also describes issuing the token from the device itself: open it from the Devices list and, in the **Authentication** section of its detail page, click **Issue token** (or **Rotate token** if one already exists), then copy the raw token from the yellow alert box. A brand new board has not checked in yet, so **Add device** is the path that gives you a token before the first flash.

### Create the API token

The upload needs a project API token with the `api` scope. A project token's scopes are checkboxes and a new token defaults to `device` only, which can only check for updates, while `api` is the scope that can upload firmware and manage deployments. This token never goes on the board, because the firmware uses the device token above.

1. Open the project.
2. On the **Project API tokens** card, click **Issue token**.
3. Include the `api` scope, and give the token a name you will recognize later, such as `ci-upload`.
4. Copy the token right away, because it is shown once and SimpleOTA stores only a hash.

The token starts with `soto_proj_` and is the value for the `SIMPLEOTA_API_TOKEN` repository secret.

## Choose the chip

This starter accepts these chip names:

`esp32`, `esp32s2`, `esp32s3`, `esp32c3`, `esp32c6`, `esp32h2`

The default is `esp32`, so pick the name that matches your board and pass it to the `idf.py set-target` command in the flash section once `sdkconfig.secrets` is filled in.

Use the same name for the `SIMPLEOTA_CHIP` repository variable in the GitHub section below. The board reports the chip family it was compiled for, and a tag build compiles `SIMPLEOTA_CHIP` (or `esp32` when that variable is empty) and labels the upload with that chip, so the local target and `SIMPLEOTA_CHIP` both have to be the chip on the board you ship, or the rollout is for a different chip than the one you flashed.

## Add local secrets

The project reads the Wi-Fi credentials and the device token from `sdkconfig.secrets`, which is gitignored. Copy the example, then replace the three placeholders:

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

Fill in this file before you run `idf.py set-target` in the flash section, because ESP-IDF applies `sdkconfig.defaults` and `sdkconfig.secrets` only when it creates `sdkconfig` and does not re-read them after that. If you change `sdkconfig.secrets` later, delete `sdkconfig` and run `idf.py set-target` again with the same chip.

A release build uses `scripts/secrets.sh` to accept or reject this file. Blank lines are allowed, and so is a comment line whose first non-whitespace character is `#`, but every other line must be one of the three options above with its value wrapped in double quotes. The script rejects anything else:

- A line that is not one `CONFIG_...=` setting is rejected with `sdkconfig.secrets contains a line other than the Wi-Fi SSID, Wi-Fi password, and device token options.`
- Any other `CONFIG_` name is rejected with `sdkconfig.secrets must not set <name>.`
- A value that is not wrapped in double quotes is rejected with `sdkconfig.secrets has a malformed <name> line.`
- An empty value, or a value that is only spaces, is rejected with `sdkconfig.secrets sets a blank <name>.`
- A value that is still `your-ssid`, `your-password`, or `your-device-token` is rejected with `sdkconfig.secrets uses a placeholder value.`
- A file that omits any of the three options is rejected with `sdkconfig.secrets does not set the Wi-Fi and device token options.`

If a release check runs and the file is not there, the script stops with `Release build is missing sdkconfig.secrets.` Running the script without `write` or `check` prints `Usage: secrets.sh write|check`. The workflow calls `write` on a tag, and `scripts/build.sh` calls `check` on a release build.

A normal local `idf.py build` does not run that script, but a tag build does, so fill in real values now and the first flash and the later release will use the same credentials.

## Flash over USB

You only do this once per board. Replace `esp32` with the chip you chose and `PORT` with the board's serial port.

1. Set the target, which needs `sdkconfig.secrets` to exist already:

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

`idf.py flash` writes the bootloader, the partition table, the OTA data, and the app, and leaves the rest of the flash alone, so an older layout can leave a SimpleOTA build number behind in NVS. The server then treats the board as already running that build and will not offer the update you just flashed. `idf.py erase-flash` clears the chip so the new table and a build number of 0 start clean, and a board that has never been flashed can skip the erase.

4. Flash the firmware and open the serial monitor:

```bash
idf.py -p PORT flash monitor
```

This first flash installs the bootloader, the rollback setting inside it, and the partition table from `partitions.csv`, and over-the-air updates cannot change any of those because they only replace the application in the inactive slot. The table has two slots, `ota_0` and `ota_1`, and a serial flash boots `ota_0`, after which updates alternate between the two.

A healthy boot logs these lines, shown here without the monitor's timestamps. `my-network` is whatever SSID you configured, the version is `PROJECT_VER` from `CMakeLists.txt`, and on a board you erased the build number is 0. The `device=` value is the Wi-Fi station MAC this firmware will check in as, and it has to be the device id you entered for the token.

```
wifi: connecting to my-network ...
wifi: got IP
simpleota: init: device=aa:bb:cc:dd:ee:ff chip=esp32 build=0 keys=0 interval=3600s
example: version 1.0.0, build 0 ; OTA task started
simpleota: check: no update (no_active_deployment)
```

`chip=` is the target you built, `keys=0` means this build has no pinned signing key, and `interval=3600s` is the hourly check. The words in parentheses on the last line are the server's status, and before a rollout exists one status it returns is `no_active_deployment`. That check runs in the background, so it can show up just before or just after the version line.

The program waits until Wi-Fi has an IP address before it starts the client. Leave the board powered if you want to watch the first release arrive, and quit the monitor with Ctrl+] when you are done.

## Add the GitHub secrets and variables

The workflow in `.github/workflows/firmware.yml` reads four repository secrets and two repository variables. In your repository, open **Settings**, then **Secrets and variables**, then **Actions**, and add each one on the **Secrets** or **Variables** tab to match the Kind column in the table below.

`SIMPLEOTA_PROJECT_ID` and `SIMPLEOTA_CHIP` are variables, which the workflow reads with `vars` rather than `secrets`, so adding either one on the Secrets tab leaves the variable the workflow reads empty. An empty chip builds `esp32`, and an empty project ID skips the upload when the API token is set.

| Name | Kind | Required | What it does | Where to get it | Example |
| --- | --- | --- | --- | --- | --- |
| `SIMPLEOTA_WIFI_SSID` | Secret | Required on a version tag | Wi-Fi network name compiled into the tag build | The network the board should join | `my-network` |
| `SIMPLEOTA_WIFI_PASSWORD` | Secret | Required on a version tag | Wi-Fi password compiled into the tag build | That network's password | the real password |
| `SIMPLEOTA_DEVICE_TOKEN` | Secret | Required on a version tag | Device token compiled into the tag build | The `soto_dev_` token from **Add device** | `soto_dev_...` |
| `SIMPLEOTA_API_TOKEN` | Secret | Required only to upload | Project token the release action uses to upload and start the rollout | **Project API tokens**, **Issue token**, with the `api` scope | `soto_proj_...` |
| `SIMPLEOTA_PROJECT_ID` | Variable | Required only to upload | Project UUID the release action uploads into | **Project ID** on the project page | a UUID |
| `SIMPLEOTA_CHIP` | Variable | Optional | Chip the tag build, pull requests, and pushes to `main` compile | The same chip you passed to `idf.py set-target` | `esp32s3` |

On a pull request or a push to `main`, the workflow copies `sdkconfig.secrets.example` and builds that, so it does not need the Wi-Fi secrets, the device token, or the API token, though it still uses `SIMPLEOTA_CHIP` when that variable is set.

On a tag whose name starts with `v`, the workflow writes `sdkconfig.secrets` from `SIMPLEOTA_WIFI_SSID`, `SIMPLEOTA_WIFI_PASSWORD`, and `SIMPLEOTA_DEVICE_TOKEN`, then builds, so the two Wi-Fi secrets must match the network the board uses or the OTA image will not reconnect. If any of those three is missing, the build fails with `Missing secret <name>.` and nothing is uploaded. The same failure happens when a secret contains a newline (`Secret <name> contains a newline.`) or is still a placeholder from the example file (`Secret <name> is still a placeholder.`), which means its value is `your-ssid`, `your-password`, or `your-device-token`.

If `SIMPLEOTA_CHIP` is empty or unset, the build uses `esp32`. If it is anything other than the six chips listed above, the build fails with `Unsupported SIMPLEOTA_CHIP '<value>'. Supported chips: esp32, esp32s2, esp32s3, esp32c3, esp32c6, esp32h2.`

If `SIMPLEOTA_API_TOKEN` is empty, the tag still builds, the job stays green, and the job summary heading is `SimpleOTA upload skipped`. The paragraph under it says: `The SIMPLEOTA_API_TOKEN secret is not set. This tag built the firmware and did not upload it or start a rollout.`

If the API token is set and `SIMPLEOTA_PROJECT_ID` is empty, the job also stays green, and the summary uses that same heading. The paragraph says: `SIMPLEOTA_API_TOKEN is set, but the SIMPLEOTA_PROJECT_ID repository variable is empty. The release action requires both, so nothing was uploaded.` That second check runs only when the API token is present, so if both are missing the summary mentions only the API token.

When both are set, the workflow uploads `build/simpleota_starter.bin` and starts a rollout without passing a signing key, which is why the release action records the build as security `basic`. A successful tag run uses the job summary heading `SimpleOTA release`, and the table under it lists Build, Version, Security (`basic`), and Channel (`stable` at 100%).

## Cut a release

The version the device reports is `PROJECT_VER` in `CMakeLists.txt`, and the workflow reads whatever version string is inside `set(PROJECT_VER "...")`, recognizing the line only when the quotes and the spaces match that form. The file starts as:

```
set(PROJECT_VER "1.0.0")
```

1. Change the version inside the quotes and leave the rest of the line as it is. In this example the new version is `1.0.1`:

```
set(PROJECT_VER "1.0.1")
```

2. Commit that change, tag it, and push the tag, which is the letter `v` followed immediately by the same version text, so `v1.0.1` matches `1.0.1`.

```bash
git add CMakeLists.txt
git commit -m "Release 1.0.1"
git tag v1.0.1
git push origin HEAD
git push origin v1.0.1
```

Pushing the `v1.0.1` tag starts the release, and the workflow removes that one leading `v` and compares the rest to `PROJECT_VER`, so the two texts have to be identical. A tag pushed while the file still says `1.0.0` fails the Build job with `Tag v1.0.1 does not match PROJECT_VER 1.0.0.` and nothing is uploaded. If the `PROJECT_VER` line is missing, or it is no longer `set(PROJECT_VER "...")` with your version string in the quotes, the job fails with `PROJECT_VER was not found in CMakeLists.txt.`

Watch the run under the **Actions** tab on GitHub, where the workflow is named **Firmware** and the job is named **Build**. A green run on a pull request or a push to `main` only means that chip compiled, because the upload runs on the tag, so open the tag's job summary to see whether the upload ran or was skipped.

## The over-the-air update

A tag run that had both the API token and the project ID uploads the binary and starts the rollout, and the release action sends it to the channel named `stable` at 100 percent, which is the channel devices belong to by default.

To see what was uploaded, open the project and switch on **Advanced** mode with the toggle at the top right, which shows firmware artifacts and deployments. The uploaded build is listed on the **Firmware artifacts** page with its build number, version label, framework, and chip family, and the rollout is listed on the **Deployments** page. An active rollout also stays on the deployments summary card on the project page, and the deployment detail page shows its check-in counts, including how many confirmed and how many failed or rolled back. Those cards refresh on their own.

The device checks in when it starts, including after a reset, and then about once an hour, with the first check running once Wi-Fi has an IP address. If the rollout is already active, you can reset the board to make it look right away instead of waiting for the hour.

While the monitor is open, a download logs these lines, where the build number is the one SimpleOTA assigned and the byte counts show how much of the image has been written out of its full size. This project logs progress at each new 10 percent mark, through `downloading: 100%`.

```
example: update available: build 2
example: downloading: 10% (17000/170000 bytes)
example: downloading: 100% (170000/170000 bytes)
```

The component compares the SHA-256 checksum after the download without printing a separate "checksum ok" line, so when it matches the next line is `simpleota: update to build 2 flashed` and the board reboots, and this project does not print a reboot line of its own. When the checksum does not match, the monitor shows `simpleota: checksum mismatch: got <hex> want <hex>`, then `simpleota: update failed: checksum_mismatch`, and `example: update failed: checksum_mismatch`, and the board stays on the firmware it was already running.

On the next boot the new image runs as a trial. The component logs the trial boot, this project echoes it, and then the version line follows:

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

The bootloader rollback setting from the first USB flash is what makes that trial safe. A new image gets exactly one attempt until it is confirmed, and if it crashes or loses power before then, the next boot returns to the previous application, which is still in the other OTA slot. The component also gives the new image 300 seconds, the window in the trial line above, to finish a successful check-in, and if it stays running but never confirms in that window, the monitor shows `simpleota: confirm_timeout: rolling back to build <previous>` and the board reboots into the previous application. The boot that comes back logs `simpleota: rollback detected (confirm_timeout): running 0x<addr> but new image was at 0x<addr>`, and because the previous build number is restored, a later fixed release can be offered again.

## Troubleshooting

These are the failures the scripts and the workflow print.

`sdkconfig.secrets is missing. Copy sdkconfig.secrets.example to sdkconfig.secrets and fill it in.` `scripts/build.sh` stops when the file is not there, and because the project also lists that file in `SDKCONFIG_DEFAULTS`, `idf.py` cannot configure the project until it exists either. Copy the example as described under Add local secrets.

When `scripts/secrets.sh` rejects the file, the message is one of the lines listed under Add local secrets, which explains each one.

The three secret errors below quote `SIMPLEOTA_WIFI_SSID`, and the same wording applies to `SIMPLEOTA_WIFI_PASSWORD` and `SIMPLEOTA_DEVICE_TOKEN`. The check-in line that quotes HTTP 401 reads the same way for HTTP 403.

`Missing secret SIMPLEOTA_WIFI_SSID.` The tag build stops and nothing is uploaded, which also happens when the secret exists but is empty, so add or fill in the secret on the **Secrets** tab.

`Secret SIMPLEOTA_WIFI_SSID contains a newline.` One of the three release secrets contains a line break, so enter it again as a single line.

`Secret SIMPLEOTA_WIFI_SSID is still a placeholder.` The secret still holds `your-ssid`, `your-password`, or `your-device-token`, so replace it with the real network name, password, or device token.

`Unsupported SIMPLEOTA_CHIP 'esp32c2'. Supported chips: esp32, esp32s2, esp32s3, esp32c3, esp32c6, esp32h2.` The chip variable is not one of those six names, so fix `SIMPLEOTA_CHIP` on the **Variables** tab or remove it to build `esp32`. This check runs on tags, pull requests, and pushes to `main`.

`PROJECT_VER was not found in CMakeLists.txt.` The version line is missing, or it is no longer `set(PROJECT_VER "...")` with your version string inside the quotes, so put it back in that shape and keep the tag as `v` followed by that string.

`Tag v1.2.0 does not match PROJECT_VER 1.0.0.` The tag is not `v` followed by the version string you set, so the job stops and nothing is uploaded. Delete the bad tag, or make the version string and the tag the same text, then push the matching tag.

The job summary heading `SimpleOTA upload skipped` means the tag compiled but was not uploaded, and the paragraph under it names either a missing `SIMPLEOTA_API_TOKEN` secret or an empty `SIMPLEOTA_PROJECT_ID` variable. The job is green on purpose in both cases. A successful tag run shows the heading `SimpleOTA release` instead, with a table listing Build, Version, Security (`basic`), and Channel (`stable` at 100%).

`wifi: disconnected; retrying` The board cannot join the network compiled into this firmware, which comes from `sdkconfig.secrets` on a USB flash and from `SIMPLEOTA_WIFI_SSID` and `SIMPLEOTA_WIFI_PASSWORD` on a tag build. The version line does not appear until `wifi: got IP`, so check the SSID and password, then flash again.

`simpleota: server rejected the token (HTTP 401). Check your project token.` The server refused the check-in. The client prints "Check your project token" even though this firmware always uses the device token (`soto_dev_`) and never a `soto_proj_` API token, so the device token either does not match this device or was copied wrong. The `device=` value in the init line is the id the token has to be issued for.

`example: update failed: checksum_mismatch` The download did not match the checksum, so the board stayed on its current firmware, and the component logs `simpleota: checksum mismatch:` and `simpleota: update failed: checksum_mismatch` for the same failure. Other failures use the same `example: update failed:` line with a different reason.

## Help

See the [SimpleOTA documentation](https://wiki.simpleota.com/).

## License

MIT. See [LICENSE](LICENSE).
