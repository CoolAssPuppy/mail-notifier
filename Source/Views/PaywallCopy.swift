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
//  The draft below is a first pass and is meant to be replaced. Its argument:
//  reading Gmail requires a restricted OAuth scope, Google requires every app
//  using one to pass an independent security assessment (CASA) every year, and
//  that bill falls on one person. Check the specifics against your own invoices
//  before shipping, and don't put a dollar figure in here unless it's one you
//  can point at.
//

import Foundation

enum PaywallCopy {

    // MARK: Name and price

    /// What the paid plan is called, matching the product name in Polar. Used
    /// wherever a product name belongs; the pitch paragraphs stay in plain
    /// language and don't name it.
    static let planName = "Mail Notifier Pro"

    /// The floor Polar enforces at checkout. Nobody can pay less than this.
    static let priceMinimum = "$0.99"

    /// What the checkout field is pre-filled with. Most people accept a default,
    /// so this number is the one that actually sets revenue.
    static let priceSuggested = "$5.99"

    /// Short form, for buttons and one-line status rows where a number won't fit.
    static let priceLabel = "pay what you want"

    /// Long form, wherever there is room for the actual numbers.
    static let priceDetail = "Pay what you want, from \(priceMinimum) a year. \(priceSuggested) is suggested."

    /// Button text for the checkout. Says what it costs on purpose: a button
    /// that opens a payment page should never be coy about money.
    static let subscribeButton = "Get \(planName) (\(priceLabel))"

    // MARK: Paywall sheet

    static let sheetTitle = "One inbox is free. \(planName) watches the rest, and you pick the price."

    static let sheetSubtitle = "You're adding a second account."

    /// Why the app costs money. This is the paragraph to make your own.
    static let whyItCosts = """
        Mail Notifier watches your Gmail, and Google classes that as a restricted \
        permission. Every app that asks for one has to pass an independent \
        security assessment, called CASA, and repeat it every year. An outside \
        lab does the assessment and sends the bill to the developer. In this \
        case it's just me.

        The subscription covers that assessment, the Apple developer program, and \
        the signing and notarization that let you install the app without \
        arguing with Gatekeeper.
        """

    // MARK: Why charge

    /// The disclosure link that reveals the longer answer.
    static let whyChargeLabel = "Why charge?"

    /// The unvarnished version, in the maker's voice, folded away behind the
    /// link. The short paragraph above stays visible because it's the one that
    /// answers the question; this is the one that says how it feels.
    static let whyChargeBody = """
        Google is a terrible company. This should be easy, but it is not. I \
        apologize for having to charge you for this, but $700 is good money.
        """

    /// Where to send the complaint. LEFT EMPTY DELIBERATELY: I won't ship a
    /// guessed address for a real person. Fill it in with one you have actually
    /// confirmed, and the sentence below appears. While it's empty, the link
    /// shows `whyChargeBody` alone and nothing is fabricated.
    static let googleCEOEmail = ""

    /// The call to action, only when there's a real address to point at.
    static var whyChargeAction: String? {
        guard !googleCEOEmail.isEmpty else { return nil }
        return "You can email Google's CEO at \(googleCEOEmail) and tell him how stupid Google is."
    }

    /// The plain terms, under the pitch. Kept short and factual.
    static let terms = """
        One account is free forever, with every feature. \(planName) unlocks every \
        additional account on every Mac you own, for whatever you decide it's \
        worth, from \(priceMinimum) a year. Whatever you pick is what it renews at. \
        Cancel any time from the customer portal; your accounts stay configured \
        and the first one keeps running.
        """

    /// Shown in place of the subscribe controls once the person has paid.
    static let activeNote = "\(planName) is active. Every account is unlocked."

    /// The collapsed link that reveals the license paste field.
    static let hasKeyPrompt = "Already have a license key?"

    static let keyFieldPlaceholder = "Paste your license key"

    /// After checkout, Polar emails the key. People will look for it in the app
    /// first, so say where it went.
    static let keyLocationHint = "Polar emails your license key the moment you subscribe. Paste it here."

    // MARK: Locked accounts

    /// The sidebar badge on an account the subscription is holding back.
    static let lockedBadge = "Locked"

    static let lockedBannerTitle = "This account is paused"

    static let lockedBannerBody = """
        Mail Notifier checks one account for free, and this one is past that. \
        It isn't being checked and won't send notifications. Nothing has been \
        deleted: subscribe and it picks up where it left off.
        """

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

    static let settingsFreeState = "Free plan. One account."

    static let settingsFreeDescription = "\(planName) adds more accounts. \(priceDetail)"

    static let settingsActiveState = planName

    static let settingsLapsedState = "\(planName) is inactive"

    static let settingsLapsedDescription = "Accounts past the first are paused. Renew to bring them back."

    static let manageButton = "Manage subscription"

    static let removeLicenseButton = "Remove from this Mac"

    static let removeLicenseDescription = "Frees this Mac's activation. The subscription itself is unaffected."

    // MARK: Unconfigured build

    /// Shown when no Polar organization is configured, which is what a fork or a
    /// local dev build looks like. Saying so beats a button that does nothing.
    static let notConfiguredNote = "Subscriptions aren't set up in this build. Every account is unlocked."
}

/// What asked for the paywall. Only the subtitle changes, but the two entry
/// points read differently enough to be worth distinguishing, and the telemetry
/// wants to know which one converts.
enum PaywallTrigger: String, Identifiable {
    /// The person tried to connect a second inbox.
    case addAccount = "add_account"
    /// The person clicked an account that the subscription has paused.
    case lockedAccount = "locked_account"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .addAccount: return PaywallCopy.sheetSubtitle
        case .lockedAccount: return PaywallCopy.lockedBannerTitle
        }
    }
}
