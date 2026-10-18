# ILMU chatbot setup

Sign in at https://console.ilmu.ai/ and create an API key with available tokens. A chat website account alone is not API access. Check the console for free-plan availability, expiry and supported models before purchasing anything.

From this project folder run `python configure_ilmu.py`. Select a model your account supports (default `ilmu-nemo-nano`) and enter the key at the hidden prompt. The script selects ILMU in the ignored local backend/.env. Restart start_backend.ps1 to apply. No database migration or app server URL change is required.

Ask a short question in AI Assistant while parked. The laptop needs internet. Missing keys, exhausted tokens, connection failures and empty responses return errors. Rebuild the app for updated privacy text and timeout guidance. Until an ILMU key is configured, the existing Gemini selection remains unchanged.

Only the selected provider receives messages. Optional saved account summaries include only the signed-in user's journey and warning counts, not video or contacts. There is no automatic fallback to another provider.

To select Gemini again, run `python configure_gemini.py` and restart the backend.

References checked 16 October 2026:
- https://docs.ilmu.ai/docs/api/chat-completions
- https://docs.ilmu.ai/docs/getting-started/authentication
- https://console.ilmu.ai/pricing

Automated API tests use mocked provider responses. A live reply still requires a valid API key, available tokens and network access. The reported live no-reply issue has not yet been reproduced with an upstream response.
