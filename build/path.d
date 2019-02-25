module build.path;

import std.file : getcwd;

version (Posix)
{
    enum dirSeparators = "/";
}
else version (Windows)
{
    enum dirSeparators = "/\\";
}
else static assert(0, "Unsupported operating system.");

/**
Return the shorter version of the given `path` be it a relative or absolute path.
*/
auto shortPath(const(char)[] path, const(char)[] base = getcwd())
{
    import std.path : buildNormalizedPath, relativePath, absolutePath;

    auto relpath = buildNormalizedPath(relativePath(cast(string)path, cast(string)base));
    auto abspath = buildNormalizedPath(absolutePath(cast(string)path, cast(string)base));
    return (abspath.length <= relpath.length) ? abspath : relpath;
}

/**
Return the shorter version of the given `path` relative to the file calling the function.
*/
pragma(inline)
auto shortRelpath(C, string callerFileFullPath = __FILE_FULL_PATH__)(const(C)[][] paths...)
{
    import std.path : buildPath, dirName;

    return shortPath(buildPath(paths), dirName(callerFileFullPath));
}
