# The Flutter tooling requires CMake 3.10 or later.
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "kinetic_player")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "kinetic_player_plugin")
set(KINETIC_NATIVE_MPV_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../native/mpv")

find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)
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
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter PkgConfig::GTK PkgConfig::MPV)

set(kinetic_player_bundled_libraries
  ""
  PARENT_SCOPE
)
