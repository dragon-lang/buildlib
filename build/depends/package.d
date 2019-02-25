module build.depends;

// TODO: this struct should not be defined here
private struct Set(T)
{
    import std.array : Appender;

    private Appender!(T*[]) elements;

    auto range() inout { return elements.data; }
    bool contains(T* element)
    {
        foreach (existing; elements.data)
        {
            if (element is existing)
                return true;
        }
        return false;
    }
    bool add(T* element)
    {
        if (contains(element))
            return false; // already added
        elements.put(element);
        return true; // newly added
    }
}

struct Depends
{
    import build.git : GitRepo;
    import build.depends.dlibs : DLibrary;

    Set!GitRepo repoSet;
    Set!DLibrary dlibSet;

    // Add a library and its dependencies
    // Returns: true if newly added, false if it was already added
    bool add(DLibrary* dlib)
    {
        if (dlibSet.contains(dlib))
            return false; // already added
        foreach (dep; dlib.deps)
        {
            add(dep);
        }
        if (dlib.repo)
            repoSet.add(dlib.repo);

        // sanity check
        assert(!dlibSet.contains(dlib), "code bug: circular dependency on dlibrary?");
        dlibSet.add(dlib);
        return true; // newly added
    }

    bool add(GitRepo* repo)
    {
        return repoSet.add(repo);
    }

    void updateRepos()
    {
        foreach (repo; repoSet.range)
        {
            repo.update();
        }
    }

    void enforceExistsAddCompilerArgs(Sink)(Sink sink)
    {
        foreach (lib; dlibSet.range)
        {
            lib.enforceExistsAddCompilerArgs(sink);
        }
    }
}
