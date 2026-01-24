#!/usr/bin/env node

// Import tweets from Apify JSON export into Supabase tw_swipefile
// Usage: node import-tweets.js <path-to-json> [username] [--min-likes=X] [--min-bookmarks=X] [--min-retweets=X] [--min-replies=X] [--text-only]
//
// Examples:
//   node import-tweets.js tweets.json thedankoe --min-likes=500 --min-bookmarks=100
//   node import-tweets.js tweets.json thedankoe --min-retweets=50 --text-only

const fs = require('fs');
const path = require('path');

const SUPABASE_URL = 'https://wqclspynbdghfsosqygg.supabase.co';
const SUPABASE_KEY = 'sb_publishable_TnW2BTNaZvow6Gm8DbxU-w_5YyQN3Av';
const BATCH_SIZE = 500;

function parseArgs(args) {
    const flags = {};
    const positional = [];

    for (const arg of args) {
        if (arg.startsWith('--')) {
            const [key, val] = arg.slice(2).split('=');
            flags[key] = val !== undefined ? val : true;
        } else {
            positional.push(arg);
        }
    }

    return {
        filePath: positional[0],
        username: positional[1] || null,
        minLikes: parseInt(flags['min-likes']) || 0,
        minBookmarks: parseInt(flags['min-bookmarks']) || 0,
        minRetweets: parseInt(flags['min-retweets']) || 0,
        minReplies: parseInt(flags['min-replies']) || 0,
        textOnly: flags['text-only'] === true
    };
}

async function importTweets(opts) {
    const raw = fs.readFileSync(opts.filePath, 'utf8');
    const tweets = JSON.parse(raw);

    console.log(`Loaded ${tweets.length} tweets from ${path.basename(opts.filePath)}`);
    console.log(`Filters: min-likes=${opts.minLikes} min-bookmarks=${opts.minBookmarks} min-retweets=${opts.minRetweets} min-replies=${opts.minReplies} text-only=${opts.textOnly}`);

    // Map Apify fields to tw_swipefile columns
    const rows = tweets.map(t => {
        let username = opts.username;
        if (!username && t.url) {
            const match = t.url.match(/x\.com\/([^/]+)\//);
            if (match) username = match[1];
        }

        const content = t.text || t.fullText || '';
        const likes = t.likeCount || t.likes || 0;
        const replies = t.replyCount || t.replies || 0;
        const retweets = t.retweetCount || t.retweets || 0;
        const views = t.viewCount || t.views || 0;
        const bookmarks = t.bookmarkCount || t.bookmarks || 0;

        return {
            username: username || 'unknown',
            content,
            likes,
            replies,
            retweets,
            views,
            bookmarks,
            content_type: detectContentType(t),
            notes: t.url || null
        };
    })
    // Filter: must have content
    .filter(r => r.content && r.content.length > 0)
    // Filter: text-only removes tweets that are just links (https://t.co/...)
    .filter(r => {
        if (!opts.textOnly) return true;
        const stripped = r.content.replace(/https?:\/\/\S+/g, '').trim();
        return stripped.length > 0;
    })
    // Filter: engagement minimums
    .filter(r => r.likes >= opts.minLikes)
    .filter(r => r.bookmarks >= opts.minBookmarks)
    .filter(r => r.retweets >= opts.minRetweets)
    .filter(r => r.replies >= opts.minReplies);

    console.log(`${rows.length} tweets passed all filters (${tweets.length - rows.length} filtered out)`);

    if (rows.length === 0) {
        console.log('Nothing to import. Try lowering your filter thresholds.');
        return;
    }

    // Batch insert
    let inserted = 0;
    for (let i = 0; i < rows.length; i += BATCH_SIZE) {
        const batch = rows.slice(i, i + BATCH_SIZE);
        const res = await fetch(`${SUPABASE_URL}/rest/v1/tw_swipefile`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'apikey': SUPABASE_KEY,
                'Authorization': `Bearer ${SUPABASE_KEY}`,
                'Prefer': 'return=minimal'
            },
            body: JSON.stringify(batch)
        });

        if (!res.ok) {
            const err = await res.text();
            console.error(`Batch ${Math.floor(i/BATCH_SIZE) + 1} failed: ${res.status} ${err}`);
        } else {
            inserted += batch.length;
            console.log(`Inserted batch ${Math.floor(i/BATCH_SIZE) + 1}: ${inserted}/${rows.length}`);
        }
    }

    console.log(`\nDone! ${inserted} tweets imported to tw_swipefile`);
}

function detectContentType(tweet) {
    if (tweet.isRetweet) return 'retweet';
    if (tweet.isQuote) return 'quote';
    const text = tweet.text || tweet.fullText || '';
    if (text.startsWith('@')) return 'reply';
    return 'tweet';
}

// Run
const args = process.argv.slice(2);
if (args.length === 0) {
    console.log('Usage: node import-tweets.js <path-to-json> [username] [flags]');
    console.log('');
    console.log('Flags:');
    console.log('  --min-likes=X       Only import tweets with >= X likes');
    console.log('  --min-bookmarks=X   Only import tweets with >= X bookmarks');
    console.log('  --min-retweets=X    Only import tweets with >= X retweets');
    console.log('  --min-replies=X     Only import tweets with >= X replies');
    console.log('  --text-only         Skip tweets that are just links (image/video posts)');
    process.exit(1);
}

const opts = parseArgs(args);
importTweets(opts);
