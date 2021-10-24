/*
 * This file is part of moss-deps.
 *
 * Copyright © 2020-2021 Serpent OS Developers
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module moss.deps.analysis.bucket;

import std.container.rbtree;

import moss.core : FileType;
public import moss.deps.query.dependency;
public import moss.deps.analysis.fileinfo;

import std.algorithm : map, filter;
import std.range : take;

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
    alias HashTree = RedBlackTree!(string, "a < b", false);
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
    void add(ref FileInfo info)
    {
        if (info.type == FileType.Regular)
        {
            info.computeHash();
            uniqueHashes.insert(info.data);
        }
        files.insert(info);
    }

    /**
     * Add a dependency to this bucket.
     */
    void addDependency(ref Dependency d)
    {
        deps.insert(d);
    }

    /**
     * Return a set of unique files in hash order. For improved compression
     * implementations should resort by locality.
     */
    auto uniqueFiles()
    {
        return uniqueHashes[].map!((h) => {
            auto comparator = FileInfo.regularComparator(h);
            return files.equalRange(comparator).take(1).front;
        }());
    }

    /**
     * Return all files within this set
     */
    auto allFiles()
    {
        return files[];
    }

    /**
     * Return unique set of dependencies
     */
    auto dependencies()
    {
        return deps[];
    }

package:

    /**
     * Construct a new AnalysisBucket with the given name
     */
    this(in string name)
    {
        _name = name;
        deps = new DependencyTree();
        uniqueHashes = new HashTree();
        files = new FileTree();
    }

private:

    string _name = null;
    FileTree files;
    DependencyTree deps;
    HashTree uniqueHashes;
}
