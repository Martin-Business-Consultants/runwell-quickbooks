# QuickBooks for Runwell

Clients linked to QuickBooks customers, recurring invoices kept in step with services, and fixed-price work invoiced from its panel.

What a piece of work costs is set on its QuickBooks tab (or with `set_quickbooks_price`): a
fixed-price total, or a service's amount per period and how often. It's kept here, apart from
agreements, so a price written into an agreement is just words there. Upgrading from 0.1 to 0.2
starts each price from what the work's approved agreements came to.

Its pages and panels are drawn with runeui, Runwell 6.0's UI kit (`ui :card`, `ui :alert`,
`ui :button`, `form.ui :field`…, and the core's helpers such as `record_card` and `status_tag`),
and its stylesheet (`app/assets/stylesheets/quickbooks/quickbooks.css`) reads runeui's tokens only
(shadcn's names, `--muted-foreground`, `--border`, `--primary` for the brand…, and runeui's `--ui-*`
scale; Runwell's `docs/theming.md`), never rune_ui's old names.

A plugin for [Runwell](https://github.com/Martin-Business-Consultants/runwellv2), the core of
project management. It owns its tables (`quickbooks_*`), points at core records by id, and
extends Runwell only through its plugin hooks, so removing it leaves Runwell as it was.

## Install

In Runwell, **Settings > Plugins > Add a plugin**: press Install on QuickBooks, or enter
`Martin-Business-Consultants/runwell-quickbooks`. Runwell downloads the latest release onto the server, restarts and creates the
plugin's tables. It starts off: switch it on in Settings > Plugins.

From the command line on the server: `bin/rails "plugins:install[Martin-Business-Consultants/runwell-quickbooks]"`, then restart
Runwell.

Needs Runwell 6.0.0 or later (0.2.0 is the version for Runwell 3.x and 4.x, 0.1.1 for 2.x). A plugin can use only the gems Runwell bundles.

## Updating

Settings > Plugins shows an Update button on the plugin when a newer release is out (it checks
nightly, or with Check for updates). The plugin updates only when someone presses it; if the new
release won't load, the previous one comes back.

## Developing

Clone this repository beside a Runwell checkout and link it in, from Runwell's directory:

```sh
bin/rails "plugins:link[../runwell-quickbooks]"
bin/rails db:migrate
bin/dev
```

## Releasing

Bump `VERSION` in `lib/quickbooks/version.rb`, commit, then tag and publish a GitHub release:

```sh
git tag v0.3.0 && git push origin main v0.3.0
gh release create v0.3.0 --generate-notes
```

Installs see it in Settings > Plugins.

## License

[FSL-1.1-MIT](LICENSE.md), like Runwell.
