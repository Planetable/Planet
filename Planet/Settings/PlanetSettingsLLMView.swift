//
//  PlanetSettingsLLMView.swift
//  Planet
//
//  Created by Kai on 5/14/25.
//

import SwiftUI


struct PlanetSettingsLLMView: View {
    @EnvironmentObject private var viewModel: WriterLLMViewModel
    
    var body: some View {
        VStack {
            Form {
                Section {
                    Picker("Server Scheme", selection: $viewModel.serverScheme) {
                        Text("HTTP")
                            .tag("http")
                        Text("HTTPS")
                            .tag("https")
                    }
                    .pickerStyle(.radioGroup)
                    TextField("Server URL", text: $viewModel.serverURL)
                        .textFieldStyle(.roundedBorder)
                    TextField("Server Port", text: $viewModel.serverPort)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.top, 6)
                
                Section {
                    if !viewModel.availableModels.isEmpty {
                        Picker("Select Model", selection: $viewModel.selectedModel) {
                            ForEach(viewModel.availableModels, id: \.self) { model in
                                Text(model)
                                    .tag(model)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    } else {
                        Text("No model available.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 6)

                Spacer()
            }
            .padding()

            Spacer(minLength: 12)

            HStack {
                Spacer()
                Button {
                    viewModel.loadAvailableModels()
                } label: {
                    Text("Reload Models")
                }
            }
            .frame(height: 42)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .background(Color.secondary.opacity(0.1))
        }
    }
}

#Preview {
    PlanetSettingsLLMView()
}
