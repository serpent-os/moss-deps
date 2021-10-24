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

module moss.deps.analysis.chain;

public import moss.deps.analysis.analyser : Analyser;
public import moss.deps.analysis.fileinfo : FileInfo;

/**
 * Chains can force the control flow depending on their return status
 */
enum AnalysisReturn
{
    /**
     * Pass this file onto the next handler. We're uninterested in it
     */
    NextHandler = 0,

    /**
     * Move to the next function in this chain.
     */
    NextFunction,

    /**
     * Ignore this file, nobody will want it
     */
    IgnoreFile,

    /**
     * End chain execution, include the file
     */
    IncludeFile,
}

/**
 * An analysis function may use the incoming FileInfo to discover further
 * details about it.
 */
alias AnalysisFunc = AnalysisReturn function(scope Analyser analyser, in FileInfo fi);

/**
 * An AnalysisChain is simply a named set of handlers which control the flow
 * for analysis evaluation.
 */
public struct AnalysisChain
{
    /**
     * Name of the handler
     */
    const(string) name;

    /**
     * Set of functions to control flow
     */
    AnalysisFunc[] funcs;

    /**
     * Higher priority always runs first
     */
    ulong priority = 0;
}

/**
 * End a chain by dropping a file
 */
public pure AnalysisReturn dropFile(scope Analyser analyser, in FileInfo fileInfo)
{
    return AnalysisReturn.IgnoreFile;
}

/**
 * End a chain with including a file
 */
public pure AnalysisReturn includeFile(scope Analyser analyser, in FileInfo fileInfo)
{
    return AnalysisReturn.IncludeFile;
}
