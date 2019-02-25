module build.proc;

import std.typecons : Flag, Yes, No;
import build.log;

/**
Add additional make-like assignments to the environment
e.g. ./build.d ARGS=foo -> sets the "ARGS" internal environment variable to "foo"

Params:
    args = the command-line arguments from which the assignments will be parsed
*/
void takeEnvArgs(string[]* args)
{
    import std.algorithm : canFind, splitter, filter;
    import std.range : dropOne, array;
    import std.process : environment;

    bool tryToAdd(string arg)
    {
        if (!arg.canFind("="))
            return false;

        auto sp = arg.splitter("=");
        auto key = sp.front;
        auto value = sp.dropOne.front;
        verbosef("environment[\"%s\"] = \"%s\"", key, value);
        environment[key] = value;
        return true;
    }
    *args = (*args).filter!(a => !tryToAdd(a)).array;
}

string tryWhich(string program)
{
    import std.algorithm : findAmong, splitter;
    import std.string : split;
    import std.process : environment;
    import std.path : pathSeparator, buildPath, extension;
    import build.file : getFileAttributes;
    import build.path : dirSeparators;

    if (findAmong(program, dirSeparators).length)
        return program;

    // TODO: support current directory with no path separators?
    if (false)
    {
        if (getFileAttributes(program).isFile)
            return program;
    }

    string[] extensions = [""];
    version(Windows)
    {
        // TODO: add a test that verifies this works correctly on windows
        if (program.extension is null)
        {
            extensions ~= environment["PATHEXT"].split(pathSeparator);
            // TODO: remove duplicate entries in extensions
        }
    }

    foreach (envPath; environment["PATH"].splitter(pathSeparator))
    {
        foreach (ext; extensions)
        {
            string combinedPath = buildPath(envPath, program ~ ext);
            if (getFileAttributes(combinedPath).isFile)
                return combinedPath;
        }
    }
    return null;
}

// TODO: should probably inherit from another exception
class WhichException : Exception
{
    this(string program)
    {
        import std.format : format;
        super(format("program '%s' was not found in PATH", program));
    }
}

string which(string program)
{
    auto result = tryWhich(program);
    if (result is null)
        throw new WhichException(program);
    return result;
}

// TODO: should probably inherit from another exception
class ProcessFailedException : Exception
{
    this(const(char)[] process, int exitCode, string output)
    {
        import std.format : format;
        if (output.length == 0)
            super(format("last command '%s' exited with code %s", process, exitCode), null, 0);
        else
            super(format("last command '%s' exited with code %s and with this output: %s", process, exitCode, output), null, 0);
    }
}


/**
Print and run the given command, capture output, wait for it to exit and return output and exit code.
*/
auto tryExecute(T...)(scope const(char[])[] args, T extra)
{
    import std.typecons : Tuple;
    static import std.process;

    verbosef("[EXECUTE] %s", std.process.escapeShellCommand(args));
    try
    {
        return std.process.execute(args, extra);
    }
    catch (std.process.ProcessException e)
    {
        return Tuple!(int, "status", string, "output")(-1, e.msg);
    }
}
/**
Print and run the given command, capture output, wait for it to exit,  and return output and exit code.
*/
auto execute(T...)(scope const(char[])[] args, T extra)
{
    import build.error : fatal;

    const result = tryExecute(args, extra);
    if (result.status != 0)
        throw new ProcessFailedException(args[0], result.status, result.output);
    return result.output;
}

/**
Print and run the given command, don't capture output, wait for it to exit and return the exit code.
*/
int tryRun(T...)(scope const(char[])[] args, T extra)
{
    import std.stdio : writeln, writefln, stdout;
    import std.process : escapeShellCommand, spawnProcess, wait;

    writefln("[RUN] %s", escapeShellCommand(args));
    writeln("--------------------------------------------------------------------------------");
    stdout.flush();
    auto proc = spawnProcess(args, extra);
    const result = wait(proc);
    writeln("--------------------------------------------------------------------------------");
    stdout.flush();
    return result;
}

/**
Print and run the given command, don't capture output, wait for it to exit, throw exception on non-zero exit code.
*/
void run(T...)(scope const(char[])[] args, T extra)
{
    import core.stdc.stdlib : exit;
    import std.stdio : writefln;

    const result = tryRun(args);
    if (result != 0)
        throw new ProcessFailedException(args[0], result, null);
}


// Does not return
pragma(inline)
void execv(T...)(T args) { return execImpl!(No.findProg)(args); }
pragma(inline)
void execvp(T...)(T args) { return execImpl!(Yes.findProg)(args); }

// Does not return
private void execImpl(Flag!"findProg" findProg, T...)(T args)
{
    import core.stdc.stdlib : exit;
    static import std.process;

    verbosef("[EXECVP] %s", std.process.escapeShellCommand(args));
    version (Windows)
    {
        // Windows doesn't have exec, fall back to spawnProcess then wait
        // NOTE: I think windows may have a way to do exec, look into this more
        auto pid = spawnProcess(args);
        exit(pid.wait());
    }
    else
    {
        import std.process : execv;
        auto argv = runCommand.map!toStringz.chain(null.only).array;
        static if (findProg)
        {
            execvp(argv[0], argv.ptr); // should never return
            errorf("execvp of '%s' failed (e=%s)", argv[0], errno);
        }
        else
        {
            execv(argv[0], argv.ptr); // should never return
            errorf("execv of '%s' failed (e=%s)", argv[0], errno);
        }
        exit(1);
    }
}