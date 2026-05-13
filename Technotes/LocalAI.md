# Using Local AI with Planet

Planet can use a local AI server for AI Chat. Ollama is the recommended option; LM Studio also works if its local server is enabled. Gemma4 works especially well with Planet, including the chat tools used to search and read your Planet library.

## Ollama

1. Install and start Ollama.
2. Download a Gemma4 model in Ollama.
3. Open Planet, then go to Settings > AI.
4. If Planet shows "Ollama detected on localhost", click Use Ollama. Otherwise set API Base URL to `http://localhost:11434/v1`.
5. Leave API Token empty for the normal local Ollama setup.
6. Set Preferred Model to the exact model name shown by Ollama, then wait for Planet to report that the preferred model is supported.

After this, open Planet AI Chat from the toolbar, or use "Chat with AI about this article" from an article. Keep Ollama running while you use AI Chat.

## LM Studio

1. Install LM Studio and download a chat model.
2. Start the local server in LM Studio and make sure the model is loaded.
3. Open Planet, then go to Settings > AI.
4. If Planet shows "LM Studio detected on localhost", click Use LM Studio. Otherwise set API Base URL to `http://localhost:1234/v1`.
5. Leave API Token empty unless your LM Studio server is configured to require one.
6. Set Preferred Model to the exact model ID listed by LM Studio, then wait for Planet to report that the preferred model is supported.

## Notes

- Planet talks to local providers through OpenAI-compatible endpoints: `/v1/models` and `/v1/chat/completions`.
- Local HTTP endpoints are accepted for `localhost`, `127.0.0.0/8`, `10.0.0.0/8`, `100.0.0.0/8`, and `192.168.0.0/16`. Use HTTPS for other hosts.
- If the AI Chat button does not appear, check Settings > AI first. Planet enables AI Chat after it can reach the configured server and find the preferred model.
- If responses fail, confirm that the local server is running, the model is loaded, and the Preferred Model value matches the provider's model name exactly.
