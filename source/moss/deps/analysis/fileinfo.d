/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.deps.analysis.fileinfo
 *
 * Captures and exposes various properties of analysed files.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module moss.deps.analysis.fileinfo;

import std.path : dirName, relativePath;
import std.array : join;
import std.file;
import moss.core : ChunkSize;
import core.sys.posix.sys.stat;
import std.string : toStringz, format;
import std.exception : enforce;

public import moss.core : FileType;
import xxhash : computeXXH3_128, XXH3_128;
import std.digest : LetterCase, Order, toHexString;

/**
 * We use mmap when beyond 16kib
 */
static enum MmapThreshhold = 16 * 1024;

/**
 * FileInfo collects essential information about each file in a package
 * to allow further proessing.
 */
public struct FileInfo
{

    /**
     * Construct a new FileInfo from the given paths
     */
    this(const(string) relativePath, const(string) fullPath)
    {
        auto z = fullPath.toStringz;
        stat_t tStat = {0};
        auto ret = lstat(z, &tStat);
        enforce(ret == 0, "FileInfo: unable to stat() %s".format(fullPath));

        this(relativePath, fullPath, tStat);

    }

    /**
     * Construct a new FileInfo using the given relative path, full path,
     * and populated stat result
     */
    this(const(string) relativePath, const(string) fullPath, in stat_t statResult)
    {
        this.statResult = statResult;
        _path = relativePath;
        _fullPath = fullPath;

        /**
         * Stat the file so we can set the appropriate file type
         */
        switch (statResult.st_mode & S_IFMT)
        {
        case S_IFBLK:
            _type = FileType.BlockDevice;
            break;
        case S_IFCHR:
            _type = FileType.CharacterDevice;
            break;
        case S_IFDIR:
            _type = FileType.Directory;
            break;
        case S_IFIFO:
            _type = FileType.Fifo;
            break;
        case S_IFLNK:
            _type = FileType.Symlink;
            _source = fullPath.readLink();
            break;
        case S_IFREG:
            _type = FileType.Regular;
            break;
        case S_IFSOCK:
            _type = FileType.Socket;
            break;
        default:
            _type = FileType.Unknown;
            break;
        }
    }

    /**
     * Restat the file due to underlying changes
     */
    public void update()
    {
        auto z = fullPath.toStringz;
        stat_t tStat = {0};
        auto ret = lstat(z, &tStat);
        enforce(ret == 0, "FileInfo.update(): unable to stat() %s".format(fullPath));

        statResult = tStat;
    }

    /**
     * Return the underlying file type
     */
    pure @property FileType type() const @safe @nogc nothrow
    {
        return _type;
    }

    /**
     * Return the *source* of a symlink type file
     */
    pure @property auto symlinkSource() @safe @nogc nothrow const
    {
        return _source;
    }

    /**
     * Return the xxh3_128 digest as bytes (regular files only)
     */
    pragma(inline, true) pure @property ubyte[16] digest() @safe @nogc nothrow const
    {
        return _digest;
    }

    /**
     * Return the xxh3_128 digest as a string
     */
    pragma(inline, true) pure @property char[32] digestString() @safe @nogc nothrow const
    {
        return toHexString!(LetterCase.lower, Order.increasing, 16)(_digest);
    }

    /**
     * Return true if this is a relative symlink
     */
    pure @property bool relativeSymlink() const @safe
    {
        import std.string : startsWith;

        return !_source.startsWith("/");
    }

    /**
     * Return the fully resolved symlink
     */
    pure @property const(string) symlinkResolved() const @safe
    {
        import std.exception : enforce;

        enforce(type == FileType.Symlink, "FileInfo.symlinkResolved() only supported for symlinks");

        auto dirn = path.dirName;
        return join([dirn, _source.relativePath(dirn)], "/");
    }

    /**
     * Return the target filesystem path
     */
    pure @property const(string) path() const @safe @nogc nothrow
    {
        return _path;
    }

    /**
     * Return the full path to the file on the host disk
     */
    pure @property const(string) fullPath() const @safe @nogc nothrow
    {
        return _fullPath;
    }

    /**
     * Return the target for this file
     */
    pure @property const(string) target() const @safe @nogc nothrow
    {
        return _target;
    }

    /**
     * Set the target for this analysis
     */
    pure @property void target(const(string) t) @safe @nogc nothrow
    {
        _target = t;
    }

    /**
     * Return underlying stat buffer
     */
    pure @property stat_t stat() const @safe @nogc nothrow
    {
        return statResult;
    }

    /**
     * Return the bitsize
     */
    pure @property ushort bitSize() @safe @nogc nothrow const
    {
        return _bitSize;
    }

    /**
     * Update the bitsize
     */
    pure @property void bitSize(ushort bitSize) @safe @nogc nothrow
    {
        _bitSize = bitSize;
    }

    /**
     * Return buildID for a regular file
     */
    pure @property string buildID() @safe @nogc nothrow const
    {
        return _buildID;
    }

    /**
     * Update buildID for a regular file
     */
    pure @property void buildID(in string buildID) @safe @nogc nothrow
    {
        _buildID = buildID;
    }

    /**
     * Compute hash sum for this file
     */
    void computeHash(XXH3_128 helper)
    {
        /* Use mmap if the file is larger than 16kib */
        _digest = computeXXH3_128(helper, _fullPath, ChunkSize,
                !(statResult.st_size < MmapThreshhold)).dup;
    }

    /**
     * Return true if both FileInfos are equal
     */
    bool opEquals()(auto ref const FileInfo other) const
    {
        if (this.type == other.type)
        {
            if (this.type == FileType.Regular || this.type == FileType.Symlink)
            {
                return this._source == other._source;
            }
            return this.statResult == other.statResult;
        }
        return false;
    }

    /**
     * Compare two FileInfos with the same type
     */
    int opCmp(ref const FileInfo other) const
    {
        if (this.type == other.type)
        {
            if (this.type == FileType.Regular || this.type == FileType.Symlink)
            {
                immutable auto dA = this._source;
                immutable auto dB = other._source;
                if (dA < dB)
                {
                    return -1;
                }
                else if (dA > dB)
                {
                    return 1;
                }
                return 0;
            }
        }
        immutable auto pA = this._path;
        immutable auto pB = this._path;
        if (pA < pB)
        {
            return -1;
        }
        else if (pA > pB)
        {
            return 1;
        }
        return 0;
    }

    /**
     * Return the hash code for the path
     */
    ulong toHash() @safe nothrow const
    {
        return typeid(string).getHash(&_path);
    }

package:

    /**
     * Return a regular file comparison struct
     */
    static FileInfo regularComparator(in string hash)
    {
        auto f = FileInfo();
        f._source = hash;
        f._type = FileType.Regular;
        return f;
    }

private:

    FileType _type = FileType.Unknown;
    string _source = null;
    string _path = null;
    string _fullPath = null;
    string _target = null;
    stat_t statResult;
    ubyte[16] _digest = 0;
    ushort _bitSize = 0;
    string _buildID = null;
}
