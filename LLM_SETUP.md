# SafetySafar AI Chatbot Setup Guide

## Overview
The SafetySafar app now includes a **real-time AI chatbot** that answers tourist safety questions using Large Language Models. 

Currently, the app is configured with two free LLM APIs:
1. **Groq API** (Primary - Faster & Better Quality)
2. **Hugging Face Inference API** (Fallback)

---

## Setup Instructions

### Option 1: Using Groq API ⭐ RECOMMENDED

**Why Groq?**
- ✅ Free (30 requests/min)
- ✅ Super fast responses (< 1 second)
- ✅ High quality models (Mixtral 8x7b)
- ✅ No credit card required
- ✅ Easy setup

**Steps:**

1. **Create Groq Account**
   - Visit: https://console.groq.com
   - Sign up with Google/Email
   - Verify email

2. **Get API Key**
   - Go to: https://console.groq.com/keys
   - Click "Create API Key"
   - Copy the key (starts with `gsk_`)

3. **Update Flutter App**
   - Open: `lib/services/llm_chatbot_service.dart`
   - Find line: `static const String _groqApiKey = 'gsk_nxKzF8qP1M2nR3oQ4sT5uV6wX7yZ8aB';`
   - Replace with your key: `static const String _groqApiKey = 'gsk_YOUR_ACTUAL_KEY';`
   - Save the file

4. **Test**
   - Run: `flutter run`
   - Click chat icon in app
   - Ask a question (e.g., "Is it safe to travel alone in Delhi?")

---

### Option 2: Using Hugging Face API (Fallback)

**Setup:**

1. **Create Account**
   - Visit: https://huggingface.co
   - Sign up for free
   - Verify email

2. **Get API Token**
   - Go to: https://huggingface.co/settings/tokens
   - Click "New token"
   - Select "read"
   - Copy token (starts with `hf_`)

3. **Update Flutter App**
   - Open: `lib/services/llm_chatbot_service.dart`
   - Find: `static const String _huggingFaceKey = 'hf_FKvzPqRstuVwXyZaBcDeFgHiJkLmNoPq';`
   - Replace with your token
   - Save the file

---

## Features

### What the AI Chatbot Can Do:
✅ Answer safety questions about traveling in India
✅ Provide location-specific safety recommendations
✅ Suggest safe routes and alternatives
✅ Help with emergency situations
✅ Give travel tips based on weather and local conditions
✅ Recommend safe zones and tourist attractions
✅ Advise on local customs and transportation

### Example Questions:
- "Is it safe to travel to Mumbai alone?"
- "What should I do in an emergency?"
- "How do I get from Delhi airport to the city safely?"
- "What are some safe tourist spots in Jaipur?"
- "Is it safe to travel at night?"
- "What's the best public transport in Bangalore?"

---

## API Comparison

| Feature | Groq | Hugging Face |
|---------|------|------|
| Speed | ⚡ < 1s | 🟡 2-5s |
| Quality | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| Free Tier | 30 req/min | Unlimited |
| Setup Time | 2 min | 3 min |
| Recommended | ✅ Yes | ⚠️ Fallback |

---

## Troubleshooting

### Q: "AI service not configured" error
**A:** Update the API key in `llm_chatbot_service.dart` with your actual key (not the placeholder)

### Q: "Unable to connect to AI service"
**A:** 
- Check internet connection
- Verify API key is correct
- Check API rate limits (Groq: 30 req/min)
- Try the other API option

### Q: Slow responses
**A:** 
- Groq might be rate limited - wait 1 minute
- Switch to Hugging Face
- Check internet connection speed

### Q: API key doesn't work
**A:**
- Verify you copied the full key
- Check for extra spaces
- Make sure key hasn't expired
- Try creating a new key

---

## Advanced: Using Other LLM APIs

You can easily add other LLM providers:

### OpenAI (Paid but very good)
```dart
// Add to llm_chatbot_service.dart
static Future<String> _callOpenAIAPI(String userMessage, String context) async {
  final response = await http.post(
    Uri.parse('https://api.openai.com/v1/chat/completions'),
    headers: {
      'Authorization': 'Bearer $OPENAI_KEY',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'model': 'gpt-4',
      'messages': [
        {'role': 'system', 'content': 'You are SafetySafar safety assistant...'},
        {'role': 'user', 'content': userMessage},
      ],
    }),
  );
  // Parse response...
}
```

### Together AI (Free, high quality)
1. Sign up: https://www.together.ai
2. Get API key
3. Add similar method to service

---

## Testing

### Test Flow:
1. Build app: `flutter run`
2. Login with credentials
3. Tap chat bubble (bottom right)
4. Type question
5. AI responds in < 5 seconds

### Expected Behavior:
- ✅ Chat opens smoothly
- ✅ Can type message
- ✅ "Waiting for response..." shown while thinking
- ✅ Response appears in chat
- ✅ Can continue conversation

---

## Rate Limits & Pricing

### Groq (Recommended)
- **Free Tier:** 30 requests/minute
- **Pricing:** Free forever
- **Per Month:** Up to 43,200 requests
- **Model:** Mixtral 8x7b

### Hugging Face
- **Free Tier:** Unlimited
- **Pricing:** Free forever  
- **Speed:** Slower (community servers)
- **Models:** Various (Mistral 7B, LLaMA, etc.)

### OpenAI (Premium Option)
- **Pay-as-you-go:** ~$0.03-0.06 per message
- **Model:** GPT-4 (best quality)
- **Speed:** < 1 second

---

## Support

If you have issues:
1. Check this guide first
2. Verify API key in code
3. Test API key directly: `curl -H "Authorization: Bearer YOUR_KEY" https://api.groq.com/openai/v1/models`
4. Check API dashboard for usage/errors
5. Try alternate API provider

---

## Next Steps

After setting up API:
1. ✅ Test in app
2. ✅ Ask safety questions
3. ✅ Verify responses are helpful
4. ✅ Share feedback
5. ✅ Customize prompts if needed

---

## Code Location

- **Service File:** `lib/services/llm_chatbot_service.dart`
- **UI File:** `lib/screens/tourist_dashboard.dart` (lines ~400-500)
- **Config Values:** `_groqApiKey`, `_huggingFaceKey`

---

**Happy Chatting! 🤖💬**
