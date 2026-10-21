cmake_minimum_required(VERSION 3.16)

set(PROJECT_VER "1.0.0")
set(SDKCONFIG_DEFAULTS "sdkconfig.defaults;sdkconfig.secrets")

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(simpleota_starter)
