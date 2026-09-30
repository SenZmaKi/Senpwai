#include "url_protocol_registration.h"

#include <windows.h>

bool RegisterUrlProtocol(const std::wstring &scheme) {
  wchar_t executable_path[MAX_PATH];
  if (::GetModuleFileNameW(nullptr, executable_path, MAX_PATH) == 0) {
    return false;
  }

  const std::wstring protocol_key_path = L"Software\\Classes\\" + scheme;
  HKEY protocol_key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, protocol_key_path.c_str(), 0,
                        nullptr, REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr,
                        &protocol_key, nullptr) != ERROR_SUCCESS) {
    return false;
  }

  const std::wstring protocol_display_name = L"URL:" + scheme + L" Protocol";
  ::RegSetValueExW(
      protocol_key, nullptr, 0, REG_SZ,
      reinterpret_cast<const BYTE *>(protocol_display_name.c_str()),
      static_cast<DWORD>((protocol_display_name.size() + 1) * sizeof(wchar_t)));

  const wchar_t empty_value[] = L"";
  ::RegSetValueExW(protocol_key, L"URL Protocol", 0, REG_SZ,
                   reinterpret_cast<const BYTE *>(empty_value),
                   sizeof(empty_value));
  ::RegCloseKey(protocol_key);

  const std::wstring command_key_path =
      protocol_key_path + L"\\shell\\open\\command";
  HKEY command_key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, command_key_path.c_str(), 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr,
                        &command_key, nullptr) != ERROR_SUCCESS) {
    return false;
  }

  const std::wstring command =
      L"\"" + std::wstring(executable_path) + L"\" \"%1\"";
  ::RegSetValueExW(command_key, nullptr, 0, REG_SZ,
                   reinterpret_cast<const BYTE *>(command.c_str()),
                   static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  ::RegCloseKey(command_key);

  return true;
}
