# Polar and Doppler setup for the paid multi-account plan

Everything the code needs is already written. This file is the manual half: five
values that have to exist before the paywall does anything. Until they exist, the
app builds and runs with every account unlocked and no paywall anywhere, which is
also what a fork gets.

Do the sandbox pass first. Sandbox and production are two entirely separate Polar
accounts with separate logins, separate organizations, and separate ids. Nothing
carries over, and you will do every step twice.

## The one thing that will bite you

Mail Notifier is a product inside the existing **Strategic Nerds** organization,
alongside Sync Bar and whatever comes next. That is the right shape for a parent
company: one payout account, one tax setup, one dashboard, revenue in one place.

It has a consequence you have to design around. Polar's license-key endpoint
grants on **organization membership**, not on product. It takes a key and an
organization id, and any active key in that organization validates. Left alone,
a Sync Bar subscriber's key would unlock Mail Notifier.

The app defends against that by comparing the `benefit_id` on the validated key
against `POLAR_BENEFIT_ID`. In a shared organization that value is **required**,
not optional. Leave it empty and you give Mail Notifier away to every subscriber
of every sibling app. The app logs an error at launch if you ship a build that
sells subscriptions with no pin set.

Every app you add to this organization from now on needs its own benefit and its
own pin. That is the tax for sharing the org, and it is cheaper than running a
separate organization, payout account, and Polar review per app.

## Part 1: Polar sandbox

### 1.1 Sign in to the sandbox

1. Go to `https://sandbox.polar.sh`.
2. Sign in. The sandbox is a completely separate account from production, even
   with the same email.
3. The sandbox Strategic Nerds organization already exists and already holds
   **Sync Bar Twitter SANDBOX, $5.99**. Use it. Do not make a second one.

That sibling product is a gift for testing. It gives you a real license key from
a different product in the same organization, which is exactly the key that must
be rejected. Test 10 below is the one that proves the whole design.

### 1.2 Copy the organization id

1. Left sidebar, **Settings**.
2. **General** tab.
3. Find the organization **ID**. It is a UUID, something like
   `f0a1b2c3-4d5e-6f70-8192-a3b4c5d6e7f8`.
4. Copy it. This is `POLAR_ORG_ID`.

In production this is the id of your existing Strategic Nerds organization, which
means it is the **same value Sync Bar already uses**. That is expected and fine.
The benefit id is what separates the two apps, not the org id.

If Settings shows a slug but no UUID, open any product and read the
`organization_id` from its API view, or call
`https://sandbox-api.polar.sh/v1/organizations` with a personal access token. The
UUID is what the app sends; the slug will not work.

### 1.3 Create the product

1. Left sidebar, **Products**, then **New Product**.
2. Name: `Mail Notifier Pro SANDBOX` in the sandbox, `Mail Notifier Pro` in
   production. This shows on the checkout page and on the receipt. The SANDBOX
   suffix matches how Sync Bar's sandbox product is named, and it is the fastest
   way to tell at a glance which environment a screenshot came from.
3. Description: your call. It also shows at checkout.
4. Pricing:
   - Type: **Recurring**
   - Interval: **Yearly**
   - Pricing model: **Pay what you want**
   - Minimum: **0.99 USD**
   - Default / suggested (the number pre-filled at checkout): **5.99 USD**
5. Save.

Pay what you want works on recurring products in Polar, not only one-time ones,
so a yearly subscription at a customer-chosen price is a supported setup. The
amount a customer picks at checkout is the amount their renewal charges. The app
needs no code for any of this: a license key behaves the same whether someone paid
99 cents or 20 dollars.

Keep it to one price. When you add lifetime pricing later it becomes a second
product with a one-time price and its own checkout link; the entitlement code
already handles a key with no expiry, so that is a Polar change plus one more
button.

### 1.3a Read this before you leave the minimum at 99 cents

Polar's Starter plan takes **5% + 50 cents per transaction**. The fixed 50 cents
is what does the damage at a low price:

| Customer pays | Polar fee | You net | Fee share |
| --- | --- | --- | --- |
| $0.99 (the minimum) | $0.55 | **$0.44** | 55% |
| $5.99 (suggested) | $0.80 | **$5.19** | 13% |

An international card adds 1.5%. Payouts cost $2 per month of active payouts plus
0.25% + $0.25 each. A dispute costs $15, which is thirty-four $0.99 subscriptions.

Against a $700 CASA bill that is **135 subscribers at the suggested price, or
1,591 at the minimum**. The minimum is not wrong, and a low floor is a real
kindness to someone who genuinely cannot pay. Just set it knowing that a $0.99
subscriber is close to revenue-neutral after fees, so the suggested price is the
number actually funding the assessment. That is why $5.99 pre-filled matters more
than $0.99 being available.

### 1.4 Add the License Keys benefit

This is the part that matters. Without it, people can pay and get nothing.

1. Inside the product, find **Benefits**, then **Create new benefit**.
2. Type: **License Keys**.
3. Description: `Mail Notifier Pro license`. Customers see this.
4. Options:
   - **Limit activations**: **ON, set to 5**. The app registers one activation
     per Mac, so a subscriber gets five machines. Each is named in the customer
     portal by its computer name and can be released from Settings, which frees
     the slot. The one rough edge is a Mac that gets wiped or sold without
     removing the license first: that activation stays claimed until the person
     releases it from the portal by hand.
   - **Limit usage**: leave it **OFF**. Nothing here is metered.
   - **Expires after / TTL**: leave it **OFF**. Read the warning below before
     changing this.
5. Save, and make sure the benefit is attached to the product.

**Why no expiry.** With a TTL, the key carries an `expires_at` and the app stops
trusting it after that date. If Polar does not push that date forward when the
yearly subscription renews, every paying customer is locked out at month twelve
and you find out from the support email. I could not confirm from Polar's docs
which way that goes. With no TTL, the key has no expiry and Polar revokes it when
the subscription is cancelled or the payment fails, which the app reads on its next
check. That is the failure mode you want: it errs toward a paying customer keeping
access.

If you want to confirm the renewal behavior yourself, sandbox subscriptions can be
advanced from the Polar dashboard. Worth doing before you rely on a TTL.

### 1.5 Copy the benefit id

1. Open the benefit you just made.
2. Copy its **ID**, another UUID.
3. This is `POLAR_BENEFIT_ID`.

**Required.** This is the value that separates Mail Notifier from Sync Bar inside
the shared Strategic Nerds organization. Make sure it is the benefit belonging to
the Mail Notifier product, not Sync Bar's. Getting these two swapped produces the
most confusing possible bug: your own subscribers are rejected and the other app's
are accepted.

### 1.6 Copy the checkout link

1. Product page, **Share** or **Checkout link**.
2. Create a link if there is not one already.
3. Copy the URL. It looks like `https://buy.polar.sh/polar_cl_xxxxxxxx` or
   `https://sandbox.polar.sh/mail-notifier/...`.
4. This is `POLAR_CHECKOUT_URL`.

### 1.7 Copy the customer portal link

1. Settings, or the Customers section, has the customer portal URL. It looks like
   `https://polar.sh/mail-notifier/portal` (sandbox: under `sandbox.polar.sh`).
2. This is `POLAR_PORTAL_URL`.

Customers request a login link by email there. It is where they cancel, update a
card, see their key, and release a device.

### 1.8 Sandbox API base

`POLAR_API_BASE = https://sandbox-api.polar.sh`

Set this for the sandbox pass and clear it for production. Getting this wrong is
the single most likely mistake: a production org id against the sandbox API
returns "not found" for every key, and the app reports an invalid license.

## Part 2: Doppler

The build reads these from `Secrets.xcconfig`, which `scripts/pull-secrets.sh`
writes from Doppler. Nothing here is a secret, so a `dev` config is fine.

### 2.1 Unlock the CLI

`doppler` is installed but its keyring is locked on this machine. It fails with
"Unable to retrieve value from system keyring". Fix:

    doppler login

### 2.2 Create the project

    doppler projects create mail-notifier

That gives you `dev`, `stg`, and `prd` configs.

### 2.3 Set the values

Sandbox values into `dev`:

    doppler secrets set --project mail-notifier --config dev \
      POLAR_ORG_ID=<sandbox org uuid> \
      POLAR_BENEFIT_ID=<sandbox benefit uuid> \
      POLAR_CHECKOUT_URL=<sandbox checkout url> \
      POLAR_PORTAL_URL=<sandbox portal url> \
      POLAR_API_BASE=https://sandbox-api.polar.sh

The same project also needs the values the app already used, which are currently
living in a hand-written `Secrets.xcconfig` on your laptop:

    doppler secrets set --project mail-notifier --config dev \
      GOOGLE_CLIENT_ID=<...> \
      GOOGLE_CLIENT_SECRET=<...> \
      OUTLOOK_CLIENT_ID=<...> \
      POSTHOG_PUBLIC_KEY=<phc_...>

Note the name: `POSTHOG_PUBLIC_KEY` in Doppler becomes `POSTHOG_API_KEY` in the
build. `scripts/pull-secrets.sh` maps it. This exact mismatch cost sync-bar months
of analytics going nowhere.

### 2.4 Pull and build

    ./scripts/pull-secrets.sh dev
    xcodegen generate
    ./scripts/debug.sh

The script backs up any existing `Secrets.xcconfig` to `Secrets.xcconfig.bak`
before writing, and refuses to overwrite if Doppler returns nothing for the Google
or Outlook credentials.

## Part 3: Test it end to end

The Debug build carries the same bundle id as the copy in `/Applications`, so
both read the same UserDefaults and the same Keychain. There is no separate
profile to test against: the sandbox pass runs against your real accounts, and
the second and third of them go Locked the moment you launch a build with no
license. That is the feature working, and it is reversible, but mail stops being
checked for those accounts until you activate a key or restore.

`scripts/test-state.sh` handles the setup and teardown:

    ./scripts/test-state.sh backup          # do this first, once
    ./scripts/test-state.sh status          # accounts, entitlement, keychain, baked config
    ./scripts/test-state.sh accounts 1      # trim to one account for test 1
    ./scripts/test-state.sh restore         # put every account back
    ./scripts/test-state.sh clear-license   # forget the key, to re-run activation
    ./scripts/test-state.sh run             # launch the Debug build

Trimming accounts rewrites UserDefaults only, so OAuth tokens survive and
`restore` brings an account back intact. **Deleting an account through the app UI
is different**: it clears the account's Keychain entry, and getting it back costs
a full re-authorization. Do not use the UI to set up a test.

**Expect Keychain prompts.** The Debug build is signed `Apple Development` and
the shipped app is signed `Developer ID`. Same bundle id, same team, different
certificate, so macOS treats them as two different programs asking for the same
stored tokens and asks permission each time the other one has touched them. It
is not a sign anything is wrong. Click Always Allow; clicking Deny leaves that
account unable to read its token and costs a re-authorization.

With the sandbox build running:

1. **Free tier.** With one account configured, everything works and no paywall
   appears anywhere.
2. **The gate.** Sidebar, **Add**. Click Gmail or Outlook. The paywall sheet
   opens instead of the OAuth window.
3. **Checkout.** Click Subscribe. The browser opens the sandbox checkout. Pay with
   Stripe's test card `4242 4242 4242 4242`, any future expiry, any CVC.
4. **Activation.** Polar emails the license key. Paste it into the field the sheet
   left open and click Activate. The sheet should say the subscription is active.
5. **Unlock.** Close the sheet, add the second account for real. It should
   connect, appear in the sidebar without a Locked badge, and start checking mail.
6. **Lapse.** In the Polar sandbox dashboard, cancel the subscription or revoke the
   benefit. In the app, Settings, and either wait for the next check or quit and
   relaunch. The second account should show Locked, stop fetching, and stop
   notifying. Its settings and tokens should still be there.
7. **Grace.** Turn off wifi and relaunch. A subscriber must stay unlocked. This is
   the one that protects people on planes, and it is the easiest to break.
8. **Reactivate.** Resubscribe in the sandbox, hit Activate again, and confirm
   everything comes back without reconnecting any account.
9. **Free slot.** With no subscription and two accounts, open the locked one and
   click "Use this one instead". The two should swap: this one starts checking,
   the other goes Locked.
10. **The cross-app leak.** Buy **Sync Bar Twitter SANDBOX** in the sandbox, take
    the license key it emails you, and paste it into Mail Notifier's license
    field. It must be **rejected** with "That license key is for a different
    product." Both products live in the same organization, so Polar itself will
    happily say that key is valid; only `POLAR_BENEFIT_ID` stops it. If this test
    passes with the key accepted, your benefit id is wrong or empty, and every
    Sync Bar subscriber is getting Mail Notifier free.

    Then clear `POLAR_BENEFIT_ID`, rebuild, and try the Sync Bar key again. It
    should now be accepted, which is the leak you are defending against. Put the
    benefit id back. Doing it in both directions is the only way to know the pin
    is actually wired up rather than the key just happening to fail.
11. **Pay what you want.** At the sandbox checkout, confirm the amount field is
    editable, pre-filled with **$5.99**, and refuses anything under **$0.99**.
    Then buy at the $0.99 minimum and confirm the license key that arrives
    unlocks exactly as much as a $5.99 one does. It should: the app never sees
    the amount.
12. **Renewal amount.** In the sandbox dashboard, look at the subscription
    created by that $0.99 purchase and confirm its recurring amount is $0.99
    rather than $5.99. Polar should bill the chosen amount on renewal. Worth
    seeing with your own eyes before the first real renewal a year from now.
13. **The activation ceiling.** The benefit allows five devices. There is only
    one Mac here, so exhaust the limit from the Polar sandbox dashboard instead:
    activate the key, then add four more activations by hand until the key is at
    5 of 5. Remove the license in Mail Notifier's Settings and paste it again.
    It must be refused with **"This license is already active on the maximum
    number of devices. Remove it from one first."**

    This one is worth the trouble because the app detects it by *substring
    match* on Polar's error text (`PolarLicenseClient.checkStatus` looks for
    "activation" and "limit"), not by status code. If Polar words the message
    differently than expected, the test fails with the generic "Couldn't reach
    the subscription service (HTTP 403)" instead, and that tells you the match
    needs updating.

    Then confirm the release path: remove one activation in the portal and
    activate again. It should succeed.
14. **The comp discount.** Create the 100% forever discount from Part 3a in the
    sandbox and buy Mail Notifier Pro SANDBOX with it. Three things to watch, in
    order of how likely they are to go wrong:

    - The discount field accepts the code on a **pay-what-you-want** product at
      all. This is the unknown. If Polar rejects a percentage discount against a
      customer-chosen amount, stop and use the $0 comp product instead.
    - Checkout asks for **no card** and completes at $0.
    - The key that arrives **activates and unlocks**, exactly like a paid one.
      It carries the same `benefit_id`, so it should.

    Then look at the subscription in the dashboard and confirm the discount
    reads as applying forever rather than once. A "once" discount looks
    identical today and bills you in a year.

## Part 3a: A comp license for yourself

You run this app every day and should not pay yourself through Stripe to do it.
The route is a 100% forever discount, redeemed once against your own checkout.
It produces a real license key down the real code path, which is worth more than
a special case in the app would be.

The key never expires: the benefit has no TTL, so `expires_at` is nil and
`EntitlementManager.isEntitled` skips the date check entirely. Nothing renews
because nothing lapses. Polar only revokes on a cancelled subscription or a
failed payment, and a 100% forever subscription has no payment to fail.

No card is involved. Per Polar's discount docs: "Free products and 100% forever
subscriptions never ask for a card, so those match on ID and email alone."

### Creating it

1. Dashboard, **Discounts**, **New Discount**.
2. Name: `Owner comp`. The customer sees this at checkout, and the customer is
   you.
3. Code: something you will not type by accident. Not `COMP` or `FREE`.
4. Type: **Percentage**, **100%**.
5. Duration: **Forever**. "Once" would bill you at renewal a year later, which
   you would discover as a surprise charge.
6. **Restrictions: restrict it to Mail Notifier Pro.** Do not skip this. Polar's
   default is the opposite of what you want here: "By default the discount can
   be applied to all products, also ones created after the discount was
   created." In a shared organization that means one leaked code gives away Sync
   Bar, Mail Notifier, and every app you add later, forever, with no card. Pin it
   to the one product.
7. Max redemptions: **1**. Max per customer: **1**.

Then buy your own product with the code, and paste the key into the app like any
other customer.

### Audit the discounts that already exist

"Also ones created after the discount was created" cuts backwards too. Every
discount made in this organization before Mail Notifier Pro existed, including
Sync Bar's, silently began applying to Mail Notifier Pro the moment the product
was created. That is how the first attempt at this failed: an existing Sync Bar
code was set to All Products.

So adding a product to a shared Polar organization has a step nobody writes
down: **go through every existing discount and restrict it.** Do it in both
sandbox and production. Then do it again the next time an app joins the
organization, because the same defaulting will pull those codes onto that
product too.

This is a different hole from the benefit pin, and one does not cover the other.
The pin decides who is *entitled* once they hold a key. A loose discount decides
what they *pay* to get one. A code restricted to Sync Bar with the benefit pin
missing gives Mail Notifier away for free; a code set to All Products with the
pin correct sells Mail Notifier for nothing and hands over a perfectly valid key.

### The part to check in sandbox first

Mail Notifier Pro is priced pay-what-you-want, and Polar's docs do not say
whether a percentage discount applies to a customer-chosen amount. It may work,
it may be rejected at checkout, or the discount field may not appear at all.
Find out in sandbox where it costs nothing to be wrong.

If it does not work, the fallback is a second product: `Mail Notifier Pro (Comp)`
priced at a one-time $0, unlisted, with **the existing License Keys benefit
attached** rather than a new one. Benefits are organization-level in Polar and
attach to many products, so the key carries the same `benefit_id` and the app's
pin accepts it with no code change. That route also has no subscription at all,
so there is nothing to cancel.

## Part 4: Production

Repeat Part 1 at `https://polar.sh` inside your existing **Strategic Nerds**
organization, then:

1. No new payout account and no new Polar review: the organization is already
   live, which is the whole benefit of putting the apps in one place.
2. Sales tax and VAT stay Polar's problem, not yours. They are merchant of record,
   which is the main reason to use them over Stripe directly.
4. Put the production values in the Doppler `prd` config, with **`POLAR_API_BASE`
   empty**. Empty means the live API.
5. Build the release with `./scripts/pull-secrets.sh prd`.

Most of this is already done, since Strategic Nerds is an existing organization
with a working payout account. In production you are really only doing steps 1.3
through 1.7: the product, the benefit, and the two links.

## Values collected so far

A running record, so nothing has to be hunted twice. None of these are secret.

| What | Sandbox | Production |
| --- | --- | --- |
| Organization id | `e9c2e741-5aa8-42ad-b2e5-2cb942952273` | `94dde5cb-90d9-47ba-b51c-d453f5e785d1` |
| Product id | `b31e3864-5297-40f7-8d15-7c21c0b1e3fc` | `2497f1b6-36fb-4173-abae-d949845cec77` |
| Benefit id | `661eadf0-4c31-4d4c-8644-a446a08d4e28` | `e917cb15-3ae5-4518-9c1f-76c78130f11d` |

Production was created 3 August 2026 and is verified: the checkout page reports
`amount_type: custom`, `minimum_amount: 99`, `preset_amount: 599`,
`recurring_interval: year`, and a `license_keys` benefit named "Mail Notifier Pro
License Key" whose id matches the `prd` Doppler value. Both benefits cap
activations at 5.

Sandbox is verified the same way, against **Mail Notifier Pro SANDBOX**: the same
`custom` / `99` / `599` / `year` pricing and a `license_keys` benefit named "Mail
Notifier Pro License SANDBOX" whose id matches Doppler `mail-notifier/dev`.

One trap already sprung once: the sandbox `POLAR_CHECKOUT_URL` in Doppler was
Sync Bar's checkout link, copied byte for byte from `sync-bar/dev`. The paywall's
Subscribe button sold the wrong app and nothing in the build complained, because
a checkout link is just a URL to the app. If a checkout link ever looks wrong,
fetch it and read the `<title>`: it names the organization and the product.

The organization ids came from Sync Bar, which shares the Strategic Nerds
organization. `scripts/bootstrap-doppler.sh` already seeds both into Doppler, so
there is nothing to paste for those.

**The product id is not what the app needs.** Polar's license-key validate
response carries `benefit_id` and no product field, so the pin has to be a benefit
id. They are different UUIDs. To get the right one: open the product, open its
**License Keys** benefit, and copy the id from the benefit, not from the product
page.

The product id above is recorded because it is handy for building checkout links
and for finding things in the dashboard. The app never reads it.

**The organization id is per environment.** Sandbox and production are separate
Polar accounts with different organization UUIDs, which is why the table above has
two. They were read out of Sync Bar's Doppler project:

    doppler secrets get POLAR_ORG_ID --project sync-bar --config dev --plain   # sandbox
    doppler secrets get POLAR_ORG_ID --project sync-bar --config prd --plain   # production

Crossing them is the failure that reports every license as invalid, which is why
the bootstrap script seeds each config rather than leaving it to a copy and
paste.

## The five values, for reference

| Doppler name | Where it comes from | Empty means |
| --- | --- | --- |
| `POLAR_ORG_ID` | Settings, General, organization UUID. Same as Sync Bar's | No paywall, everything unlocked |
| `POLAR_BENEFIT_ID` | The Mail Notifier License Keys benefit's UUID | **Any Strategic Nerds key unlocks this app** |
| `POLAR_CHECKOUT_URL` | Product, Share | Subscribe button disabled |
| `POLAR_PORTAL_URL` | Customer portal link | Manage subscription link hidden |
| `POLAR_API_BASE` | `https://sandbox-api.polar.sh`, or empty | Live API |

None of them are secret. They ship inside the app bundle, the same way the OAuth
client ids do. No Polar access token exists anywhere in the app, because the three
endpoints it calls need no authentication.
