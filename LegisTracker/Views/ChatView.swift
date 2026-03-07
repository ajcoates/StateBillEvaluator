import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
}

struct ChatView: View {
    @Bindable var viewModel: LegislationViewModel
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading = false
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("Ask Claude", systemImage: "bubble.left.and.text.bubble.right")
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            if messages.isEmpty {
                                Text("Ask questions about the selected bill, its impact, or legislation in general.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding()
                            }

                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }

                            if isLoading {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Thinking…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal)
                                .id("loading")
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: isLoading) { _, loading in
                        if loading {
                            proxy.scrollTo("loading", anchor: .bottom)
                        }
                    }
                }

                Divider()

                // Input
                HStack(spacing: 8) {
                    TextField("Ask about this bill…", text: $inputText)
                        .textFieldStyle(.plain)
                        .onSubmit { sendMessage() }

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.borderless)
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
                .padding(8)
            }
        }
        .onChange(of: viewModel.selectedBill?.billId) { _, _ in
            messages.removeAll()
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(role: "user", content: text))
        inputText = ""
        isLoading = true

        Task {
            let claude = ClaudeService()

            // Build system prompt with bill context
            var systemPrompt = "You are a helpful legislative analyst assistant. Be concise and direct."
            if let bill = viewModel.selectedBill {
                systemPrompt += """
                \n\nThe user is currently viewing this bill:
                Title: \(bill.title)
                State: \(bill.state)
                Status: \(bill.status)
                Description: \(bill.billDescription)
                Category: \(bill.categoryName ?? "Uncategorized")
                Passage Likelihood: \(bill.passageLikelihood.rawValue)
                """
                if let sponsors = bill.sponsors {
                    systemPrompt += "\nSponsors: \(sponsors)"
                }
                if let lastAction = bill.lastAction {
                    systemPrompt += "\nLast Action: \(lastAction)"
                }
                if let analysis = bill.impactAnalysisJSON {
                    systemPrompt += "\nImpact Analysis: \(analysis)"
                }
            }

            // Build conversation history
            let apiMessages = messages.map { ClaudeMessage(role: $0.role, content: $0.content) }

            do {
                let response = try await claude.chat(messages: apiMessages, systemPrompt: systemPrompt)
                await MainActor.run {
                    messages.append(ChatMessage(role: "assistant", content: response))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessage(role: "assistant", content: "Error: \(error.localizedDescription)"))
                    isLoading = false
                }
            }
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == "user" { Spacer(minLength: 40) }

            Text(message.content)
                .font(.callout)
                .padding(8)
                .background(message.role == "user" ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .textSelection(.enabled)

            if message.role == "assistant" { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 8)
    }
}
