/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.deps.analysis.bucket
 *
 * Define the concept of an AnalysisBucket, into which files are sorted
 * based on rules that define subpackages such as documentation and
 * development headers and libraries.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module moss.deps.analysis.bucket;

import std.container.rbtree;

import moss.core : FileType;
public import moss.deps.dependency;
public import moss.deps.analysis.fileinfo;

import std.algorithm : map, filter;
import std.range : take;

import xxhash : XXH3_128;

/**
 * An AnalysisBucket is created for each subpackage so we know ahead of time
 * which files go where.
 */
public final class AnalysisBucket
{
    /**
     * Store dependencies in unique tree
     */
    alias DependencyTree = RedBlackTree!(Dependency, "a < b", false);
    alias ProviderTree = RedBlackTree!(Provider, "a < b", false);
    alias HashTree = RedBlackTree!(ubyte[16], "a < b", false);
    alias FileTree = RedBlackTree!(FileInfo, "a < b", true);

    @disable this();

    /**
     * Return the bucket name
     */
    pure @property const(string) name() @safe @nogc nothrow
    {
        return _name;
    }

    /**
     * Add this FileInfo to our own
     */
    void add(ref FileInfo info, XXH3_128 hashHelper)
    {
        if (info.type == FileType.Regular)
        {
            info.computeHash(hashHelper);
            synchronized (uniqueHashes)
            {
                uniqueHashes.insert(info.digest);
            }
        }

        synchronized (files)
        {
            files.insert(info);
        }
    }

    /**
     * Add a dependency to this bucket.
     */
    void addDependency(ref Dependency d)
    {
        synchronized (deps)
        {
            deps.insert(d);
        }
    }

    /**
     * Add a provider to this bucket
     */
    void addProvider(ref Provider p)
    {
        synchronized (provs)
        {
            provs.insert(p);
        }
    }

    /**
     * Return a set of unique files in hash order. For improved compression
     * implementations should resort by locality.
     */
    auto uniqueFiles() @safe
    {
        /* This needs optimising at a future date, but equalRange isn't working properly
         * for our FileInfo just yet.
         */
        return uniqueHashes[].map!((h) => files[].filter!((f) => f.type == FileType.Regular
                && f.digest == h).front);
    }

    /**
     * Return all files within this set
     */
    auto allFiles() @safe @nogc nothrow
    {
        return files[];
    }

    /**
     * Return unique set of dependencies
     */
    auto dependencies() @safe nothrow
    {
        import std.algorithm : canFind;

        return deps[].filter!((d) => !provs[].canFind!((p) => p.type == d.type
                && p.target == d.target));
    }

    /**
     * Return unique set of providers
     */
    auto providers() @safe @nogc nothrow
    {
        return provs[];
    }

    /**
     * Returns true if this bucket is empty
     */
    pure bool empty() @safe @nogc nothrow
    {
        return files.length() == 0;
    }

package:

    /**
     * Construct a new AnalysisBucket with the given name
     */
    this(in string name)
    {
        _name = name;
        deps = new DependencyTree();
        provs = new ProviderTree();
        uniqueHashes = new HashTree();
        files = new FileTree();
    }

private:

    string _name = null;
    FileTree files;
    DependencyTree deps;
    ProviderTree provs;
    HashTree uniqueHashes;
}
