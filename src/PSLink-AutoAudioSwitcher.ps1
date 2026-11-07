# PSLink AutoAudioSwitcher - monitor (Windows PowerShell 5.1, x64)
# Supports the empirically tested Sony PS Link USB adapter VID_054C / PID_0ECC.
# Default mode is read-only; -Apply changes the current user's default playback endpoint.
# No driver installation, USB writes, downloads, or administrative privileges.
param(
    [switch]$Apply,
    [ValidateRange(500,60000)][int]$IntervalMs = 900,
    [ValidateNotNullOrEmpty()][string]$HeadsetNameContains = 'PlayStation Link Adapter',
    [ValidateNotNullOrEmpty()][string]$SpeakerNameContains = 'Realtek'
)
$ErrorActionPreference = 'Stop'

$source = @'
using System;
using System.Runtime.InteropServices;

public static class PSLinkHidProbe {
    [StructLayout(LayoutKind.Sequential)]
    private struct SP_DEVICE_INTERFACE_DATA {
        public int cbSize;
        public Guid InterfaceClassGuid;
        public int Flags;
        public IntPtr Reserved;
    }

    [DllImport("hid.dll")]
    private static extern void HidD_GetHidGuid(out Guid guid);

    [DllImport("hid.dll", SetLastError = true)]
    private static extern bool HidD_GetFeature(IntPtr device, [In, Out] byte[] data, int dataLength);

    [DllImport("setupapi.dll", EntryPoint = "SetupDiGetClassDevsW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr SetupDiGetClassDevs(ref Guid classGuid, string enumerator, IntPtr parent, uint flags);

    [DllImport("setupapi.dll", SetLastError = true)]
    private static extern bool SetupDiEnumDeviceInterfaces(IntPtr set, IntPtr deviceInfo, ref Guid classGuid, uint index, ref SP_DEVICE_INTERFACE_DATA data);

    [DllImport("setupapi.dll", EntryPoint = "SetupDiGetDeviceInterfaceDetailW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr set, ref SP_DEVICE_INTERFACE_DATA data, IntPtr detail, uint length, out uint required, IntPtr deviceInfo);

    [DllImport("setupapi.dll", SetLastError = true)]
    private static extern bool SetupDiDestroyDeviceInfoList(IntPtr set);

    [DllImport("kernel32.dll", EntryPoint = "CreateFileW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateFile(string path, uint access, uint share, IntPtr security, uint disposition, uint flags, IntPtr template);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    public static string FindCol04() {
        Guid guid;
        HidD_GetHidGuid(out guid);
        IntPtr devices = SetupDiGetClassDevs(ref guid, null, IntPtr.Zero, 0x12);
        if (devices == new IntPtr(-1)) return null;
        try {
            for (uint i = 0; ; i++) {
                SP_DEVICE_INTERFACE_DATA data = new SP_DEVICE_INTERFACE_DATA();
                data.cbSize = Marshal.SizeOf(typeof(SP_DEVICE_INTERFACE_DATA));
                if (!SetupDiEnumDeviceInterfaces(devices, IntPtr.Zero, ref guid, i, ref data)) break;
                uint required;
                SetupDiGetDeviceInterfaceDetail(devices, ref data, IntPtr.Zero, 0, out required, IntPtr.Zero);
                if (required < 8) continue;
                IntPtr detail = Marshal.AllocHGlobal((int)required);
                try {
                    Marshal.WriteInt32(detail, IntPtr.Size == 8 ? 8 : 6);
                    if (!SetupDiGetDeviceInterfaceDetail(devices, ref data, detail, required, out required, IntPtr.Zero)) continue;
                    string path = Marshal.PtrToStringUni(IntPtr.Add(detail, 4));
                    if (path != null &&
                        path.IndexOf("vid_054c&pid_0ecc", StringComparison.OrdinalIgnoreCase) >= 0 &&
                        path.IndexOf("col04", StringComparison.OrdinalIgnoreCase) >= 0)
                        return path;
                } finally {
                    Marshal.FreeHGlobal(detail);
                }
            }
            return null;
        } finally {
            SetupDiDestroyDeviceInfoList(devices);
        }
    }

    public static byte[] ReadFeature(string path, byte reportId) {
        IntPtr h = CreateFile(path, 0x80000000u, 3u, IntPtr.Zero, 3u, 0u, IntPtr.Zero);
        if (h == new IntPtr(-1) || h == IntPtr.Zero) return null;
        try {
            byte[] bytes = new byte[64];
            bytes[0] = reportId;
            return HidD_GetFeature(h, bytes, bytes.Length) ? bytes : null;
        } finally {
            CloseHandle(h);
        }
    }
}

[ComImport, Guid("870AF99C-171D-4F9E-AF0D-E63DF40C2BC9")]
internal class PSLinkPolicyConfigClient { }

[ComImport, Guid("F8679F50-850A-41CF-9C72-430F290290C8"),
 InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IPSLinkPolicyConfig {
    [PreserveSig] int GetMixFormat();
    [PreserveSig] int GetDeviceFormat();
    [PreserveSig] int ResetDeviceFormat();
    [PreserveSig] int SetDeviceFormat();
    [PreserveSig] int GetProcessingPeriod();
    [PreserveSig] int SetProcessingPeriod();
    [PreserveSig] int GetShareMode();
    [PreserveSig] int SetShareMode();
    [PreserveSig] int GetPropertyValue();
    [PreserveSig] int SetPropertyValue();
    [PreserveSig] int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string deviceId, int role);
    [PreserveSig] int SetEndpointVisibility();
}

public static class PSLinkAudioSwitcher {
    public static void SetDefaultOutput(string endpointId) {
        IPSLinkPolicyConfig config = (IPSLinkPolicyConfig)new PSLinkPolicyConfigClient();
        try {
            for (int role = 0; role < 3; role++) {
                int hr = config.SetDefaultEndpoint(endpointId, role);
                Marshal.ThrowExceptionForHR(hr);
            }
        } finally {
            if (config != null) Marshal.ReleaseComObject(config);
        }
    }
}

'@

if (-not ('PSLinkHidProbe' -as [type])) {
    Add-Type -TypeDefinition $source -ErrorAction Stop
}

function Get-PlaybackEndpoint {
    param([Parameter(Mandatory = $true)][string]$NameContains)
    # Match by Windows audio RENDER endpoint ID (0.0.0), not localized names.
    # NameContains is a literal substring, not a regular expression or command.
    $devices = @(Get-PnpDevice -Class AudioEndpoint -PresentOnly -ErrorAction Stop |
        Where-Object {
            $_.InstanceId -match '^SWD\\MMDEVAPI\\\{0\.0\.0\.00000000\}\.\{[A-Fa-f0-9-]+\}$' -and
            $_.FriendlyName.IndexOf($NameContains, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
        })
    if ($devices.Count -ne 1) {
        throw "Playback endpoint name must match exactly one device: '$NameContains' (found $($devices.Count)). Check Get-PnpDevice -Class AudioEndpoint."
    }
    return [pscustomobject]@{
        Name   = $devices[0].FriendlyName
        Id     = $devices[0].InstanceId.Substring('SWD\MMDEVAPI\'.Length)
        Status = $devices[0].Status
    }
}

function Get-HeadsetConnection {
    param([string]$Path)
    # Three-valued status: EIN / AUS / UNBEKANNT. Never infer OFF from failed read.
    $bytes = [PSLinkHidProbe]::ReadFeature($Path, [byte]0x82)
    if ($null -eq $bytes -or $bytes.Length -lt 4 -or $bytes[0] -ne 0x82) { return 'UNBEKANNT' }
    # Device-specific values verified during development:
    # ON  = 82-01-10-0F
    # OFF = 82-01-20-0F, or 82-00-00-00 in initial test.
    if ($bytes[1] -eq 0x01 -and $bytes[2] -eq 0x10 -and $bytes[3] -eq 0x0F) { return 'EIN' }
    if ($bytes[1] -eq 0x01 -and $bytes[2] -eq 0x20 -and $bytes[3] -eq 0x0F) { return 'AUS' }
    if ($bytes[1] -eq 0x00 -and $bytes[2] -eq 0x00 -and $bytes[3] -eq 0x00) { return 'AUS' }
    return 'UNBEKANNT'
}

try {
    $path = [PSLinkHidProbe]::FindCol04()
    if (-not $path) { throw 'PS Link HID COL04 not found. Is the supported dongle connected?' }

    $headset = Get-PlaybackEndpoint -NameContains $HeadsetNameContains
    $speakers = Get-PlaybackEndpoint -NameContains $SpeakerNameContains
    if ($headset.Id -eq $speakers.Id) { throw 'Headset and speakers resolved to the same endpoint. Refusing to switch.' }
    Write-Host "Found: $($headset.Name)" -ForegroundColor Cyan
    Write-Host "Found: $($speakers.Name)" -ForegroundColor Cyan

    if ($Apply) {
        Write-Host 'MODE: APPLY. Changes Windows default playback device on stable state transitions.' -ForegroundColor Yellow
    } else {
        Write-Host 'MODE: MONITOR ONLY. No audio settings will be changed.' -ForegroundColor Green
    }
    Write-Host 'Toggle headset power to test. Ctrl+C to stop.'

    $candidate = ''
    $stableCount = 0
    $lastStable = ''
    $lastWarn = [DateTime]::MinValue

    while ($true) {
        $state = Get-HeadsetConnection -Path $path
        if ($state -eq 'UNBEKANNT') {
            $candidate = ''
            $stableCount = 0
            if (((Get-Date) - $lastWarn).TotalSeconds -ge 20) {
                Write-Host 'Unknown HID report or read failure; leaving audio unchanged.' -ForegroundColor DarkYellow
                $lastWarn = Get-Date
            }
        } else {
            if ($state -eq $candidate) { $stableCount++ }
            else { $candidate = $state; $stableCount = 1 }
            if ($stableCount -ge 3 -and $state -ne $lastStable) {
                $lastStable = $state
                $target = if ($state -eq 'EIN') { $headset } else { $speakers }
                $clock = Get-Date -Format 'HH:mm:ss'
                Write-Host "[$clock] Headset $state -> $($target.Name)" -ForegroundColor Cyan
                if ($Apply) {
                    try {
                        $currentTarget = Get-PlaybackEndpoint -NameContains $(if ($state -eq 'EIN') { $HeadsetNameContains } else { $SpeakerNameContains })
                        if ($currentTarget.Status -ne 'OK') { throw "Target audio endpoint is not ready ($($currentTarget.Status))." }
                        [PSLinkAudioSwitcher]::SetDefaultOutput($currentTarget.Id)
                        Write-Host '  Default playback device set.' -ForegroundColor Green
                    } catch {
                        Write-Host "  AUDIO SWITCH FAILED: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
        }
        Start-Sleep -Milliseconds $IntervalMs
    }
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
