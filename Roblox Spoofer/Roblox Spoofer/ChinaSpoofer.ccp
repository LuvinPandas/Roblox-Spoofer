#include <iostream>
#include <windows.h>
#include <tlhelp32.h> // Process32First, Process32Next
#include <string>
#include <shlobj.h> // SHGetFolderPath
#include <winreg.h> // Registry operations
#include <vector>
#include <sstream>
#include <iomanip>
#include <winnetwk.h>
// Set console text color
void SetConsoleTextColor(WORD color) {
    HANDLE hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
    SetConsoleTextAttribute(hConsole, color);
}

// Reset console text color to default
void ResetConsoleTextColor() {
    SetConsoleTextColor(FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE); // Default color
}

// Print messages with a specific color
void PrintMessage(const std::string& level, const std::string& message, WORD color) {
    SetConsoleTextColor(color);
    std::cout << "[" << level << "] " << message << std::endl;
    ResetConsoleTextColor();
}
// Check if running as admin
bool IsRunningAsAdmin() {
    BOOL isAdmin = FALSE;
    PSID adminGroupSid = NULL;
    SID_IDENTIFIER_AUTHORITY NtAuthority = SECURITY_NT_AUTHORITY;

    if (AllocateAndInitializeSid(&NtAuthority, 2, SECURITY_BUILTIN_DOMAIN_RID, DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0, &adminGroupSid)) {
        if (CheckTokenMembership(NULL, adminGroupSid, &isAdmin)) {
            FreeSid(adminGroupSid);
        }
    }
    return isAdmin == TRUE;
}


// Check if Roblox is running
bool IsRobloxRunning() {
    HANDLE hProcessSnap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);

    if (hProcessSnap == INVALID_HANDLE_VALUE) {
        return false;
    }

    PROCESSENTRY32 pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32);

    bool found = false;
    if (Process32First(hProcessSnap, &pe32)) {
        do {
            std::wstring exeFile(pe32.szExeFile);
            if (exeFile == L"RobloxPlayerBeta.exe" || exeFile == L"RobloxStudio.exe") {
                found = true;
                break;
            }
        } while (Process32Next(hProcessSnap, &pe32));
    }

    CloseHandle(hProcessSnap);
    return found;
}

// Delete Roblox's temp files
bool DeleteRobloxTempFiles() {
    TCHAR tempPath[MAX_PATH];
    if (SHGetFolderPath(NULL, CSIDL_LOCAL_APPDATA, NULL, 0, tempPath) != S_OK) {
        return false;
    }

    std::wstring robloxPath = std::wstring(tempPath) + L"\\Roblox";
    BOOL result = RemoveDirectory(robloxPath.c_str());

    if (result == 0) {
        DWORD error = GetLastError();
        if (error == ERROR_FILE_NOT_FOUND) {
            return true; // Considered success
        }
        return false; // Error
    }

    return true; // Deleted successfully
}

// Generate a random MAC address
std::string GenerateRandomMacAddress() {
    std::ostringstream macAddress;
    macAddress << std::hex << std::uppercase << std::setw(2) << std::setfill('0');
    for (int i = 0; i < 6; ++i) {
        if (i != 0) macAddress << ":";
        macAddress << (rand() % 256);
    }
    return macAddress.str();
}

// Enable or disable network connection
void EnableLocalAreaConnection(const std::string& adapterName, bool enable) {
    std::string control = enable ? "enable" : "disable";
    std::string command = "netsh interface set interface \"" + adapterName + "\" " + control;

    system(command.c_str());
}

// Spoof the MAC address
bool SpoofMAC() {
    HKEY hKey;
    LONG result;
    bool err = false;

    result = RegOpenKeyEx(HKEY_LOCAL_MACHINE, L"SYSTEM\\CurrentControlSet\\Control\\Class\\{4d36e972-e325-11ce-bfc1-08002be10318}", 0, KEY_ALL_ACCESS, &hKey);
    if (result == ERROR_SUCCESS) {
        TCHAR subKeyName[256];
        DWORD subKeyNameSize;
        FILETIME lastWriteTime;

        for (DWORD i = 0; RegEnumKeyEx(hKey, i, subKeyName, &subKeyNameSize, NULL, NULL, NULL, &lastWriteTime) == ERROR_SUCCESS; i++) {
            // Initialize subKeyNameSize for each iteration
            subKeyNameSize = sizeof(subKeyName) / sizeof(TCHAR) - 1;

            if (wcscmp(subKeyName, L"Properties") != 0) {
                HKEY hSubKey;
                result = RegOpenKeyEx(hKey, subKeyName, 0, KEY_ALL_ACCESS, &hSubKey);
                if (result == ERROR_SUCCESS) {
                    BYTE busType[256];
                    DWORD busTypeSize = sizeof(busType);
                    result = RegQueryValueEx(hSubKey, L"BusType", NULL, NULL, busType, &busTypeSize);
                    if (result == ERROR_SUCCESS) {
                        std::string newMacAddress = GenerateRandomMacAddress();
                        DWORD dataSize = static_cast<DWORD>(newMacAddress.length() + 1);
                        RegSetValueEx(hSubKey, L"NetworkAddress", 0, REG_SZ, reinterpret_cast<const BYTE*>(newMacAddress.c_str()), dataSize);

                        // Get the adapter name from the registry
                        TCHAR adapterName[256];
                        DWORD adapterNameSize = sizeof(adapterName);
                        result = RegQueryValueEx(hSubKey, L"NetConnectionId", NULL, NULL, reinterpret_cast<BYTE*>(adapterName), &adapterNameSize);
                        if (result == ERROR_SUCCESS) {
                            EnableLocalAreaConnection(std::string(adapterName, adapterName + adapterNameSize / sizeof(TCHAR)), true);
                        }
                    }
                    RegCloseKey(hSubKey);
                }
                else {
                    PrintMessage("ERROR", "Failed to open network adapter registry key.", FOREGROUND_RED | FOREGROUND_INTENSITY);
                    err = true;
                }
            }
        }
        RegCloseKey(hKey);
    }
    else {
        PrintMessage("ERROR", "Failed to open registry key for network adapters.", FOREGROUND_RED | FOREGROUND_INTENSITY);
        err = true;
    }

    return err;
}

int main() {
    SetConsoleTitle(TEXT("Roblox Spoofer"));

    if (!IsRunningAsAdmin()) {
        PrintMessage("ERROR", "This application requires administrative privileges. Please run as administrator.", FOREGROUND_RED | FOREGROUND_INTENSITY);
        std::cout << "Press any key to exit..." << std::endl;
        std::cin.get();
        return 1; // Exit with an error code
    }
    // Check if Roblox is running
    if (IsRobloxRunning()) {
        PrintMessage("ERROR", "Roblox is currently running. Please close Roblox to use the spoofer.", FOREGROUND_RED | FOREGROUND_INTENSITY);
        std::cout << "Press any key to exit..." << std::endl;
        std::cin.get();
        return 1; // Exit with an error code
    }

    PrintMessage("INFO", "Roblox Spoofer v1.0", FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE | FOREGROUND_INTENSITY);
    std::cout << "-------------------" << std::endl;

    // MAC Address Spoofing
    PrintMessage("INFO", "Spoofing MAC address...", FOREGROUND_BLUE | FOREGROUND_INTENSITY);
    if (SpoofMAC()) {
        PrintMessage("ERROR", "Failed to spoof MAC address.", FOREGROUND_RED | FOREGROUND_INTENSITY);
    }
    else {
        PrintMessage("INFO", "MAC address spoofed successfully.", FOREGROUND_GREEN | FOREGROUND_INTENSITY);
    }

    // Clear Roblox's Temp Files
    PrintMessage("INFO", "Clearing Roblox temp files...", FOREGROUND_BLUE | FOREGROUND_INTENSITY);
    if (DeleteRobloxTempFiles()) {
        PrintMessage("INFO", "Roblox temp files cleared successfully.", FOREGROUND_GREEN | FOREGROUND_INTENSITY);
    }
    else {
        PrintMessage("ERROR", "Failed to clear Roblox temp files or Roblox temp directory does not exist.", FOREGROUND_RED | FOREGROUND_INTENSITY);
    }

    PrintMessage("INFO", "Operation completed.", FOREGROUND_GREEN | FOREGROUND_INTENSITY);

    std::cout << "Press any key to exit..." << std::endl;
    std::cin.get();
    return 0;
}
