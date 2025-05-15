//
//  WriterLLMOutoutView.swift
//  Planet
//
//  Created by Kai on 5/14/25.
//

import SwiftUI


struct WriterLLMOutoutView: View {
    @EnvironmentObject private var llmViewModel: WriterLLMViewModel

    var body: some View {
        WriterPromptTextView(text: $llmViewModel.result)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
