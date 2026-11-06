import Darwin
import Foundation
import os
import SwiftTerm

public final class ShellSession: LocalProcessDelegate {
    public struct Configuration: Equatable, Sendable {
        public var shell: String
        public var arguments: [String]
        public var loginName: String?
        public var directory: URL
        public var environment: [String: String]

        public init(shell: String, arguments: [String] = [], loginName: String? = nil, directory: URL, environment: [String: String]) {
            self.shell = shell
            self.arguments = arguments
            self.loginName = loginName
            self.directory = directory
            self.environment = environment
        }

        public static func login(in directory: URL, environment: [String: String] = ProcessInfo.processInfo.environment) -> Configuration {
            let requested = environment["SHELL"] ?? ""
            let shell = !requested.isEmpty && FileManager.default.isExecutableFile(atPath: requested) ? requested : "/bin/zsh"
            var variables = environment
            variables["TERM"] = "xterm-256color"
            variables["COLORTERM"] = "truecolor"
            variables["TERM_PROGRAM"] = "Mork"
            if variables["LANG"]?.isEmpty ?? true { variables["LANG"] = "en_US.UTF-8" }
            return Configuration(shell: shell, loginName: "-" + URL(fileURLWithPath: shell).lastPathComponent, directory: directory, environment: variables)
        }
    }

    private static let registry = OSAllocatedUnfairLock<Set<pid_t>>(initialState: [])

    public static var livePIDs: Set<pid_t> { registry.withLock { $0 } }

    public static func terminateAll() {
        let pids = Array(registry.withLock { pids in
            defer { pids.removeAll() }
            return pids
        })
        DispatchQueue.concurrentPerform(iterations: pids.count) { ShellReaper.stop(pids[$0]) }
    }

    public var onOutput: ((ArraySlice<UInt8>) -> Void)?
    public var onExit: ((Int32?) -> Void)?
    public var windowSize: (() -> winsize)?
    public private(set) var processID: pid_t?
    public private(set) var isRunning = false

    private let queue: DispatchQueue
    private lazy var process = LocalProcess(delegate: self, dispatchQueue: queue)

    public init(queue: DispatchQueue = .main) {
        self.queue = queue
    }

    deinit {
        terminate()
    }

    public func start(_ configuration: Configuration) {
        guard !isRunning else { return }
        process.startProcess(
            executable: configuration.shell,
            args: configuration.arguments,
            environment: configuration.environment.map { "\($0.key)=\($0.value)" },
            execName: configuration.loginName,
            currentDirectory: configuration.directory.path
        )
        guard process.running else { return }
        let pid = process.shellPid
        processID = pid
        isRunning = true
        Self.registry.withLock { _ = $0.insert(pid) }
    }

    public func send(_ text: String) {
        send(ArraySlice(Array(text.utf8)))
    }

    public func send(_ bytes: ArraySlice<UInt8>) {
        guard isRunning else { return }
        process.send(data: bytes)
    }

    public func resize(columns: Int, rows: Int) {
        guard isRunning, process.childfd >= 0 else { return }
        var size = winsize(ws_row: UInt16(clamping: rows), ws_col: UInt16(clamping: columns), ws_xpixel: 0, ws_ypixel: 0)
        _ = PseudoTerminalHelpers.setWinSize(masterPtyDescriptor: process.childfd, windowSize: &size)
    }

    public func terminate() {
        guard isRunning, let pid = processID else { return }
        isRunning = false
        Self.registry.withLock { _ = $0.remove(pid) }
        let members = ShellReaper.sessionMembers(of: pid)
        process.terminate()
        DispatchQueue.global(qos: .utility).async {
            ShellReaper.stop(pid, members: members)
        }
    }

    public func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        if let pid = processID {
            Self.registry.withLock { _ = $0.remove(pid) }
        }
        isRunning = false
        onExit?(exitCode.map { ($0 >> 8) & 0xff })
    }

    public func dataReceived(slice: ArraySlice<UInt8>) {
        onOutput?(slice)
    }

    public func getWindowSize() -> winsize {
        windowSize?() ?? winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0)
    }
}

enum ShellReaper {
    static let gracePeriod: TimeInterval = 1

    static func stop(_ pid: pid_t) {
        stop(pid, members: sessionMembers(of: pid))
    }

    static func stop(_ pid: pid_t, members: [pid_t]) {
        let everyone = Set(members + [pid])
        everyone.forEach { kill($0, SIGHUP) }
        kill(pid, SIGCONT)
        var reaped = false
        let deadline = Date().addingTimeInterval(gracePeriod)
        while Date() < deadline {
            reaped = reaped || waitpid(pid, nil, WNOHANG) != 0
            if reaped && everyone.allSatisfy({ !isRunning($0, session: pid) }) { return }
            usleep(20_000)
        }
        everyone.filter { isRunning($0, session: pid) }.forEach { kill($0, SIGKILL) }
        if !reaped { waitpid(pid, nil, 0) }
    }

    static func sessionMembers(of session: pid_t) -> [pid_t] {
        let capacity = Int(proc_listallpids(nil, 0)) + 64
        var pids = [pid_t](repeating: 0, count: capacity)
        let count = pids.withUnsafeMutableBytes { buffer in
            Int(proc_listallpids(buffer.baseAddress, Int32(buffer.count)))
        }
        return pids.prefix(max(count, 0)).filter { $0 > 0 && getsid($0) == session }
    }

    private static func isRunning(_ pid: pid_t, session: pid_t) -> Bool {
        getsid(pid) == session && kill(pid, 0) == 0
    }
}
