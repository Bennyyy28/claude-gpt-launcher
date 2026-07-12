import Foundation

@main
enum ClaudeGPTMCPServer {
    static func main() {
        while let line = readLine() {
            guard let data = line.data(using: .utf8),
                  let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            if let response = handle(request),
               let encoded = try? JSONSerialization.data(withJSONObject: response),
               let output = String(data: encoded, encoding: .utf8) {
                print(output)
                fflush(stdout)
            }
        }
    }

    static func handle(_ request: [String: Any]) -> [String: Any]? {
        let method = request["method"] as? String ?? ""
        let id = request["id"]

        if method.hasPrefix("notifications/") { return nil }
        guard let id else { return nil }

        switch method {
        case "initialize":
            let params = request["params"] as? [String: Any]
            let protocolVersion = params?["protocolVersion"] as? String ?? "2025-06-18"
            return success(id: id, result: [
                "protocolVersion": protocolVersion,
                "capabilities": ["tools": ["listChanged": false]],
                "serverInfo": ["name": "claude-gpt-harness", "version": "1.0.0"],
            ])
        case "ping":
            return success(id: id, result: [:])
        case "tools/list":
            return success(id: id, result: ["tools": tools])
        case "tools/call":
            return success(id: id, result: callTool(request["params"] as? [String: Any]))
        default:
            return failure(id: id, code: -32601, message: "Method not found: \(method)")
        }
    }

    private static var tools: [[String: Any]] {
        [toolDefinition(name: "claude_code_plan", edits: false),
         toolDefinition(name: "claude_code_edit", edits: true)]
    }

    private static func toolDefinition(name: String, edits: Bool) -> [String: Any] {
        var properties: [String: Any] = [
            "projectPath": ["type": "string", "description": "Absolute path to a Git working tree inside the user's home directory."],
            "prompt": ["type": "string", "description": "The bounded task for the Claude Code harness."],
            "model": [
                "type": "string",
                "enum": ClaudeHarnessRunner.allowedModels,
                "default": "gpt-5.6-sol",
            ],
            "allowProtectedRepository": [
                "type": "boolean",
                "default": false,
                "description": "Leave false unless the user explicitly authorized a repository matching CLAUDE_GPT_PROTECTED_REMOTES.",
            ],
        ]
        var required = ["projectPath", "prompt"]
        if edits {
            properties["confirmEdits"] = [
                "type": "boolean",
                "description": "Must be true. Confirms the caller intends Claude Code to edit files without shell execution.",
            ]
            required.append("confirmEdits")
        }

        return [
            "name": name,
            "description": edits
                ? "Run Claude Code's harness to edit files in a validated Git repository when the MCP registration explicitly enables edits. Shell and network tools are unavailable. Configured protected repositories require explicit opt-in."
                : "Ask Claude Code's harness for a read-only repository plan or review. No edits, shell, or network tools are available. Configured protected repositories require explicit opt-in.",
            "inputSchema": [
                "type": "object",
                "properties": properties,
                "required": required,
                "additionalProperties": false,
            ],
            "outputSchema": [
                "type": "object",
                "properties": [
                    "status": ["type": "string"],
                    "mode": ["type": "string"],
                    "model": ["type": "string"],
                    "projectPath": ["type": "string"],
                    "output": ["type": "string"],
                ],
                "required": ["status", "mode", "model", "projectPath", "output"],
                "additionalProperties": false,
            ],
        ]
    }

    private static func callTool(_ params: [String: Any]?) -> [String: Any] {
        let name = params?["name"] as? String ?? ""
        let arguments = params?["arguments"] as? [String: Any] ?? [:]
        let mode: ClaudeHarnessMode
        switch name {
        case "claude_code_plan": mode = .plan
        case "claude_code_edit": mode = .edit
        default: return toolError("Unknown tool: \(name)")
        }

        do {
            let result = try ClaudeHarnessRunner.run(
                projectPath: arguments["projectPath"] as? String ?? "",
                prompt: arguments["prompt"] as? String ?? "",
                model: arguments["model"] as? String ?? "gpt-5.6-sol",
                mode: mode,
                confirmEdits: arguments["confirmEdits"] as? Bool ?? false,
                allowProtectedRepository: arguments["allowProtectedRepository"] as? Bool ?? false
            )
            let structured: [String: Any] = [
                "status": "completed",
                "mode": result.mode.rawValue,
                "model": result.model,
                "projectPath": result.projectPath,
                "output": result.output,
            ]
            return [
                "content": [["type": "text", "text": result.output]],
                "structuredContent": structured,
                "isError": false,
            ]
        } catch {
            return toolError(error.localizedDescription)
        }
    }

    private static func toolError(_ message: String) -> [String: Any] {
        ["content": [["type": "text", "text": message]], "isError": true]
    }

    private static func success(id: Any, result: [String: Any]) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "result": result]
    }

    private static func failure(id: Any, code: Int, message: String) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]]
    }
}
