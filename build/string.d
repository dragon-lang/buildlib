module build.string;

import std.string : indexOf;

inout(Char)[] firstLine(Char)(inout(Char)[] str)
{
    import std.string : stripRight;

    // THIS ISN'T WORKING, `.until` returns a type that stripRight doesn't understand
    return str.until("\n").stripRight("\r");
}

unittest
{
    assert("" == "".firstLine);
    assert("" == "\n".firstLine);
    assert("" == "\r\n".firstLine);
    assert("foo" == "foo".firstLine);
    assert("foo" == "foo\n".firstLine);
    assert("foo" == "foo\r\n".firstLine);
}

auto sliceInsideQuotes(inout(char)[] str)
{
    import std.exception : enforce;
    import std.string : indexOf;
    import std.format : format;

    auto firstQuote = str.indexOf(`"`);
    enforce(firstQuote >=0, format("string did not contain quotes '%s'", str));
    auto result = str[firstQuote + 1 .. $];
    auto secondQuote = result.indexOf(`"`);
    enforce(secondQuote >= 0, format("string did not end with quote '%s'", str));
    return result[0 .. secondQuote];
}

// Slice `str` after `needle`. Returns null if `needle` is not found.
inout(Char)[] sliceAfter(T, Char)(inout(Char)[] str, T needle)
{
    auto index = str.indexOf(needle);
    if (index < 0)
        return null;
    return str[index + needle.length .. $];
}

inout(Char)[] until(T, Char)(inout(Char)[] str, T needle) if (is(typeof(str.indexOf(needle))))
{
    auto index = str.indexOf(needle);
    if (index < 0)
        return str;
    return str[0 .. index];
}
inout(Char)[] until(alias Cond, Char)(inout(Char)[] str) if (is(typeof(Cond(str[0]))))
{
    foreach (i, c; str)
        if (Cond(c))
            return str[0 .. i];
    return str;
}
