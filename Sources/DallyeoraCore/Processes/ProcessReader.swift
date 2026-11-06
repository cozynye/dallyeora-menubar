import Darwin
import Foundation

/// libproc과 sysctl로 프로세스 목록을 읽는다. 사설 API는 쓰지 않는다.
/// 다른 사용자 소유 프로세스는 이름·경로·부모·uid만 읽히고 수치는 권한이 없어 0이다.
public enum ProcessReader {
    public static func snapshot() -> ProcessSnapshot {
        let me = getuid()
        let uptime = ProcessInfo.processInfo.systemUptime
        var count = proc_listallpids(nil, 0)
        guard count > 0 else { return ProcessSnapshot(uptime: uptime, samples: []) }
        var pids = [pid_t](repeating: 0, count: Int(count) + 64)
        count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))

        var samples: [ProcessSample] = []
        samples.reserveCapacity(Int(count))
        for pid in pids.prefix(Int(max(count, 0))) where pid > 0 {
            guard let info = kinfo(pid) else { continue } // 목록을 받은 뒤 끝난 프로세스
            let path = self.path(of: pid)
            let name = path.isEmpty ? info.comm : (path as NSString).lastPathComponent
            var footprint: UInt64 = 0
            var cpu: UInt64 = 0
            if info.uid == me, let usage = rusage(pid) {
                footprint = usage.ri_phys_footprint
                cpu = nanos(usage.ri_user_time + usage.ri_system_time)
            }
            samples.append(ProcessSample(pid: pid, ppid: info.ppid, uid: info.uid, name: name, path: path,
                                         footprintBytes: footprint, cpuTimeNanos: cpu))
        }
        return ProcessSnapshot(uptime: uptime, samples: samples)
    }

    private struct KInfo {
        var ppid: pid_t
        var uid: uid_t
        var comm: String
    }

    private static func kinfo(_ pid: pid_t) -> KInfo? {
        var kp = kinfo_proc()
        var len = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &kp, &len, nil, 0) == 0, len > 0 else { return nil }
        let comm = withUnsafePointer(to: &kp.kp_proc.p_comm) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) { String(cString: $0) }
        }
        return KInfo(ppid: kp.kp_eproc.e_ppid, uid: kp.kp_eproc.e_ucred.cr_uid, comm: comm)
    }

    private static func path(of pid: pid_t) -> String {
        var buffer = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count)) // 널을 뺀 길이
        return length > 0 ? String(decoding: buffer.prefix(Int(length)), as: UTF8.self) : ""
    }

    private static func rusage(_ pid: pid_t) -> rusage_info_v4? {
        var info = rusage_info_v4()
        // proc_pid_rusage는 rusage_info_t*(void**)를 받지만 실제로는 구조체 메모리 자체를 가리켜야 한다.
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return result == 0 ? info : nil
    }

    private static let timebase: (numer: UInt64, denom: UInt64) = {
        var info = mach_timebase_info()
        mach_timebase_info(&info)
        return (UInt64(info.numer), UInt64(info.denom))
    }()

    /// Mach 시간 단위를 나노초로.
    static func nanos(_ machTime: UInt64) -> UInt64 {
        machTime * timebase.numer / timebase.denom
    }
}
