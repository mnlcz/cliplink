module urlfilter;

import std.regex;
import std.string : strip;

@safe:

private enum urlPattern = ctRegex!(`^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/[^\s]*)?$`);

string extractUrl(string text) @safe
{
    string candidate = text.strip();
    auto m = candidate.matchFirst(urlPattern);

    return m.empty ? null : candidate;
}

unittest
{
    // valid
    assert(extractUrl(
            "https://example.com/something/FILENAME") == "https://example.com/something/FILENAME");
    assert(extractUrl("http://example.com/path") == "http://example.com/path");
    assert(extractUrl("  https://example.com/trim  ") == "https://example.com/trim");
    assert(extractUrl("https://sub.domain.co.uk/file") == "https://sub.domain.co.uk/file");

    // invalid
    assert(extractUrl("not a url") is null);
    assert(extractUrl("ftp://example.com") is null);
    assert(extractUrl("https://nodot") is null);
    assert(extractUrl("") is null);
    assert(extractUrl("   ") is null);

    // should NOT match multi-line clipboard content
    assert(extractUrl("https://example.com\nhttps://other.com") is null);
}
