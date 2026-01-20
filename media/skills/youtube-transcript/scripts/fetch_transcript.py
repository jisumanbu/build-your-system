#!/usr/bin/env python3
"""
YouTube Transcript Fetcher
Extracts subtitles from YouTube videos with language priority: zh > en > others
Usage: python fetch_transcript.py <youtube_url_or_video_id>
"""

import sys
import re
from youtube_transcript_api import YouTubeTranscriptApi
from youtube_transcript_api._errors import (
    TranscriptsDisabled,
    NoTranscriptFound,
    VideoUnavailable,
)


def extract_video_id(url_or_id: str) -> str:
    """Extract video ID from various YouTube URL formats."""
    patterns = [
        r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/shorts/|youtube\.com/live/)([a-zA-Z0-9_-]{11})',
        r'^([a-zA-Z0-9_-]{11})$',  # Direct video ID
    ]

    for pattern in patterns:
        match = re.search(pattern, url_or_id)
        if match:
            return match.group(1)

    return None


def fetch_transcript(video_id: str) -> str:
    """
    Fetch transcript with language priority: zh > en > others.
    Returns plain text without timestamps.
    """
    api = YouTubeTranscriptApi()

    # Get available transcripts
    transcript_list = api.list(video_id)

    # Language priority
    priority_langs = ['zh-Hans', 'zh-Hant', 'zh', 'zh-CN', 'zh-TW', 'en', 'en-US', 'en-GB']

    selected_transcript = None

    # Try priority languages first
    for lang in priority_langs:
        try:
            selected_transcript = transcript_list.find_transcript([lang])
            break
        except NoTranscriptFound:
            continue

    # Fallback to any available transcript
    if selected_transcript is None:
        try:
            # Get first available (manual or generated)
            for transcript in transcript_list:
                selected_transcript = transcript
                break
        except Exception:
            pass

    if selected_transcript is None:
        raise NoTranscriptFound("No transcript available for this video")

    # Fetch and join text
    snippets = selected_transcript.fetch()
    text = ' '.join(snippet.text for snippet in snippets)

    return text


def main():
    if len(sys.argv) < 2:
        print("Usage: python fetch_transcript.py <youtube_url_or_video_id>", file=sys.stderr)
        sys.exit(1)

    url_or_id = sys.argv[1]
    video_id = extract_video_id(url_or_id)

    if not video_id:
        print(f"Error: Cannot extract video ID from '{url_or_id}'", file=sys.stderr)
        sys.exit(1)

    try:
        transcript = fetch_transcript(video_id)
        print(transcript)
    except TranscriptsDisabled:
        print("Error: Transcripts are disabled for this video", file=sys.stderr)
        sys.exit(1)
    except NoTranscriptFound as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except VideoUnavailable:
        print("Error: Video is unavailable", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
