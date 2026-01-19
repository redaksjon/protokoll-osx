import Foundation

/// Registry of known Protokoll tools
public struct ToolRegistry {
    
    // MARK: - Known Tools
    
    public static let contextStatus = "protokoll_context_status"
    public static let listTranscripts = "protokoll_list_transcripts"
    public static let readTranscript = "protokoll_read_transcript"
    public static let listProjects = "protokoll_list_projects"
    public static let listPeople = "protokoll_list_people"
    public static let listTerms = "protokoll_list_terms"
    public static let processAudio = "protokoll_process_audio"
    public static let addProject = "protokoll_add_project"
    public static let addPerson = "protokoll_add_person"
    public static let addTerm = "protokoll_add_term"
    public static let editTranscript = "protokoll_edit_transcript"
    public static let combineTranscripts = "protokoll_combine_transcripts"
    public static let provideFeedback = "protokoll_provide_feedback"
    
    // MARK: - Tool Descriptions
    
    public static func description(for tool: String) -> String? {
        switch tool {
        case contextStatus:
            return "Get the status of the Protokoll context system"
        case listTranscripts:
            return "List transcripts in a directory (prefer resource protokoll://transcripts instead)"
        case readTranscript:
            return "Read a transcript file (prefer resource protokoll://transcript/{path} instead)"
        case listProjects:
            return "List all projects"
        case listPeople:
            return "List all people"
        case listTerms:
            return "List all terms"
        case processAudio:
            return "Process an audio file"
        case addProject:
            return "Add a new project"
        case addPerson:
            return "Add a new person"
        case addTerm:
            return "Add a new term"
        case editTranscript:
            return "Edit a transcript"
        case combineTranscripts:
            return "Combine multiple transcripts"
        case provideFeedback:
            return "Provide feedback to correct a transcript"
        default:
            return nil
        }
    }
}
