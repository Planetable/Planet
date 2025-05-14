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
        TextEditor(text: $llmViewModel.rawResult)
            .font(.custom("Menlo", size: 14.0))
            .lineSpacing(4.0)
            .disableAutocorrection(true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
