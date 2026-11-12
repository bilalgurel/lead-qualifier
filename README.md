# AI Lead Qualifier (n8n workflow)

An n8n workflow that receives inbound leads, scores them with AI, and routes them as **hot**, **warm** or **cold**, with a ready-to-send reply for each one. Duplicate webhook events are detected and never sent to the AI twice.

## What it does

1. **Intake**: a webhook receives the lead (name, email, company, message).
2. **Validation**: bad input is rejected with a clear `400` answer.
3. **Duplicate check**: a lead that was already processed is answered from memory. Webhook retries cost nothing and create no duplicate records.
4. **AI scoring**: the model returns a 0-100 score, the reasons, a short summary for the sales team, and a suggested first reply, as structured JSON.
5. **Routing**: the tier is decided in code from configurable thresholds, then the lead goes down the Hot, Warm, Cold or Needs-review branch.

## Built for reliability

- **Idempotent**: uses the sender's `event_id` when present, otherwise email + message hash.
- **Safe retries**: the AI call is retried 3 times. If it still fails, the caller gets `502` and the lead is *not* marked as processed, so sending it again works.
- **The model does not make the decision**: it only proposes a score. The score is clamped to 0-100 and the tier is computed in code.
- **Unreadable AI answers** go to a "needs review" branch instead of breaking the flow.
- **Prompt-injection aware**: the lead text is passed as data and the model is told not to follow instructions inside it. One sample lead tries exactly that.
- **No secrets in the workflow**: the API key lives in an n8n credential.

## Setup

You need Node.js 20 or newer and a Gemini API key.

1. Start n8n:
   ```
   npx n8n
   ```
   Open http://localhost:5678 and create the local owner account.

2. Import the workflow: create a new workflow, open the menu (three dots, top right), choose **Import from File** and select `workflow.json`.

3. Add your API key: open the **Score lead with AI** node. Under *Credential for Header Auth* choose **Create new credential** and enter:
   - Name: `x-goog-api-key`
   - Value: your Gemini API key

4. Set the model: open the **Config** node and replace `PASTE_GEMINI_MODEL_ID` with a model id from https://ai.google.dev/gemini-api/docs/models. Edit `businessProfile` and the thresholds here as well.

5. Activate the workflow (the **Publish** / **Active** switch at the top).

## Try it

With the workflow active, from this folder:

```
powershell -ExecutionPolicy Bypass -File send_samples.ps1
```

or send one lead by hand:

```
curl -X POST http://localhost:5678/webhook/lead-intake -H "Content-Type: application/json" -d @samples/hot_lead.json
```

Expected results:

| Sample | Result |
|---|---|
| `hot_lead.json` | `tier: hot`, score 70 or above |
| `warm_lead.json` | `tier: warm` |
| `cold_lead.json` | `tier: cold` (spam that also tries to trick the AI into giving a score of 100) |
| `hot_lead.json` again | `status: duplicate`, no AI call |

Each run is visible under **Executions** in n8n, where you can see which branch the lead took.

## Example answer

```json
{
  "status": "processed",
  "tier": "hot",
  "score": 88,
  "reasons": ["Decision maker with approved budget", "Clear use case that matches our services"],
  "summary": "Operations director of a 4-clinic dental group wants a WhatsApp assistant within 3 weeks.",
  "suggested_reply": "Hi Sarah, thanks for reaching out...",
  "next_action": "Notify sales now and reply within one hour."
}
```

## Connect your own tools

The four branch nodes at the end are placeholders. Replace them with real actions, for example:

- **Hot**: Slack or email alert to sales, create a deal in the CRM
- **Warm**: add to an email sequence
- **Cold**: append a row to Google Sheets
- **Needs review**: message a person

## Notes and limits

- Duplicate memory uses n8n workflow static data. It only persists for the **active** workflow (production URL), not for manual test runs in the editor.
- It reliably catches retries that arrive after the first run has finished. Two identical events arriving at the exact same moment can both pass. For that level of guarantee, replace the memory with a database that has a unique key (Postgres, Redis or an n8n Data Table).
- To use another model provider, change the request in **Build prompt** and the response path in **Parse and score**.

Tested on n8n 2.35.
