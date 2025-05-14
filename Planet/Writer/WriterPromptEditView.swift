//
//  WriterPromptEditView.swift
//  Planet
//
//  Created by Kai on 5/14/25.
//

import SwiftUI


struct WriterPromptEditView: View {
    @EnvironmentObject private var llmViewModel: WriterLLMViewModel
    @ObservedObject var draft: DraftModel

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $llmViewModel.prompt)
                .font(.custom("Menlo", size: 14.0))
                .lineSpacing(4.0)
                .disableAutocorrection(true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            HStack {
                Button("Cancel") {
                    llmViewModel.cancelCurrentRequest()
                }
                if !llmViewModel.prompts.isEmpty {
                    Menu("History") {
                        ForEach(llmViewModel.prompts, id: \.self) { prompt in
                            Button {
                                llmViewModel.prompt = prompt
                            } label: {
                                Text(prompt)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: 260)
                }
                Spacer()
                if llmViewModel.queryStatus == .sending {
                    Text("\(llmViewModel.queryStatus.description)")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
                Button("Submit") {
                    llmViewModel.sendPrompt()
                }
                .disabled(llmViewModel.queryStatus == LLMQueryStatus.sending)
            }
            .frame(height: 40)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            .padding(.top, 4)
        }
        .onChange(of: llmViewModel.result) { newValue in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.draft.content = newValue
            }
        }
    }
}
