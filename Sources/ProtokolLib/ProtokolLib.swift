// ProtokolLib - Core MCP client library for Protokoll
//
// This library contains the MCP (Model Context Protocol) client implementation
// including transport, types, and client logic.

import Foundation

// Re-export all public types
@_exported import struct Foundation.Data
@_exported import struct Foundation.URL

// Version information
public struct ProtokolLibInfo {
    public static let version = "1.0.0"
    public static let name = "ProtokolLib"
}
