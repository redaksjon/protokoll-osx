import Foundation
import OSLog

/// Stdio transport for local MCP server
@available(macOS 14.0, *)
public actor StdioTransport: MCPTransport {
    
    // MARK: - Properties
    
    private let serverPath: String
    private let logger: Logger
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var messageQueue: [Data] = []
    private var receiveWaiters: [CheckedContinuation<Data, Error>] = []
    private var stdoutReadTask: Task<Void, Never>?
    private var stderrReadTask: Task<Void, Never>?
    private var readCancelled: UnsafeMutablePointer<Bool>?
    
    public var isConnected: Bool {
        process?.isRunning ?? false
    }
    
    // MARK: - Initialization
    
    public init(
        serverPath: String = NSHomeDirectory() + "/.nvm/versions/node/v24.8.0/bin/protokoll-mcp",
        logger: Logger = Logger(subsystem: "com.protokoll.mcp", category: "transport")
    ) {
        self.serverPath = serverPath
        self.logger = logger
    }
    
    // MARK: - Lifecycle
    
    public func start() async throws {
        logger.info("Starting stdio transport with server: \(self.serverPath)")
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: serverPath) else {
            logger.error("Server not found at: \(self.serverPath)")
            throw StdioTransportError.serverNotFound(path: serverPath)
        }
        
        // Check if it's a directory (can't execute a directory)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: serverPath, isDirectory: &isDirectory), isDirectory.boolValue {
            logger.error("Server path is a directory: \(self.serverPath)")
            throw StdioTransportError.serverNotFound(path: serverPath)
        }
        
        // Check if file is executable
        guard FileManager.default.isExecutableFile(atPath: serverPath) else {
            logger.error("Server file is not executable: \(self.serverPath)")
            throw StdioTransportError.failedToStart(error: NSError(
                domain: "StdioTransport",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "File is not executable: \(serverPath)"]
            ))
        }
        
        // Create pipes
        stdinPipe = Pipe()
        stdoutPipe = Pipe()
        stderrPipe = Pipe()
        
        // Create process
        process = Process()
        
        // IMPORTANT: Run the ACTUAL server.js file, not the symlink
        // The symlink causes import.meta.url check to fail
        let actualServerPath = NSHomeDirectory() + "/.nvm/versions/node/v24.8.0/lib/node_modules/@redaksjon/protokoll/dist/mcp/server.js"
        
        process?.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process?.arguments = ["node", actualServerPath]
        process?.standardInput = stdinPipe
        process?.standardOutput = stdoutPipe
        process?.standardError = stderrPipe
        
        // Set environment to inherit PATH and other vars
        process?.environment = ProcessInfo.processInfo.environment
        
        // Set up termination handler
        process?.terminationHandler = { [weak self] process in
            Task {
                guard let self = self else { return }
                await self.handleTermination(exitCode: process.terminationStatus)
            }
        }
        
        // Launch process
        do {
            try process?.run()
            logger.info("Server process started (PID: \(self.process?.processIdentifier ?? -1))")
            
            // Give server more time to fully initialize
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            
            // Check if it's still running
            if !(process?.isRunning ?? false) {
                logger.error("Server process died immediately after launch")
                
                // Clean up pipes immediately to prevent blocking reads
                stdinPipe = nil
                stdoutPipe = nil
                stderrPipe = nil
                process = nil
                
                // Try to read any error output (non-blocking)
                if let stderrPipe = stderrPipe {
                    let errorData = try? stderrPipe.fileHandleForReading.readToEnd()
                    if let errorData = errorData, let errorMsg = String(data: errorData, encoding: .utf8) {
                        logger.error("Server startup error: \(errorMsg)")
                    }
                }
                
                throw StdioTransportError.failedToStart(error: NSError(domain: "StdioTransport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server died immediately"]))
            }
            
            logger.info("Server is running and ready")
        } catch {
            logger.error("Failed to start server: \(error.localizedDescription)")
            // CRITICAL: Close file handles on error to prevent any blocking reads
            stdinPipe?.fileHandleForWriting.closeFile()
            stdoutPipe?.fileHandleForReading.closeFile()
            stderrPipe?.fileHandleForReading.closeFile()
            stdinPipe = nil
            stdoutPipe = nil
            stderrPipe = nil
            process = nil
            throw StdioTransportError.failedToStart(error: error)
        }
        
        // CRITICAL: Do ALL I/O off the actor to avoid blocking
        // Only hop to actor to deliver messages
        
        // Capture what we need for the detached tasks
        let stdoutHandle = stdoutPipe!.fileHandleForReading
        let stderrHandle = stderrPipe!.fileHandleForReading
        
        logger.info("Creating read tasks...")
        
        // Start stdout reading - this is where we get responses
        // Use a simple flag for cancellation instead of actor hop
        let cancelledPtr = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        cancelledPtr.pointee = false
        readCancelled = cancelledPtr
        
        stdoutReadTask = Task.detached { [weak self, cancelledPtr] in
            defer { cancelledPtr.deallocate() }
            
            fputs("=== STDOUT READ LOOP STARTED ===\n", stderr)
            var buffer = Data()
            var loopCount = 0
            
            while !Task.isCancelled && !cancelledPtr.pointee {
                loopCount += 1
                
                // Check cancellation frequently
                if Task.isCancelled || cancelledPtr.pointee {
                    break
                }
                
                // Check if self/process is still valid
                guard let strongSelf = self else {
                    break
                }
                
                // Check if process is still running (non-blocking check)
                let isRunning = await strongSelf.process?.isRunning ?? false
                if !isRunning {
                    break
                }
                
                // Read data - availableData can block, but closing the handle in stop() will unblock it
                let data = stdoutHandle.availableData
                
                if data.isEmpty {
                    // No data available, sleep briefly
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                    continue
                }
                
                buffer.append(data)
                
                // Process complete messages (newline-delimited)
                while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                    let messageData = Data(buffer[..<newlineIndex])
                    buffer.removeSubrange(...newlineIndex)
                    
                    if !messageData.isEmpty {
                        // Deliver to actor
                        if let strongSelf = self {
                            await strongSelf.deliverMessage(messageData)
                        }
                    }
                }
            }
            fputs("=== STDOUT READ LOOP ENDED ===\n", stderr)
        }
        
        // Start stderr reading for error capture  
        stderrReadTask = Task.detached { [weak self, cancelledPtr] in
            fputs("=== STDERR READ LOOP STARTED ===\n", stderr)
            
            while !Task.isCancelled && !cancelledPtr.pointee {
                if self == nil { break }
                
                // Read stderr - if handle is closed, this returns empty immediately
                let data = stderrHandle.availableData
                if !data.isEmpty {
                    if let msg = String(data: data, encoding: .utf8) {
                        fputs("┌─ SERVER LOG ─────────────────────────────────────────┐\n", stderr)
                        fputs("\(msg)", stderr)
                        if !msg.hasSuffix("\n") { fputs("\n", stderr) }
                        fputs("└──────────────────────────────────────────────────────┘\n", stderr)
                    }
                }
                
                // Sleep before next check
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
            fputs("=== STDERR READ LOOP ENDED ===\n", stderr)
        }
        
        logger.info("Read tasks started")
    }
    
    public func stop() async throws {
        logger.info("Stopping stdio transport")
        
        // CRITICAL: Set cancellation flag FIRST
        if let readCancelled = readCancelled {
            readCancelled.pointee = true
        }
        
        // CRITICAL: Close file handles IMMEDIATELY to unblock any pending availableData calls
        // This MUST happen before cancelling tasks, otherwise availableData blocks forever
        stdoutPipe?.fileHandleForReading.closeFile()
        stderrPipe?.fileHandleForReading.closeFile()
        stdinPipe?.fileHandleForWriting.closeFile()
        
        // Cancel read tasks (they should exit immediately now that handles are closed)
        stdoutReadTask?.cancel()
        stderrReadTask?.cancel()
        
        // Give tasks a brief moment to exit
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
        
        // Clean up
        stdoutReadTask = nil
        stderrReadTask = nil
        readCancelled = nil
        
        if let process = process, process.isRunning {
            process.terminate()
            
            // Wait for termination with timeout
            let deadline = Date().addingTimeInterval(5.0)
            while process.isRunning && Date() < deadline {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
            
            if process.isRunning {
                logger.warning("Process did not terminate, forcing kill")
                process.interrupt()
            }
        }
        
        // Clear pipe references
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        process = nil
        
        // Cancel any pending receives
        for waiter in receiveWaiters {
            waiter.resume(throwing: StdioTransportError.connectionClosed)
        }
        receiveWaiters.removeAll()
        
        logger.info("Stdio transport stopped")
    }
    
    // MARK: - Communication
    
    public func send(_ message: Data) async throws {
        guard let stdinPipe = stdinPipe else {
            throw StdioTransportError.notConnected
        }
        
        // Add newline delimiter
        var messageWithNewline = message
        messageWithNewline.append(0x0A) // \n
        
        do {
            let handle = stdinPipe.fileHandleForWriting
            try handle.write(contentsOf: messageWithNewline)
            
            // Flush to ensure data is sent immediately
            if #available(macOS 10.15, *) {
                try? handle.synchronize()
            }
            
            if let messageStr = String(data: message, encoding: .utf8) {
                logger.debug("Sent: \(messageStr)")
            }
        } catch {
            logger.error("Failed to write to stdin: \(error.localizedDescription)")
            throw StdioTransportError.writeFailed(error: error)
        }
    }
    
    public func receive() async throws -> Data {
        // If we have queued messages, return the first one
        if !messageQueue.isEmpty {
            let queueSize = messageQueue.count
            logger.debug("Returning queued message (\(queueSize) in queue)")
            return messageQueue.removeFirst()
        }
        
        // Otherwise, wait for a message
        let waiterCount = receiveWaiters.count
        logger.debug("Waiting for message from server (waiters: \(waiterCount))...")
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            self.receiveWaiters.append(continuation)
        }
    }
    
    /// Called from detached task to deliver a message
    public func deliverMessage(_ data: Data) {
        logger.info("Delivering message (\(data.count) bytes)")
        
        // If someone is waiting, deliver directly
        if !receiveWaiters.isEmpty {
            let waiter = receiveWaiters.removeFirst()
            waiter.resume(returning: data)
            logger.debug("Delivered to waiting receiver")
        } else {
            // Queue for later
            messageQueue.append(data)
            logger.debug("Queued message (queue size: \(self.messageQueue.count))")
        }
    }
    
    // MARK: - Process Management
    
    private func handleTermination(exitCode: Int32) {
        logger.warning("Server process terminated with code: \(exitCode)")
        
        // Cancel any pending receives
        for waiter in receiveWaiters {
            waiter.resume(throwing: StdioTransportError.connectionClosed)
        }
        receiveWaiters.removeAll()
    }
}

// MARK: - Errors

public enum StdioTransportError: Error, LocalizedError {
    case serverNotFound(path: String)
    case failedToStart(error: Error)
    case notConnected
    case connectionClosed
    case writeFailed(error: Error)
    
    public var errorDescription: String? {
        switch self {
        case .serverNotFound(let path):
            return "Server not found at: \(path)"
        case .failedToStart(let error):
            return "Failed to start server: \(error.localizedDescription)"
        case .notConnected:
            return "Transport not connected"
        case .connectionClosed:
            return "Connection closed"
        case .writeFailed(let error):
            return "Write failed: \(error.localizedDescription)"
        }
    }
}
