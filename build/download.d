module build.download;

import std.functional : memoize;

import build.log;

/**
Downloads a file from a given URL

Params:
    to       = Location to store the file downloaded
    from     = The URL to the file to download
    attempts = The number of times to attempt the download
Returns: `true` if download succeeded
*/
bool tryDownload(string to, string from, uint attempts = 3)
{
    import std.net.curl : download, HTTPStatusException;

    for (auto attempt = 1; attempt <= attempts; attempt++)
    {
        try
        {
            logf("Attempt %s to download %s ...", attempt, from);
            download(from, to);
            return true;
        }
        catch(HTTPStatusException e)
        {
            if (e.status == 404) throw e;
            else
            {
                logf("Failed to download %s (Attempt %s of %s)", from, attempt, attempts);
                continue;
            }
        }
    }

    return false;
}

// TODO: inherit from a different exception
class DownloadFailedException : Exception
{
    this(string url)
    {
        import std.format : format;
        super(format("failed to download '%s'", url));
    }
}

string downloadAndExtract(string url, string targetDir = null)
{
    auto result = tryDownloadAndExtract(url, targetDir);
    if (!result)
        throw new DownloadFailedException(url);
    return result;
}
string tryDownloadAndExtract(string url, string targetDir = null)
{
    import std.format : format;
    import std.path : baseName, buildPath;
    import std.file : exists;
    import std.stdio : writefln;
    import build.path : shortRelpath;

    string localFile;
    if (targetDir is null)
        localFile = shortRelpath(baseName(url));
    else
        localFile = buildPath(targetDir, baseName(url));

    if (exists(localFile))
    {
        writefln("already downloaded '%s'", localFile);
    }
    else
    {
        // check if any of it's extracted intermediate forms exist
        for (string nextFile = localFile;;)
        {
            auto op = getExtractOp(nextFile);
            if (op.isNull)
                break;
            string currentFile = nextFile;
            nextFile = op.resultFile;
            if (exists(nextFile))
            {
                writefln("url '%s' was already downloaded and extracted to '%s'", url, nextFile);
                return extract(nextFile); // finish extraction if needed
            }
        }
        auto result = tryDownload(localFile, url);
        if (!result)
        {
            return null;
        }
        if (!exists(localFile))
            throw new Exception(format("tryDownload '%s' seemed to succeed but file '%s' still does not exist",
                url, localFile));
    }
    return extract(localFile);
}

string findGzip() { import build.proc : which; return which("gzip"); }
string findTar() { import build.proc : which; return which("tar"); }
alias getGzip = memoize!findGzip;
alias getTar = memoize!findTar;

bool endsWithRemove(string* str, string postfix)
{
    import std.string : endsWith;

    if ((*str).endsWith(postfix))
    {
        *str = (*str)[0 .. $ - postfix.length];
        return true;
    }
    return false;
}
struct ExtractOp
{
    string resultFile;
    void function(string file) func;

    static ExtractOp nullValue()
    {
        ExtractOp op = void;
        op.resultFile = null;
        return op;
    }
    bool isNull() const { return resultFile is null; }
}
ExtractOp getExtractOp(string file)
{
    if (endsWithRemove(&file, ".tar.gz"))
        return ExtractOp(file, &unTarGzip);
    else if (endsWithRemove(&file, ".gz"))
        return ExtractOp(file, &unGzip);
    else if (endsWithRemove(&file, ".tar"))
        return ExtractOp(file, &unTar);
    else if (endsWithRemove(&file, ".zip"))
        assert(0, ".zip not implemented");
    return ExtractOp.nullValue;
}

void unTarGzip(string file)
{
    import build.proc : run;

    run([getTar(), "-xzf", file]);
}
void unGzip(string file)
{
    import build.proc : run;

    run([getGzip(), "-d", file]);
}
void unTar(string file)
{
    import build.proc : run;

    run([getTar(), "-xf", file]);
}

string extract(string file)
{
    import std.format : format;
    import std.file : exists, remove;
    import std.stdio : writefln;

    string original = file;
    for (;;)
    {
        auto op = getExtractOp(file);
        if (op.isNull)
        {
            if (original == file)
                writefln("'%s' didn't need any extraction", file);
            else
                writefln("successfully extracted '%s' to '%s'", original, file);
            return file;
        }
        const currentFile = file;
        file = op.resultFile;
        if (exists(file))
        {
            writefln("'%s' already extracted, removing '%s'", file, currentFile);
            remove(currentFile);
            continue;
        }
        op.func(currentFile);
        if (exists(currentFile))
        {
            remove(currentFile);
            if (exists(currentFile))
                throw new Exception(format("could not remove '%s'", currentFile));
        }
        if (!exists(file))
            throw new Exception(format("failed to extract '%s' to '%s'", currentFile, file));
    }
}
