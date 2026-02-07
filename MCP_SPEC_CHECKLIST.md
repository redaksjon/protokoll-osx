# MCP implementation checklist

**Before implementing or changing MCP transport or protocol code**, verify against the [official MCP specification](https://modelcontextprotocol.io/specification/2024-11-05/basic/transports) and this checklist. Do not rely on a high-level description only—check the spec for required headers, session handling, and event formats.

## HTTP/SSE transport

When implementing or modifying the SSE transport (e.g. `SSETransport.swift`):

- [ ] **Session ID**  
  Clients **must** send the session ID when posting to the message endpoint, either as a query parameter or in the **`mcp-session-id`** header. The session ID is provided by the server when establishing the SSE connection (e.g. in the `endpoint` event data or in the endpoint URL).  
  → Parse and store session ID from the endpoint event (JSON `sessionId`/`session_id`/`mcp-session-id` or from the endpoint URL query). Send it on every POST via the `mcp-session-id` header (and/or use the full endpoint URL if it already includes the session).

- [ ] **Endpoint event**  
  The server sends an **`endpoint`** event containing the URI for the client to use for sending messages. The event data may be a plain URI string or JSON (e.g. `{"url": "...", "sessionId": "..."}`).  
  → Support both plain URI and JSON; resolve relative URIs against the SSE base URL.

- [ ] **Message events**  
  Server messages are sent as SSE **`message`** events, with the message content encoded as JSON in the event data.  
  → Parse `event: message` and treat `data:` as the JSON-RPC message body.

- [ ] **GET for SSE, POST for client messages**  
  Client opens the SSE stream with GET; all client messages must be sent as HTTP POST to the endpoint URI provided in the `endpoint` event.  
  → Use GET for the initial connection; use the received endpoint URL (and session ID) for all POSTs.

- [ ] **Accept / Content-Type**  
  Client should send appropriate headers (e.g. `Accept: text/event-stream` for GET; `Content-Type: application/json` for POST).  
  → Set headers on both GET and POST requests.

## stdio transport

When implementing or modifying the stdio transport:

- [ ] Messages are **newline-delimited** and must not contain embedded newlines.
- [ ] Only valid MCP (JSON-RPC) messages on stdin/stdout; stderr may be used for logging.

## General

- [ ] **Lifecycle**  
  Follow the MCP lifecycle (initialize handshake, optional initialized notification, etc.) as in the spec.
- [ ] **JSON-RPC 2.0**  
  All messages conform to JSON-RPC 2.0 (id, method, params / result / error).

## References

- [MCP Transports (2024-11-05)](https://modelcontextprotocol.io/specification/2024-11-05/basic/transports)
- [MCP Messages](https://modelcontextprotocol.io/specification/2024-11-05/basic/messages)
- [MCP Lifecycle](https://modelcontextprotocol.io/specification/2024-11-05/basic/lifecycle)
