module build.filenames;

version (Windows)
{
    enum objExt = ".obj";
    enum libExt = ".lib";
    enum sharedLibExt = ".dll";
    enum exeExt = ".exe";
}
else
{
    enum objExt = ".o";
    enum libExt = ".a";
    enum sharedLibExt = ".so";
    enum exeExt = "";
}

/// Return the filename with the obj file extension
auto objName(T)(T s) { return s ~ objExt; }

/// Return the filename with the lib file extension
auto libName(T)(T s) { return s ~ libExt; }

/// Return the filename with the shared library file extension
auto sharedLibName(T)(T s) { return s ~ sharedLibExt; }

/// Return the filename with the exe file extension
auto exeName(T)(T s) { return s ~ exeExt; }
