//
//  FeatureFlags.swift
//  Planet
//

enum FeatureFlags {
    #if PLANET_ENABLE_APPLE_INTELLIGENCE
    static let appleIntelligenceSupport = true
    #else
    static let appleIntelligenceSupport = false
    #endif

    #if PLANET_ENABLE_AI_CHAT_SCROLL_MANAGEMENT
    static let aiChatScrollManagement = true
    #else
    static let aiChatScrollManagement = false
    #endif
}
