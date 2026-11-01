// Read only this test process's output-session peak levels; no audio is recorded.
#include <windows.h>
#include <mmdeviceapi.h>
#include <audiopolicy.h>
#include <endpointvolume.h>
#include <wrl/client.h>
#include <algorithm>
#include <cstdlib>
#include <iostream>
#include <vector>
using Microsoft::WRL::ComPtr;

int main(int argc, char** argv) {
  if (argc != 2) return 2;
  const DWORD target = static_cast<DWORD>(std::strtoul(argv[1], nullptr, 10));
  if (!target || FAILED(CoInitializeEx(nullptr, COINIT_MULTITHREADED))) return 3;
  int result = 0;
  {
    ComPtr<IMMDeviceEnumerator> enumerator;
    ComPtr<IMMDeviceCollection> devices;
    std::vector<ComPtr<IAudioMeterInformation>> meters;
    HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
        CLSCTX_ALL, IID_PPV_ARGS(&enumerator));
    if (SUCCEEDED(hr)) hr = enumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, &devices);
    UINT count = 0;
    if (SUCCEEDED(hr)) hr = devices->GetCount(&count);
    for (UINT i = 0; SUCCEEDED(hr) && i < count; ++i) {
      ComPtr<IMMDevice> device;
      ComPtr<IAudioSessionManager2> manager;
      ComPtr<IAudioSessionEnumerator> sessions;
      if (FAILED(devices->Item(i, &device)) ||
          FAILED(device->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL, nullptr, &manager)) ||
          FAILED(manager->GetSessionEnumerator(&sessions))) continue;
      int session_count = 0;
      if (FAILED(sessions->GetCount(&session_count))) continue;
      for (int j = 0; j < session_count; ++j) {
        ComPtr<IAudioSessionControl> session;
        ComPtr<IAudioSessionControl2> control;
        ComPtr<IAudioMeterInformation> meter;
        DWORD process_id = 0;
        if (SUCCEEDED(sessions->GetSession(j, &session)) &&
            SUCCEEDED(session.As(&control)) &&
            SUCCEEDED(control->GetProcessId(&process_id)) && process_id == target &&
            SUCCEEDED(session.As(&meter))) meters.push_back(meter);
      }
    }
    float peak = 0;
    int samples = 0;
    for (int tick = 0; tick < 150 && !meters.empty(); ++tick) {
      for (const auto& meter : meters) {
        float value = 0;
        if (SUCCEEDED(meter->GetPeakValue(&value))) {
          peak = (std::max)(peak, value);
          ++samples;
        }
      }
      Sleep(10);
    }
    std::cout << "{\"peak\":" << peak << ",\"samples\":" << samples
              << ",\"sessions\":" << meters.size() << "}" << std::endl;
    if (meters.empty() || samples == 0) result = 4;
  }
  CoUninitialize();
  return result;
}
