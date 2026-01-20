# Content Engine

A personal content velocity system for generating YouTube content and video ads at scale.

## Stack

- **Frontend**: Static HTML/CSS/JS (host on Vercel)
- **Backend Logic**: n8n workflows
- **Database**: Supabase (PostgreSQL + Storage)
- **AI**: Claude API (Anthropic), OpenAI Whisper (transcription)
- **Image Generation**: NanoBanana (thumbnails)

## Project Structure

```
youtube-content-system/
├── html/
│   ├── 01-generation-hub.html    # YouTube content generation
│   ├── 02-swipe-file.html        # Thumbnails, headlines, hooks swipes
│   ├── 03-face-library.html      # Face assets for thumbnails
│   ├── 04-output-review.html     # Review & refine generated content
│   ├── 05-history.html           # All generation history
│   ├── 06-ad-swipes.html         # Video ad swipe library
│   └── 07-ad-generator.html      # Ad script generation
├── n8n-workflows/
│   ├── 01-swipe-storage.json     # Analyze & store swipes
│   ├── 02-content-generation.json # YouTube content generation
│   ├── 03-regeneration.json      # Refine specific outputs
│   ├── 04-finalize.json          # Save final selections
│   ├── 05-ad-upload.json         # Video ad upload + transcription + analysis
│   └── 06-ad-generation.json     # Generate ad scripts from swipes
├── supabase/
│   └── schema.sql                # All tables
└── README.md
```

## Two Systems, One Engine

### YouTube Content System
- Upload thumbnail/headline/hook swipes → AI extracts patterns
- Describe video concept → Generate titles, hooks, thumbnail designs
- Review, refine, export

### Ad Generation System
- Upload winning video ads → Whisper transcribes → Claude extracts hook, structure, triggers
- Describe product/offer → Pull relevant swipe patterns → Generate 3 ad script versions
- Each version includes: hook, full script, shot list/production notes

## Setup Instructions

### 1. Supabase Setup

1. Create a new Supabase project at [supabase.com](https://supabase.com)
2. Go to SQL Editor
3. Copy and run the contents of `supabase/schema.sql`
4. Go to Settings → API and copy:
   - Project URL
   - `anon` public key
   - `service_role` secret key (for n8n)
5. Go to Storage and create a bucket called `assets` (set to public)

### 2. n8n Setup

1. Self-host n8n or use [n8n.cloud](https://n8n.cloud)
2. Go to Settings → Credentials and add:
   - **Supabase**: URL + service_role key
   - **Anthropic (Claude)**: API key
   - **NanoBanana**: API key (get from nanobanana.com)
3. Import each workflow from `n8n-workflows/`:
   - Click "Add Workflow" → "Import from File"
   - After import, update credential references in each node
4. Activate all workflows
5. Copy the webhook URLs for each workflow

### 3. Frontend Setup

1. Open each HTML file in `html/` folder
2. Find and replace these placeholders with your actual URLs:

```javascript
// In each HTML file, search for these and replace:
const WEBHOOK_SWIPE = 'YOUR_N8N_SWIPE_WEBHOOK_URL';
const WEBHOOK_GENERATE = 'YOUR_N8N_GENERATE_WEBHOOK_URL';
const WEBHOOK_REGENERATE = 'YOUR_N8N_REGENERATE_WEBHOOK_URL';
const WEBHOOK_FINALIZE = 'YOUR_N8N_FINALIZE_WEBHOOK_URL';
const SUPABASE_URL = 'YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

3. Deploy to Vercel:
```bash
cd html
vercel --prod
```

Or just open locally for testing.

### 4. NanoBanana Setup

1. Create account at [nanobanana.com](https://nanobanana.com)
2. Get API key
3. Add to n8n credentials

## Webhook Endpoints

| Workflow | Endpoint | Purpose |
|----------|----------|---------|
| Swipe Storage | POST `/swipe` | Add thumbnails/headlines/hooks to swipe file |
| Content Generation | POST `/generate` | Generate new content from concept |
| Regeneration | POST `/regenerate` | Regenerate specific output with refinement |
| Finalize | POST `/finalize` | Save final selections |

## Usage Flow

### Building Your Swipe File

1. Go to **Swipe File** page
2. For thumbnails: drag & drop screenshot → auto-analyzed and stored
3. For headlines: paste text → auto-analyzed and stored
4. For hooks: paste hook script → auto-analyzed and stored

The AI extracts patterns, triggers, and (for thumbnails) recreation prompts.

### Generating Content

1. Go to **Generate** page
2. Describe your video concept
3. Select niche
4. Check what to generate (thumbnails/titles/hooks)
5. Click Generate → redirects to Review page

### Reviewing & Refining

1. On **Review** page, see all generated options
2. Click to select your favorites
3. Use refinement text box + "Refine" button to iterate
4. Edit any text directly in the UI
5. Click "Export & Save" to finalize

### History

1. **History** page shows all past generations
2. Filter by niche, status, date
3. Click to view details or reuse

## Customization

### Adding Niches

Edit the niche dropdown in `01-generation-hub.html`:
```html
<select class="form-select" id="niche">
    <option value="your-new-niche">Your New Niche</option>
</select>
```

### Modifying Prompts

All AI prompts are in the n8n workflows. Key nodes to edit:
- `Claude: Analyze Swipe` — how swipes are categorized
- `Claude: Generate Titles` — title generation prompt
- `Claude: Generate Hooks` — hook generation prompt
- `Claude: Thumbnail Concepts` — thumbnail prompt generation

### Styling

All CSS is inline in each HTML file. Key variables at top:
```css
:root {
    --accent: #00ff88;  /* Change main accent color */
    --bg-primary: #0a0a0b;  /* Background */
}
```

## Cost Estimates

| Service | Usage | ~Cost/Month |
|---------|-------|-------------|
| Claude API | 20 generations/day | $12 |
| NanoBanana | 100 thumbnails/month | $10 |
| Supabase | Free tier | $0 |
| n8n Cloud | Starter | $20 |
| Vercel | Free tier | $0 |
| **Total** | | **~$42/month** |

Self-host n8n to reduce to ~$22/month.

## Troubleshooting

**Webhook not responding**
- Check n8n workflow is activated
- Check webhook URL is correct in HTML
- Check n8n logs for errors

**Images not uploading**
- Check Supabase Storage bucket is public
- Check bucket name is `assets`

**Claude errors**
- Check API key is valid
- Check you have credits

**CORS errors**
- Add your Vercel domain to Supabase allowed origins
- In n8n, ensure webhook node has "Respond Immediately" disabled

## Local Development

For quick iteration without deploying:

```bash
# Simple local server
cd html
npx serve

# Or just open files directly in browser
open 01-generation-hub.html
```

## Making UI Changes with AI

Open folder in Cursor or use Claude Code:
```bash
cursor /path/to/youtube-content-system/html
# or
cd /path/to/youtube-content-system/html && claude
```

Then just describe what you want changed.

---

Built for speed. Ship content. 🚀
