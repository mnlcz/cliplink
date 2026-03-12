module linkappender;

import std.stdio : File;
import std.path : expandTilde;

@safe:

immutable string outputFile = "~/links.txt";

bool appendLink(string link)
{
    try
    {
        openAndAppend(link);
        return true;
    }
    catch (Exception e)
    {
        return false;
    }
}

private void openAndAppend(string url) @trusted
{
    auto f = File(expandTilde(outputFile), "a");
    scope (exit)
        f.close();
    f.writeln(url);
}

unittest
{
    import std.file : remove, readText, exists;
    import std.string : strip;

    immutable testFile = "/tmp/cliplink_test.txt";

    /// Test version of `openAndAppend`.
    void appendTo(string url, string path) @trusted
    {
        auto f = File(path, "a");
        scope (exit)
            f.close();
        f.writeln(url);
    }

    if (exists(testFile))
        remove(testFile);

    appendTo("https://example.com/one", testFile);
    appendTo("https://example.com/two", testFile);

    string content = readText(testFile);
    assert(content == "https://example.com/one\nhttps://example.com/two\n",
        "File content mismatch: " ~ content);

    remove(testFile);
}
