import SwiftUI

struct ContextView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCategory: ContextCategory = .people
    
    enum ContextCategory: String, CaseIterable {
        case people = "People"
        case projects = "Projects"
        case companies = "Companies"
        case terms = "Terms"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Context System")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { loadContext() }) {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            // Category tabs
            Picker("Category", selection: $selectedCategory) {
                ForEach(ContextCategory.allCases, id: \.self) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            Group {
                switch selectedCategory {
                case .people:
                    PeopleListView()
                case .projects:
                    ProjectsListView()
                case .companies:
                    CompaniesListView()
                case .terms:
                    TermsListView()
                }
            }
        }
        .onAppear {
            loadContext()
        }
    }
    
    func loadContext() {
        ProtokolService.shared.loadContext(appState: appState)
    }
}

struct PeopleListView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List {
            ForEach(appState.contextData.people) { person in
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name)
                        .font(.headline)
                    
                    if let role = person.role, let company = person.company {
                        Text("\(role) at \(company)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !person.soundsLike.isEmpty {
                        Text("Sounds like: \(person.soundsLike.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct ProjectsListView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List {
            ForEach(appState.contextData.projects) { project in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(project.name)
                            .font(.headline)
                        
                        if project.active {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    
                    Text(project.destination)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !project.explicitPhrases.isEmpty {
                        Text("Triggers: \(project.explicitPhrases.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct CompaniesListView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List {
            ForEach(appState.contextData.companies) { company in
                VStack(alignment: .leading, spacing: 4) {
                    Text(company.name)
                        .font(.headline)
                    
                    if let context = company.context {
                        Text(context)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !company.soundsLike.isEmpty {
                        Text("Sounds like: \(company.soundsLike.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct TermsListView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List {
            ForEach(appState.contextData.terms) { term in
                VStack(alignment: .leading, spacing: 4) {
                    Text(term.term)
                        .font(.headline)
                    
                    if let context = term.context {
                        Text(context)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !term.soundsLike.isEmpty {
                        Text("Variants: \(term.soundsLike.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
