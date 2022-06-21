/* SPDX-License-Identifier: Zlib */

/**
 * moss.deps.registry.manager
 *
 * Defines an encapsulation of "query plugins", including an interface
 * for managing and using them.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.deps.registry.manager;

public import moss.deps.registry.plugin;
public import moss.deps.registry.transaction;

import std.algorithm : each, filter, joiner, map;

/**
 * Encapsulation of multiple underlying "query plugins"
 */
public final class RegistryManager
{
    /**
     * Add a plugin to the RegistryManager
     */
    void addPlugin(RegistryPlugin plugin)
    {
        plugins ~= plugin;
    }

    /**
     * Remove an existing plugin from this manager
     */
    void removePlugin(RegistryPlugin plugin)
    {
        import std.algorithm : remove;

        plugins = plugins.remove!((s) => s == plugin);
    }

    /**
     * Return all PackageCandidates by provider
     */
    auto byProvider(in ProviderType type, const(string) provider, ItemFlags flags = ItemFlags.None)
    {
        return plugins.map!((s) => s.queryProviders(type, provider, flags)).joiner;
    }

    /**
     * Return all PackageCandidates by Name
     */
    pragma(inline, true) auto byName(const(string) pkgName, ItemFlags flags = ItemFlags.None)
    {
        return byProvider(ProviderType.PackageName, pkgName, flags);
    }

    /**
     * Return all package candidates matching the given ID
     */
    pragma(inline, true) auto byID(const(string) pkgID)
    {
        return plugins.map!((s) => s.queryID(pkgID))
            .filter!((r) => !r.isNull())
            .map!((r) => RegistryItem(r.get.pkgID, r.get.plugin));
    }

    /**
     * List all items matching the given flags
     */
    pragma(inline, true) auto list(ItemFlags flags)
    {
        return plugins.map!((s) => s.list(flags)).joiner;
    }

    /**
     * List only installed candidates.
     * These are separate from the available candidates.
     */
    pragma(inline, true) auto listInstalled(ItemFlags flags = ItemFlags.None)
    {
        return list((flags &= ~ItemFlags.Installed) | ItemFlags.Installed);
    }

    /**
     * List only *available* candidates.
     * These are separate from the installed candidates.
     */

    pragma(inline, true) auto listAvailable(ItemFlags flags = ItemFlags.None)
    {
        return list((flags &= ~ItemFlags.Available) | ItemFlags.Available);
    }

    /**
     * Create a new transaction
     */
    Transaction transaction()
    {
        return new Transaction(this);
    }

    /**
     * Remove all plugins and invoke their close method
     */
    void close()
    {
        foreach (p; plugins)
        {
            p.close();
            p.destroy();
        }
        plugins = null;
    }

private:

    RegistryPlugin[] plugins;
}
