# The Flutter tooling requires CMake 3.10 or later.
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "kinetic_player")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "kinetic_player_plugin")
set(KINETIC_NATIVE_MPV_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../native/mpv")

find_package(PkgConfig REQUIRED)
# Match the host embedder. Linking GTK 3 and GTK 4 into one process is unsafe.
set(KINETIC_PLAYER_GTK_VERSION "AUTO" CACHE STRING "Host GTK major: AUTO, 3 or 4")
set_property(CACHE KINETIC_PLAYER_GTK_VERSION PROPERTY STRINGS AUTO 3 4)
set(KINETIC_HOST_GTK_MAJOR "")
if(GTK_VERSION MATCHES "^([34])\\.")
  set(KINETIC_HOST_GTK_MAJOR "${CMAKE_MATCH_1}")
endif()
if(KINETIC_PLAYER_GTK_VERSION STREQUAL "AUTO")
  if(KINETIC_HOST_GTK_MAJOR)
    set(KINETIC_GTK_MAJOR "${KINETIC_HOST_GTK_MAJOR}")
  else()
    set(KINETIC_GTK_MAJOR "3")
  endif()
else()
  set(KINETIC_GTK_MAJOR "${KINETIC_PLAYER_GTK_VERSION}")
endif()
if(NOT KINETIC_GTK_MAJOR MATCHES "^[34]$")
  message(FATAL_ERROR "KINETIC_PLAYER_GTK_VERSION must be AUTO, 3 or 4")
endif()
if(KINETIC_HOST_GTK_MAJOR AND NOT KINETIC_GTK_MAJOR STREQUAL KINETIC_HOST_GTK_MAJOR)
  message(FATAL_ERROR "GTK major must match the Flutter host (${KINETIC_HOST_GTK_MAJOR}); use a matching embedder.")
endif()
if(KINETIC_GTK_MAJOR STREQUAL "4")
  pkg_check_modules(KINETIC_GTK REQUIRED IMPORTED_TARGET gtk4)
else()
  pkg_check_modules(KINETIC_GTK REQUIRED IMPORTED_TARGET gtk+-3.0)
endif()
pkg_check_modules(MPV IMPORTED_TARGET mpv)
if(NOT MPV_FOUND)
  message(FATAL_ERROR
    "libmpv not found. Install libmpv-dev (Debian/Ubuntu) or mpv-libs-devel (Fedora).")
endif()

add_library(${PLUGIN_NAME} SHARED
  "kinetic_player_plugin.cc"
  "${KINETIC_NATIVE_MPV_DIR}/mpv_player.cc"
  "${KINETIC_NATIVE_MPV_DIR}/png_encode.cc"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  CXX_STANDARD 17)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${KINETIC_NATIVE_MPV_DIR}"
  "${KINETIC_NATIVE_MPV_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter PkgConfig::KINETIC_GTK PkgConfig::MPV)

set(kinetic_player_bundled_libraries
  ""
  PARENT_SCOPE
)
