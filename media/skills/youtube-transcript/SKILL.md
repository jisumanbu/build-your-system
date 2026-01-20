---
name: youtube-transcript
description: This skill should be used when the user provides a YouTube link, asks to "get transcript", "extract subtitles", "获取字幕", "提取字幕", "拿字幕", or when any YouTube URL (youtube.com/watch, youtu.be, youtube.com/shorts, youtube.com/live) appears in the message.
---

# YouTube Transcript Extractor

Extract subtitles from YouTube videos as plain text, automatically detecting the best available language.

## When to Use

Activate when:
- A YouTube URL appears in the user's message
- User asks to extract/get subtitles or transcript from a video
- User provides a video ID and wants its content

## Supported URL Formats

- `https://www.youtube.com/watch?v=VIDEO_ID`
- `https://youtu.be/VIDEO_ID`
- `https://www.youtube.com/shorts/VIDEO_ID`
- `https://www.youtube.com/live/VIDEO_ID`
- Direct video ID (11 characters)

## How to Use

### Step 1: Extract Video ID

Identify the YouTube URL or video ID from the user's message using regex:

```
(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/shorts/|youtube\.com/live/)([a-zA-Z0-9_-]{11})
```

### Step 2: Run the Script

Execute the fetch script with the URL or video ID:

```bash
python "${CLAUDE_PLUGIN_ROOT}/skills/youtube-transcript/scripts/fetch_transcript.py" "<youtube_url_or_video_id>"
```

The script will:
1. Extract video ID from URL
2. Fetch available transcripts
3. Select best language (priority: 中文 → English → others)
4. Return plain text without timestamps

### Step 3: Return Result

Present the transcript to the user. For long transcripts, consider:
- Summarizing key points
- Breaking into sections
- Asking what the user wants to do with it

## Language Priority

The script automatically selects subtitles in this order:
1. Chinese (zh-Hans, zh-Hant, zh, zh-CN, zh-TW)
2. English (en, en-US, en-GB)
3. Any other available language

## Error Handling

| Error | Meaning | Response |
|-------|---------|----------|
| Cannot extract video ID | Invalid URL format | Ask user for correct link |
| Transcripts disabled | Video owner disabled subtitles | Inform user, no workaround |
| No transcript found | No subtitles available | Inform user |
| Video unavailable | Video deleted/private | Inform user |

## Example Usage

**User input:**
> 帮我提取这个视频的字幕 https://www.youtube.com/watch?v=dQw4w9WgXcQ

**Action:**
```bash
python "${CLAUDE_PLUGIN_ROOT}/skills/youtube-transcript/scripts/fetch_transcript.py" "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
```

**Response:**
Return the extracted transcript text to the user.

## Integration with Other Skills

This skill pairs well with:
- **transcript-cleaner**: Clean up auto-generated subtitles
- **script-writing**: Use transcript as research material
