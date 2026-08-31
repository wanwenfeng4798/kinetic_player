#ifndef KINETIC_MPV_PNG_ENCODE_H_
#define KINETIC_MPV_PNG_ENCODE_H_

#include <cstdint>
#include <vector>

namespace kinetic {

// Encodes packed RGBA8888 (no padding) to PNG bytes. Empty on failure.
std::vector<uint8_t> EncodePngRgba(const uint8_t* rgba, int width, int height);

}  // namespace kinetic

#endif  // KINETIC_MPV_PNG_ENCODE_H_
