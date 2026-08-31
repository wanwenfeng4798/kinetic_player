#include "png_encode.h"

#include <cstring>

namespace kinetic {
namespace {

uint32_t CrcTable(int n) {
  uint32_t c = static_cast<uint32_t>(n);
  for (int k = 0; k < 8; k++) {
    c = (c & 1) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1);
  }
  return c;
}

uint32_t Crc32(const uint8_t* data, size_t len, uint32_t crc = 0xFFFFFFFFu) {
  for (size_t i = 0; i < len; i++) {
    crc = CrcTable((crc ^ data[i]) & 0xFF) ^ (crc >> 8);
  }
  return crc;
}

void PutBe32(std::vector<uint8_t>& o, uint32_t v) {
  o.push_back(static_cast<uint8_t>(v >> 24));
  o.push_back(static_cast<uint8_t>(v >> 16));
  o.push_back(static_cast<uint8_t>(v >> 8));
  o.push_back(static_cast<uint8_t>(v));
}

void Chunk(std::vector<uint8_t>& o, const char type[4], const uint8_t* data,
           size_t len) {
  PutBe32(o, static_cast<uint32_t>(len));
  const size_t type_at = o.size();
  o.insert(o.end(), type, type + 4);
  if (len && data) {
    o.insert(o.end(), data, data + len);
  }
  const uint32_t crc = Crc32(o.data() + type_at, 4 + len) ^ 0xFFFFFFFFu;
  PutBe32(o, crc);
}

uint32_t Adler32(const uint8_t* data, size_t len) {
  uint32_t a = 1, b = 0;
  for (size_t i = 0; i < len; i++) {
    a = (a + data[i]) % 65521;
    b = (b + a) % 65521;
  }
  return (b << 16) | a;
}

}  // namespace

std::vector<uint8_t> EncodePngRgba(const uint8_t* rgba, int width, int height) {
  if (!rgba || width <= 0 || height <= 0) {
    return {};
  }
  const size_t row_bytes = static_cast<size_t>(width) * 4 + 1;  // filter byte
  std::vector<uint8_t> raw(row_bytes * static_cast<size_t>(height));
  for (int y = 0; y < height; y++) {
    uint8_t* dst = raw.data() + static_cast<size_t>(y) * row_bytes;
    dst[0] = 0;
    std::memcpy(dst + 1, rgba + static_cast<size_t>(y) * width * 4,
                static_cast<size_t>(width) * 4);
  }

  // zlib stream: 0x78 0x01 + stored blocks + adler32
  std::vector<uint8_t> zlib;
  zlib.push_back(0x78);
  zlib.push_back(0x01);
  size_t offset = 0;
  while (offset < raw.size()) {
    const size_t remain = raw.size() - offset;
    const uint16_t chunk = remain > 65535 ? 65535 : static_cast<uint16_t>(remain);
    const bool last = offset + chunk >= raw.size();
    zlib.push_back(last ? 0x01 : 0x00);
    zlib.push_back(static_cast<uint8_t>(chunk));
    zlib.push_back(static_cast<uint8_t>(chunk >> 8));
    const uint16_t nlen = static_cast<uint16_t>(chunk ^ 0xFFFFu);
    zlib.push_back(static_cast<uint8_t>(nlen));
    zlib.push_back(static_cast<uint8_t>(nlen >> 8));
    zlib.insert(zlib.end(), raw.data() + offset, raw.data() + offset + chunk);
    offset += chunk;
  }
  PutBe32(zlib, Adler32(raw.data(), raw.size()));

  std::vector<uint8_t> png = {137, 80, 78, 71, 13, 10, 26, 10};
  uint8_t ihdr[13];
  ihdr[0] = static_cast<uint8_t>(width >> 24);
  ihdr[1] = static_cast<uint8_t>(width >> 16);
  ihdr[2] = static_cast<uint8_t>(width >> 8);
  ihdr[3] = static_cast<uint8_t>(width);
  ihdr[4] = static_cast<uint8_t>(height >> 24);
  ihdr[5] = static_cast<uint8_t>(height >> 16);
  ihdr[6] = static_cast<uint8_t>(height >> 8);
  ihdr[7] = static_cast<uint8_t>(height);
  ihdr[8] = 8;
  ihdr[9] = 6;  // RGBA
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;
  Chunk(png, "IHDR", ihdr, sizeof(ihdr));
  Chunk(png, "IDAT", zlib.data(), zlib.size());
  Chunk(png, "IEND", nullptr, 0);
  return png;
}

}  // namespace kinetic
