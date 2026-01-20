-- YouTube Content Generation System
-- Supabase Schema
-- Run this in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- THUMBNAIL SWIPES
-- ============================================
CREATE TABLE thumbnail_swipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    image_url TEXT NOT NULL,
    composition TEXT, -- "face left, text right, high contrast"
    text_overlay TEXT, -- actual text visible on thumbnail
    triggers TEXT[] DEFAULT '{}', -- ["curiosity_gap", "shock"]
    colors TEXT, -- "green/black, yellow accent"
    recreation_prompt TEXT, -- detailed prompt to recreate this style
    niche TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for filtering by niche
CREATE INDEX idx_thumbnail_swipes_niche ON thumbnail_swipes(niche);

-- ============================================
-- HEADLINE SWIPES
-- ============================================
CREATE TABLE headline_swipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    raw_text TEXT NOT NULL, -- original headline
    pattern TEXT, -- "I [achieved X] in [timeframe] Using This [descriptor] [method]"
    triggers TEXT[] DEFAULT '{}',
    niche TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_headline_swipes_niche ON headline_swipes(niche);

-- ============================================
-- HOOK SWIPES
-- ============================================
CREATE TABLE hook_swipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    raw_text TEXT NOT NULL, -- full hook script
    hook_type TEXT, -- "curiosity_gap", "contrarian", "story_open", "authority", "shock", "question"
    pattern TEXT, -- structure breakdown
    opening_mechanism TEXT, -- "pattern interrupt", "bold claim", "question"
    triggers TEXT[] DEFAULT '{}',
    niche TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_hook_swipes_niche ON hook_swipes(niche);
CREATE INDEX idx_hook_swipes_type ON hook_swipes(hook_type);

-- ============================================
-- FACE ASSETS
-- ============================================
CREATE TABLE face_assets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    image_url TEXT NOT NULL,
    expression TEXT NOT NULL, -- "shocked", "serious", "pointing", "happy"
    tags TEXT[] DEFAULT '{}',
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_face_assets_expression ON face_assets(expression);

-- Ensure only one default per expression category
CREATE UNIQUE INDEX idx_face_assets_default 
ON face_assets(expression) 
WHERE is_default = TRUE;

-- ============================================
-- AD SWIPES (Video Ads)
-- ============================================
CREATE TABLE ad_swipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    video_url TEXT NOT NULL,
    hook_text TEXT, -- The opening hook (first 3-5 seconds)
    hook_type TEXT, -- problem_agitate, curiosity, social_proof, contrarian, story, question, shock
    concept TEXT, -- What's the angle/big idea
    structure JSONB, -- Array of {time, desc} for ad breakdown
    cta_type TEXT, -- soft, hard
    triggers TEXT[] DEFAULT '{}', -- emotional triggers used
    style TEXT, -- ugc, motion, mashup, product
    niche TEXT,
    transcript TEXT, -- Full transcript from Whisper
    duration_seconds INTEGER,
    source TEXT, -- Where the ad came from (FB Library, TikTok, etc)
    notes TEXT, -- Personal notes
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_ad_swipes_hook_type ON ad_swipes(hook_type);
CREATE INDEX idx_ad_swipes_niche ON ad_swipes(niche);
CREATE INDEX idx_ad_swipes_style ON ad_swipes(style);
CREATE INDEX idx_ad_swipes_created ON ad_swipes(created_at DESC);

-- ============================================
-- AD GENERATIONS (History for generated ads)
-- ============================================
CREATE TABLE ad_generations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product TEXT NOT NULL,
    angle TEXT,
    niche TEXT,
    style TEXT,
    duration_seconds INTEGER,
    hook_types TEXT[] DEFAULT '{}',
    template_id UUID REFERENCES ad_swipes(id), -- If based on a template
    versions JSONB, -- Array of generated versions
    selected_version INTEGER, -- Which version was selected
    status TEXT DEFAULT 'draft', -- draft, used, archived
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_ad_generations_niche ON ad_generations(niche);
CREATE INDEX idx_ad_generations_created ON ad_generations(created_at DESC);

-- ============================================
-- GENERATIONS (History)
-- ============================================
CREATE TABLE generations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    concept TEXT NOT NULL, -- original video concept input
    niche TEXT,
    status TEXT DEFAULT 'draft', -- "draft", "published", "archived"
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_generations_status ON generations(status);
CREATE INDEX idx_generations_niche ON generations(niche);
CREATE INDEX idx_generations_created ON generations(created_at DESC);

-- ============================================
-- GENERATION OUTPUTS
-- ============================================
CREATE TABLE generation_outputs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    generation_id UUID NOT NULL REFERENCES generations(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- "thumbnail", "title", "hook"
    content JSONB NOT NULL, -- flexible storage for any output type
    is_selected BOOLEAN DEFAULT FALSE,
    version INTEGER DEFAULT 1, -- for tracking regenerations
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_generation_outputs_generation ON generation_outputs(generation_id);
CREATE INDEX idx_generation_outputs_type ON generation_outputs(type);

-- ============================================
-- CONTENT STRUCTURE EXAMPLES
-- ============================================
-- 
-- Title content:
-- {
--   "text": "Why 99% of Herbalists Get This Wrong",
--   "pattern_used": "contrarian",
--   "triggers": ["curiosity", "authority"]
-- }
--
-- Hook content:
-- {
--   "text": "If you've tried every supplement...",
--   "hook_type": "curiosity_gap",
--   "word_count": 45
-- }
--
-- Thumbnail content:
-- {
--   "image_url": "https://...",
--   "prompt_used": "Shocked face left third...",
--   "style_reference_id": "uuid-of-swipe-used"
-- }

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for generations table
CREATE TRIGGER update_generations_updated_at
    BEFORE UPDATE ON generations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- ROW LEVEL SECURITY (Optional but recommended)
-- ============================================
-- Uncomment these if you want to add RLS policies

-- ALTER TABLE thumbnail_swipes ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE headline_swipes ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE hook_swipes ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE face_assets ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE generations ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE generation_outputs ENABLE ROW LEVEL SECURITY;

-- For a single-user system, you can create a simple "allow all" policy:
-- CREATE POLICY "Allow all" ON thumbnail_swipes FOR ALL USING (true);
-- (Repeat for other tables)

-- ============================================
-- STORAGE BUCKET
-- ============================================
-- Run this in Supabase Dashboard → Storage → New Bucket
-- Bucket name: assets
-- Public: Yes
--
-- Or via SQL:
-- INSERT INTO storage.buckets (id, name, public) VALUES ('assets', 'assets', true);

-- ============================================
-- SAMPLE DATA (Optional - for testing)
-- ============================================

-- Sample headline swipes
INSERT INTO headline_swipes (raw_text, pattern, triggers, niche) VALUES
('I Made $47,000 in 30 Days Using This Forgotten Marketing Strategy', 'I [achieved result] in [timeframe] Using This [descriptor] [method]', ARRAY['authority', 'curiosity'], 'marketing'),
('Why 99% of Herbalists Get Liver Support Wrong (And What Actually Works)', 'Why [percentage]% of [audience] Get [topic] Wrong (And What Actually Works)', ARRAY['contrarian', 'authority'], 'herbalism'),
('The $3 Herb That Outperforms $300 Supplements', 'The $[low amount] [item] That Outperforms $[high amount] [expensive item]', ARRAY['shock', 'value'], 'herbalism');

-- Sample hook swipes
INSERT INTO hook_swipes (raw_text, hook_type, pattern, opening_mechanism, triggers, niche) VALUES
('If you''ve tried milk thistle, dandelion root, and every liver supplement on the market... and you''re still dealing with fatigue, brain fog, and stubborn weight—it''s not because those herbs don''t work. It''s because you''re using them wrong.', 'curiosity_gap', 'Acknowledge failed attempts → Identify symptoms → Reframe the problem', 'empathy hook', ARRAY['curiosity', 'validation'], 'herbalism'),
('Your liver isn''t struggling because you need more supplements. It''s struggling because modern herbalism forgot how organs actually work.', 'contrarian', 'Bold contradictory claim → Root cause reframe', 'pattern interrupt', ARRAY['shock', 'authority'], 'herbalism');

-- ============================================
-- USEFUL QUERIES
-- ============================================

-- Get swipes by niche with trigger filtering
-- SELECT * FROM headline_swipes WHERE niche = 'herbalism' AND 'curiosity' = ANY(triggers);

-- Get all outputs for a generation
-- SELECT * FROM generation_outputs WHERE generation_id = 'your-uuid' ORDER BY type, created_at;

-- Get recent generations with selected outputs
-- SELECT g.*, 
--        (SELECT jsonb_agg(content) FROM generation_outputs WHERE generation_id = g.id AND is_selected = true) as selected
-- FROM generations g 
-- ORDER BY created_at DESC 
-- LIMIT 20;
