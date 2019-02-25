/**
A library to support d libraries in remote repositories.
*/
module build.depends.dlibs;

import std.typecons : Flag, Yes, No;
import build.git : GitRepo;
//import build.depends : DependSet;

struct DLibrary
{
    GitRepo* repo;
    /// The path from the root of the repo to the library source
    private string repoSourcePath;
    DLibrary*[] deps;

    this(GitRepo* repo, string repoSourcePath, DLibrary*[] deps)
    {
        this.repo = repo;
        this.repoSourcePath = repoSourcePath;
        this.deps = deps;
    }
    void addCompilerArgs(T)(T sink)
    {
        import std.format : format;
        import std.path : buildPath;

        // TODO: need a way to check whether or not this library as already been added
        sink.put(format("-I=%s", buildPath(repo.localPath, repoSourcePath)));
    }
    void enforceExistsAddCompilerArgs(T)(T sink)
    {
        repo.enforceExists();
        addCompilerArgs(sink);
    }
}

/+
struct DBinaryRepo
{
    string url;
    string branch;
    // TODO: support specific revisions
     mixin cachingLocalPathMixin;

    this(string url, string branch)
    {
        this.url = url;
        this.branch = branch;
    }
    mixin updateRepoMethodMixin;
}
+/
