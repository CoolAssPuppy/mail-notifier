//
//  PaywallCopy.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  EVERY user-facing word about money lives here. The paywall sheet, the locked
//  account banner, the sidebar badge, and the Settings subscription card all
//  read their text from this file and hold none of their own. Rewriting the
//  pitch means editing this file and nothing else.
//
//  Keep it short. The whole pitch is a title, two paragraphs, and a button.
//

import Foundation

enum PaywallCopy {

    // MARK: Name and price

    /// What the paid plan is called, matching the product name in Polar.
    static let planName = "Mail Notifier Pro"

    /// The floor Polar enforces at checkout. Nobody can pay less than this.
    static let priceMinimum = "$1.99"

    static let subscribeButton = "Get \(planName)"

    // MARK: Paywall sheet

    static let sheetTitle = planName

    static let sheetSubtitle =
        "Your first email account is free. After that, I need to charge to unlock multiple email accounts."

    static let whyPayTitle = "Why?"

    static let whyPayBody = """
        Because Google sucks and is not a developer-friendly company. They make \
        individual developers submit for annual bogus certification run by \
        third-parties. In order to recoup their fee, I have to charge a minimal \
        amount per year. Don't hate the player, hate the game. In this case, \
        Google and all of greedy BigTech.
        """

    static let namePriceTitle = "Name your price"

    static let namePriceBody = """
        I get that not everyone can afford to pay. Student? Live in a different \
        part of the world? All good. Just pay \(priceMinimum). If you can pay \
        more, please do.
        """

    /// Shown in place of the subscribe controls once the person has paid.
    static let activeNote = "\(planName) is active. Every account is unlocked."

    /// The collapsed link that reveals the license paste field. Folded away
    /// because it is for the few people who already paid.
    static let hasKeyPrompt = "Already have a license key?"

    static let keyFieldPlaceholder = "Paste your license key"

    /// People look for the key in the app first, so say where it went.
    static let keyLocationHint = "Polar emails your key when you subscribe."

    // MARK: Locked accounts

    /// The sidebar badge on an account the subscription is holding back.
    static let lockedBadge = "Locked"

    static let lockedBannerTitle = "This account is paused"

    static let lockedBannerBody = "You get one account for free. Subscribe to check this one too."

    /// The escape hatch for someone who doesn't want to pay but picked the wrong
    /// account to keep. Without this, whichever account was added first wins
    /// forever, which is the wrong one often enough to matter.
    static let makeFreeButton = "Use this one instead"

    static let makeFreeDescription = "Makes this your free account and pauses the other one."

    /// The classic menu row for a locked account, where there is no room for a
    /// banner.
    static let lockedMenuItem = "Locked, subscribe to check this account"

    // MARK: Settings card

    static let settingsCardTitle = "Subscription"

    static let settingsFreeState = "Free. One account."

    static let settingsFreeDescription = "Subscribe to add more, for a price you name."

    static let settingsActiveState = planName

    static let settingsLapsedState = "\(planName) is inactive"

    static let settingsLapsedDescription = "Your extra accounts are paused. Renew to turn them back on."

    static let manageButton = "Manage subscription"

    static let removeLicenseButton = "Remove from this Mac"

    static let removeLicenseDescription = "Frees up this Mac. Your subscription keeps working everywhere else."

    // MARK: Unconfigured build

    /// Shown when no Polar organization is configured, which is what a fork or a
    /// local dev build looks like. Saying so beats a button that does nothing.
    static let notConfiguredNote = "Subscriptions aren't set up in this build. Every account is unlocked."
}

/// What asked for the paywall. The sheet reads the same either way; this exists
/// so the telemetry can tell which entry point converts.
enum PaywallTrigger: String, Identifiable {
    /// The person tried to connect a second inbox.
    case addAccount = "add_account"
    /// The person clicked an account that the subscription has paused.
    case lockedAccount = "locked_account"

    var id: String { rawValue }
}
