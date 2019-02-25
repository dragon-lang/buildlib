module build.git;

private __gshared string defaultGitRepoDir = null;
void setDefaultGitRepoDir(string dir)
{
    assert(dir !is null, "code bug: cannot call setDefaultGitRepoDir with null value");
    assert(defaultGitRepoDir is null, "code bug: cannot call setDefaultGitRepoDir more than once");
    defaultGitRepoDir = dir;
}
string getDefaultGitRepoDir()
{
    assert(defaultGitRepoDir !is null, "code bug: cannot call getDefaultGitRepoDir before setDefaultGitRepoDir has been called");
    return defaultGitRepoDir;
}

// TODO: which class to inherit from?
class MissingGitRepoException : Exception
{
    this(GitRepo repo)
    {
        import std.format : format;
        super(format("missing repo, clone it with: git clone %s %s", repo.url, repo.localPath), null, 0);
    }
}

struct GitRepo
{
    string url;
    string branch;
    // TODO: support specific revisions
    private string cachedLocalPath;

    this(string url, string branch)
    {
        this.url = url;
        this.branch = branch;
    }

    auto localPath()
    {
        import std.path : baseName, buildPath;

        if (cachedLocalPath is null)
            cachedLocalPath = buildPath(getDefaultGitRepoDir, baseName(url));
        return cachedLocalPath;
    }
    void overrideLocalPath(string path)
    in { assert(path !is null, "code bug: cannot call overridetLocalPath with a null value");
         assert(cachedLocalPath is null, "code bug: build has called overrideLocalPath but it has already taken on the default value"); } do
    {
        this.cachedLocalPath = path;
    }

    void enforceExists()
    {
        import std.file : exists;

        if (!exists(localPath))
            throw new MissingGitRepoException(this);
    }
    void update()
    {
        import std.file : exists;
        import build.proc : run;

        // TODO: should I just return instead?
        assert(url !is null, "cannot call update on a repo that doesn't have a url");

        if (exists(localPath))
        {
            // todo: probably don't use my 'fetchout' tool
            run(["git", "-C", localPath, "fetchout", "origin", "master"]);
        }
        else
        {
            run(["git", "clone", url, localPath]);
        }
    }
}
