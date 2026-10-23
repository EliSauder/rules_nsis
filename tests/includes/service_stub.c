/* A minimal Windows service for the Sc.nsh lifecycle test: it reports
 * RUNNING once started and STOPPED when asked to stop. */
#include <windows.h>

static SERVICE_STATUS_HANDLE status_handle;
static SERVICE_STATUS status;
static HANDLE stop_event;

static void report(DWORD state) {
  status.dwCurrentState = state;
  status.dwControlsAccepted = state == SERVICE_RUNNING ? SERVICE_ACCEPT_STOP : 0;
  SetServiceStatus(status_handle, &status);
}

static DWORD WINAPI control(DWORD code, DWORD type, LPVOID data, LPVOID context) {
  (void)type;
  (void)data;
  (void)context;
  if (code == SERVICE_CONTROL_STOP) {
    report(SERVICE_STOP_PENDING);
    SetEvent(stop_event);
    return NO_ERROR;
  }
  return code == SERVICE_CONTROL_INTERROGATE ? NO_ERROR : ERROR_CALL_NOT_IMPLEMENTED;
}

static void WINAPI service_main(DWORD argc, LPWSTR *argv) {
  (void)argc;
  (void)argv;
  status_handle = RegisterServiceCtrlHandlerExW(L"", control, NULL);
  if (!status_handle) {
    return;
  }
  status.dwServiceType = SERVICE_WIN32_OWN_PROCESS;
  stop_event = CreateEventW(NULL, TRUE, FALSE, NULL);
  report(SERVICE_RUNNING);
  WaitForSingleObject(stop_event, INFINITE);
  CloseHandle(stop_event);
  report(SERVICE_STOPPED);
}

int main(void) {
  SERVICE_TABLE_ENTRYW table[] = {{L"", service_main}, {NULL, NULL}};
  return StartServiceCtrlDispatcherW(table) ? 0 : (int)GetLastError();
}
