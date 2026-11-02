#include "mpv_player.h"

#include <atomic>
#include <chrono>
#include <cstdlib>
#include <iostream>
#include <thread>

using namespace std::chrono_literals;

// Real libmpv regression: run under gdb to retain the crashing native stack.
int main(int argc, char** argv) {
  if (argc < 2 || argc > 3) return 2;
  const int metadata_rotation = argc == 3 ? std::atoi(argv[2]) : 0;
  kinetic::MpvPlayer player;
  std::atomic<int> frames{0};
  kinetic::MpvPlayer::Callbacks callbacks;
  callbacks.post_to_ui = [](std::function<void()> fn) { fn(); };
  callbacks.on_frame = [&] { ++frames; };
  callbacks.on_error = [](const std::string& error, int) {
    std::cerr << error << std::endl;
    std::exit(3);
  };
  if (!player.Init(std::move(callbacks))) return 4;
  player.SetOutputSize(958, 380);
  player.Load(argv[1], true);
  for (int i = 0; i < 200 && frames < 3; ++i) std::this_thread::sleep_for(50ms);
  if (frames < 3) return 5;
  auto await_frame = [&] {
    const int before = frames;
    for (int i = 0; i < 100 && frames < before + 3; ++i)
      std::this_thread::sleep_for(50ms);
    if (frames < before + 3) std::exit(6);
  };
  for (const int angle : {0, 90, 180, 270, 0}) {
    std::cout << "ROTATE " << angle << std::endl;
    player.SetRotation(angle);
    await_frame();
    if (player.CapturePng().empty()) return 7;
    std::vector<uint8_t> pixels;
    int w, h;
    if (!player.CopyRgbaFrame(pixels, w, h)) return 8;
    double rx = 0, ry = 0, bx = 0, by = 0, red = 0, blue = 0;
    for (int y = 0; y < h; ++y) for (int x = 0; x < w; ++x) {
      auto i = (y * w + x) * 4;
      if (pixels[i] > 180 && pixels[i+2] < 70) { rx += x; ry += y; ++red; }
      if (pixels[i+2] > 180 && pixels[i] < 70) { bx += x; by += y; ++blue; }
    }
    if (!red || !blue) return 9;
    rx /= red; ry /= red; bx /= blue; by /= blue;
    const int expected = (angle + metadata_rotation) % 360;
    bool correct = expected == 0 ? ry < by : expected == 90 ? rx > bx :
                   expected == 180 ? ry > by : rx < bx;
    if (!correct) return 10;
  }
  for (int mode = 0; mode < 6; ++mode) {
    player.SetShowType(mode);
    for (int angle : {0, 90, 180, 270, 45, -90, 450}) {
      player.SetRotation(angle);
      for (auto size : {std::pair<int,int>{957,379}, {281,501}, {480,320}}) {
        std::cout << "MATRIX aspect=" << mode << " angle=" << angle
                  << " size=" << size.first << 'x' << size.second << std::endl;
        player.SetOutputSize(size.first, size.second);
        player.SetMirrorHorizontal(mode % 2);
        player.SetMirrorVertical(mode % 3 == 0);
        await_frame();
        if (player.CapturePng().empty()) return 11;
        std::vector<uint8_t> pixels;
        int w, h;
        if (!player.CopyRgbaFrame(pixels, w, h) ||
            w != size.first || h != size.second) return 12;
      }
    }
  }
  for (const auto* decoder : {"no", "auto-safe"}) {
    player.SetHwdec(decoder);
    await_frame();
    if (player.CapturePng().empty()) return 13;
  }
  for (int scale = 0; scale < 3; ++scale) {
    player.SetScaleMode(scale);
    await_frame();
  }
  auto tracks = player.GetVideoTracks();
  if (tracks.empty() || !player.SelectVideoTrack(tracks.front().index) ||
      !player.SelectVideoTrack(-1)) return 14;
  if (player.GetNetSpeed().bytes_per_second < 0) return 15;
  player.Shutdown();
  std::cout << "PASS orientation pixels and 126 rotation/aspect/resize/mirror combinations" << std::endl;
}
