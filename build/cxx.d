module cxx;

import std.meta : AliasSeq;
import std.typecons : Nullable, Flag, Yes, No;
import std.array : Appender, appender;

import build.error : fatal;

enum CxxKind { gnu, clang, dmc, msvc }
enum Arch { x86, x86_64 }

//private char capital(char c) { return cast(char)(c - ('a' - 'A')); }

private struct CxxFlag
{
    string name;
}
private enum cxxFlags = AliasSeq!(
    CxxFlag("compileCAsCxx"), // compile as c++ even if files are *.c
    CxxFlag("noLink"),
    CxxFlag("noExcept"),
    CxxFlag("noRtti"),
    CxxFlag("pic"),
    CxxFlag("warningsAsErrors"),
);
private struct CxxTypedArg
{
    string type;
    string name;
    // name of extra bool variable that is set to true when the field is set
    string setterFieldName;
}
private enum cxxTypedArgs = AliasSeq!(
    CxxTypedArg("string", "outName"),
    CxxTypedArg("Arch", "overrideTargetArch", "overrideTargetArchIsSet"),
);
private struct CxxList
{
    string singleName;
    string multiName;
}
private enum cxxLists = AliasSeq!(
    CxxList("define", "defines"),
    CxxList("includePath", "includePaths"),
    CxxList("source", "sources"),
    CxxList("customArg", "customArgs"),
);

struct CxxArgs
{
    private static struct Data
    {
        static foreach (cxxFlag; cxxFlags)
        {
            mixin("bool " ~ cxxFlag.name ~ ";");
        }
        static foreach (cxxTypedArg; cxxTypedArgs)
        {
            static if (cxxTypedArg.setterFieldName)
            {
                mixin("bool " ~ cxxTypedArg.setterFieldName ~ ";");
            }
            mixin(cxxTypedArg.type ~ " " ~ cxxTypedArg.name ~ ";");
        }
        static foreach (cxxList; cxxLists)
        {
            mixin("Appender!(string[]) " ~ cxxList.multiName ~ ";");
        }
        void putArgs(CxxKind kind, Appender!(string[]) args) const
        {
            if (compileCAsCxx)
            {
                if (kind == CxxKind.dmc)
                    args.put("-cpp");
                if (kind == CxxKind.msvc)
                    args.put("/TP");
            }
            if (noLink)
                args.put("-c");
            if (outName)
            {
                if (kind == CxxKind.msvc)
                {
                    if (noLink)
                        args.put("/Fo:" ~ outName);
                    else
                        args.put("/Fe:" ~ outName);
                }
                else
                {
                    args.put("-o" ~ outName);
                }
            }
            if (overrideTargetArchIsSet)
            {
                final switch (overrideTargetArch)
                {
                    case Arch.x86:
                        if (kind == CxxKind.gnu || kind == CxxKind.clang)
                        {
                            // TODO: this isn't right, but works for now
                            // ALSO: this won't work if the 32-bit libraries
                            //       are not installed, should check for that?
                            args.put("-m32");
                        }
                        else if (kind == CxxKind.dmc)
                            throw fatal("DMC does not support overrideTargetArch");
                        else if (kind == CxxKind.msvc)
                            throw fatal("MSVC does not support overrideTargetArch");
                        break;
                    case Arch.x86_64:
                        assert(0, "not impl");
                }
            }
            if (noExcept)
            {
                if (kind == CxxKind.gnu || kind == CxxKind.clang)
                    args.put("-fno-exceptions");
                // TODO: a way to do this in dmc/msvc?
            }
            if (noRtti)
            {
                if (kind == CxxKind.gnu || kind == CxxKind.clang)
                    args.put("-fno-rtti");
                // TODO: a way to do this in dmc/msvc?
            }
            if (pic)
            {
                if (kind == CxxKind.gnu || kind == CxxKind.clang)
                    args.put("-fpic");
                // TODO: a way to do this in dmc/msvc?
            }
            if (warningsAsErrors)
            {
                if (kind == CxxKind.gnu || kind == CxxKind.clang)
                    args.put("-Werror");
                else if (kind == CxxKind.dmc)
                    args.put("-wx");
                // TODO: a way to do this in msvc?
            }
            foreach (define; defines.data)
                args.put("-D" ~ define);
            foreach (path; includePaths.data)
                args.put("-I" ~ path);
            foreach (source; sources.data)
                args.put(source);
            foreach (customArg; customArgs.data)
                args.put(customArg);
        }
    }
    private Data current;

    void putArgs(CxxKind kind, Appender!(string[]) args) const
    {
        current.putArgs(kind, args);
    }

    CxxArgs* merge(ref const CxxArgs args)
    {
        static foreach (cxxFlag; cxxFlags)
        {
            __traits(getMember, current, cxxFlag.name) =
                __traits(getMember, args.current, cxxFlag.name);
        }
        static foreach (cxxTypedArg; cxxTypedArgs)
        {
            static if (cxxTypedArg.setterFieldName)
            {
                __traits(getMember, current, cxxTypedArg.setterFieldName) =
                    __traits(getMember, args.current, cxxTypedArg.setterFieldName);
            }
            __traits(getMember, current, cxxTypedArg.name) =
                __traits(getMember, args.current, cxxTypedArg.name);
        }
        static foreach (cxxList; cxxLists)
        {
            __traits(getMember, current, cxxList.multiName).put(
                __traits(getMember, args.current, cxxList.multiName).data);
        }
        return &this;
    }
    static foreach (cxxFlag; cxxFlags)
    {
        mixin(`CxxArgs* ` ~ cxxFlag.name ~ `() { this.current.` ~
            cxxFlag.name ~ ` = true; return &this; }`);
    }
    static foreach (cxxTypedArg; cxxTypedArgs)
    {
        mixin(`CxxArgs* ` ~ cxxTypedArg.name ~ `(` ~ cxxTypedArg.type ~ ` value)
{
    this.current.` ~ cxxTypedArg.name ~ ` = value;`
~ ((!cxxTypedArg.setterFieldName) ? "" : `
    this.current.` ~ cxxTypedArg.setterFieldName ~ ` = true;`) ~ `
    return &this;
}
`);
    }
    static foreach (cxxList; cxxLists)
    {
        mixin(`CxxArgs* ` ~ cxxList.singleName ~ `(string value) { this.current.` ~
            cxxList.multiName ~ `.put(value); return &this; }`);
        mixin(`CxxArgs* ` ~ cxxList.multiName ~ `(T)(T values) { this.current.` ~
            cxxList.multiName ~ `.put(values); return &this; }`);
    }
}

struct CxxArgsWithCompiler
{
    private CxxCompiler* compiler;
    private CxxArgs cxxArgs;
    string[] makeArgs() const
    {
        auto args = appender!(string[]);
        args.put(compiler.program);
        cxxArgs.putArgs(compiler.kind, args);
        return args.data;
    }
    void putArgs(Appender!(string[]) args) const { cxxArgs.putArgs(compiler.kind, args); }
    CxxArgsWithCompiler* merge(ref const CxxArgs args) { cxxArgs.merge(args); return &this; }
    static foreach (cxxFlag; cxxFlags)
    {
        mixin(`CxxArgsWithCompiler* ` ~ cxxFlag.name ~ `() { cxxArgs.` ~
            cxxFlag.name ~ `(); return &this; }`);
    }
    static foreach (cxxTypedArg; cxxTypedArgs)
    {
        mixin(`CxxArgsWithCompiler* ` ~ cxxTypedArg.name ~ `(` ~ cxxTypedArg.type ~ ` value) { cxxArgs.` ~
            cxxTypedArg.name ~ `(value); return &this; }`);
    }
    static foreach (cxxList; cxxLists)
    {
        mixin(`CxxArgsWithCompiler* ` ~ cxxList.singleName ~ `(string value) { cxxArgs.` ~
            cxxList.singleName ~ `(value); return &this; }`);
        mixin(`CxxArgsWithCompiler* ` ~ cxxList.multiName ~ `(T)(T values) { cxxArgs.` ~
            cxxList.multiName ~ `(values); return &this; }`);
    }
}

bool findX86NoX64(string s)
{
    import std.string : indexOfAny, startsWith;

    for (;;)
    {
        auto i = s.indexOfAny("xX");
        if (i < 0)
            return false;
        s = s[i + 1 .. $];
        if (!s.startsWith("86"))
            continue;
        s = s[2 .. $];
        if (!s.startsWith("_64"))
            return true;
    }
}
unittest
{
    assert(!findX86NoX64(""));
    assert(!findX86NoX64(""));
    assert(!findX86NoX64("x"));
    assert(!findX86NoX64("X"));
    assert(!findX86NoX64("x8"));
    assert(!findX86NoX64("X8"));
    assert(findX86NoX64("x86"));
    assert(findX86NoX64("X86"));
    assert(findX86NoX64("x86_"));
    assert(findX86NoX64("X86_"));
    assert(findX86NoX64("x86_6"));
    assert(findX86NoX64("X86_6"));
    assert(!findX86NoX64("x86_64"));
    assert(!findX86NoX64("X86_64"));
}

enum ArchSupport
{
    no,
    yesDefault,
    yesNotDefault,
}

struct CxxCompiler
{
    string program;
    CxxKind kind;

    private static struct Cached
    {
        string compilerInfo; // A string returned by the compiler
        Nullable!Arch defaultTargetArch;
        bool nonDefaultTargetArchsDetermined;
        Arch[] nonDefaultTargetArchs;
    }
    Cached cached;

    CxxArgsWithCompiler makeCommand() { return CxxArgsWithCompiler(&this, CxxArgs()); }

    private string queryCompilerInfo()
    {
        import build.proc : tryExecute;

        if (kind == CxxKind.gnu)
        {
            return tryExecute([program, "-v"]).output;
        }

        if (kind == CxxKind.dmc)
        {
            // no need to query dmc, only support x86 as far as I know
            return "only supports x86";
        }

        if (kind == CxxKind.msvc)
        {
            return tryExecute([program]).output;
        }
        assert(0, "queryCompiler not implemented for this compiler");
    }
    private string getCompilerInfo()
    {
        if (cached.compilerInfo is null)
        {
            cached.compilerInfo = queryCompilerInfo();
            assert(cached.compilerInfo, "code bug");
        }
        return cached.compilerInfo;
    }

    private Arch determineDefaultTargetArch()
    {
        import std.algorithm : canFind;
        import std.string : startsWith;
        import std.ascii : isWhite;
        import build.string : sliceAfter, until;

        if (kind == CxxKind.gnu)
        {
            const info = getCompilerInfo();
            auto defaultTarget = info.sliceAfter("Target: ");
            if (defaultTarget is null)
                throw fatal("'%s' -v output does not contain 'Target: ': %s", program, info);
            if (defaultTarget.startsWith("x86_64"))
                return Arch.x86_64;
            if (defaultTarget.startsWith("x86"))
               return Arch.x86;
            throw fatal("'%s' -v contains unknown 'Target: %s'", program, defaultTarget.until!isWhite);
        }

        if (kind == CxxKind.dmc)
            return Arch.x86; // only support x86 as far as I know

        if (kind == CxxKind.msvc)
        {
            const info = getCompilerInfo();
            if (info.canFind("x64") || info.canFind("x86_64"))
                return Arch.x86_64;
            if (info.canFind("x86"))
                return Arch.x86;
            throw fatal("cl output doesn't contain a known arch (i.e. x86): %s", info);
        }

        assert(0, "determineDefaultTargetArch not implemented for this compiler");
    }
    Arch getDefaultTargetArch()
    {
        import std.typecons : nullable;

        if (cached.defaultTargetArch.isNull)
        {
            cached.defaultTargetArch = determineDefaultTargetArch().nullable();
            assert(!cached.defaultTargetArch.isNull, "code bug");
        }
        return cached.defaultTargetArch.get;
    }

    private Arch[] determineNonDefaultTargetArchs()
    {
        import std.algorithm : canFind;
        import std.ascii : isWhite;
        import build.string : sliceAfter, until;

        auto archs = appender!(Arch[])();
        if (kind == CxxKind.gnu)
        {
            auto info = getCompilerInfo();
            for (;;)
            {
                auto withArch = info.sliceAfter("--with-arch");
                if (withArch is null)
                    break;
                info = withArch;
                withArch = withArch.until!isWhite;
                if (withArch.canFind("i686"))
                    archs.put(Arch.x86);
                // NOTE: not fully implemented
            }
        }
        else if (kind == CxxKind.dmc)
        { /* doesn't support extra arches as far as I know */ }
        else if (kind == CxxKind.msvc)
        { /* doesn't support extra arches as far as I know */ }
        else
            assert(0, "not impl");
        return archs.data;
    }
    private Arch[] getNonDefaultTargetArchs()
    {
        if (!cached.nonDefaultTargetArchsDetermined)
        {
            cached.nonDefaultTargetArchs = determineNonDefaultTargetArchs();
            cached.nonDefaultTargetArchsDetermined = true;
        }
        return cached.nonDefaultTargetArchs;
    }
    ArchSupport supports(Arch arch)
    {
        import std.algorithm : canFind;

        if (arch == getDefaultTargetArch())
            return ArchSupport.yesDefault;
        const nonDefaults = getNonDefaultTargetArchs();
        if (nonDefaults.canFind(arch))
            return ArchSupport.yesNotDefault;

        return ArchSupport.no;
    }
}
