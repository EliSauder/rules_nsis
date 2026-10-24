#include <windows.h>

__declspec(dllexport) void __cdecl Nop(HWND hwndParent, int string_size, LPTSTR variables, void *stacktop, void *extra) {}

BOOL WINAPI DllMain(HINSTANCE hInst, DWORD reason, LPVOID reserved) {
  return TRUE;
}
