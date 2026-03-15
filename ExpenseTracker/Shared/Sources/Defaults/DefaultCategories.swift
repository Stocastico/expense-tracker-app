import Foundation

/// Provides the built-in default categories for the expense tracker,
/// including keyword mappings for auto-categorization of transactions.
public enum DefaultCategories {

    // MARK: - Expense Categories

    public static let foodAndDining = Category(
        id: "food-dining",
        name: "Food & Dining",
        icon: "\u{1F37D}\u{FE0F}",
        color: "#FF6B6B",
        type: .expense,
        keywords: [
            "restaurant", "cafe", "coffee", "starbucks", "mcdonalds", "mcdonald's",
            "burger king", "subway", "pizza", "sushi", "thai", "chinese food",
            "doordash", "grubhub", "uber eats", "ubereats", "deliveroo",
            "just eat", "takeaway", "takeout", "diner", "bistro", "bar",
            "pub", "kfc", "wendy's", "taco bell", "chipotle", "panera",
            "dunkin", "tim hortons", "pret", "nando's", "five guys",
            "domino's", "papa john's", "wolt"
        ]
    )

    public static let groceries = Category(
        id: "groceries",
        name: "Groceries",
        icon: "\u{1F6D2}",
        color: "#51CF66",
        type: .expense,
        keywords: [
            "grocery", "supermarket", "walmart", "target", "costco",
            "whole foods", "trader joe's", "aldi", "lidl", "kroger",
            "safeway", "publix", "wegmans", "sprouts", "heb", "h-e-b",
            "meijer", "food lion", "piggly wiggly", "albert heijn",
            "carrefour", "tesco", "sainsbury", "asda", "waitrose",
            "marks & spencer food", "rewe", "edeka", "penny", "netto",
            "mercadona", "esselunga", "coop", "migros", "spar"
        ]
    )

    public static let transport = Category(
        id: "transport",
        name: "Transport",
        icon: "\u{1F697}",
        color: "#339AF0",
        type: .expense,
        keywords: [
            "uber", "lyft", "taxi", "cab", "gas", "fuel", "petrol",
            "shell", "bp", "exxon", "chevron", "parking", "toll",
            "transit", "metro", "subway", "bus", "train", "railway",
            "amtrak", "greyhound", "bolt", "grab", "gojek", "ola",
            "car wash", "car repair", "mechanic", "auto", "vehicle",
            "tire", "oil change", "registration", "dmv", "tfl",
            "deutsche bahn", "sncf", "renfe", "trenitalia", "flixbus"
        ]
    )

    public static let housing = Category(
        id: "housing",
        name: "Housing",
        icon: "\u{1F3E0}",
        color: "#845EF7",
        type: .expense,
        keywords: [
            "rent", "mortgage", "property tax", "hoa", "home insurance",
            "home repair", "plumber", "electrician", "contractor",
            "furniture", "ikea", "home depot", "lowe's", "ace hardware",
            "wayfair", "pottery barn", "west elm", "crate & barrel",
            "real estate", "landlord", "lease", "apartment"
        ]
    )

    public static let utilities = Category(
        id: "utilities",
        name: "Utilities",
        icon: "\u{26A1}",
        color: "#FCC419",
        type: .expense,
        keywords: [
            "electric", "electricity", "water", "gas bill", "internet",
            "wifi", "broadband", "comcast", "at&t", "verizon",
            "t-mobile", "sprint", "vodafone", "o2", "ee", "three",
            "phone bill", "mobile plan", "cable", "sewage", "trash",
            "waste", "utility", "heating", "cooling", "solar"
        ]
    )

    public static let healthcare = Category(
        id: "healthcare",
        name: "Healthcare",
        icon: "\u{1F3E5}",
        color: "#FF922B",
        type: .expense,
        keywords: [
            "doctor", "hospital", "clinic", "pharmacy", "cvs",
            "walgreens", "rite aid", "medical", "dental", "dentist",
            "optometrist", "eye doctor", "therapist", "therapy",
            "prescription", "medicine", "health insurance", "copay",
            "lab", "x-ray", "surgery", "urgent care", "emergency",
            "mental health", "psychiatrist", "psychologist", "vitamin",
            "supplement", "boots pharmacy", "apotheke"
        ]
    )

    public static let entertainment = Category(
        id: "entertainment",
        name: "Entertainment",
        icon: "\u{1F3AC}",
        color: "#F06595",
        type: .expense,
        keywords: [
            "movie", "cinema", "theater", "theatre", "concert",
            "museum", "amusement park", "theme park", "disney",
            "universal", "bowling", "arcade", "gaming", "playstation",
            "xbox", "nintendo", "steam", "epic games", "twitch",
            "event", "festival", "ticket", "ticketmaster", "eventbrite",
            "stubhub", "live nation", "zoo", "aquarium", "comedy",
            "show", "exhibition", "gallery"
        ]
    )

    public static let shopping = Category(
        id: "shopping",
        name: "Shopping",
        icon: "\u{1F6CD}\u{FE0F}",
        color: "#20C997",
        type: .expense,
        keywords: [
            "amazon", "ebay", "etsy", "shopify", "aliexpress",
            "wish", "zara", "h&m", "uniqlo", "gap", "old navy",
            "nike", "adidas", "puma", "reebok", "under armour",
            "nordstrom", "macy's", "bloomingdale's", "tj maxx",
            "marshalls", "ross", "primark", "asos", "shein",
            "best buy", "apple store", "samsung", "electronics",
            "clothing", "shoes", "accessories", "mall", "outlet",
            "zalando", "about you", "otto"
        ]
    )

    public static let education = Category(
        id: "education",
        name: "Education",
        icon: "\u{1F4DA}",
        color: "#4C6EF5",
        type: .expense,
        keywords: [
            "tuition", "university", "college", "school", "course",
            "udemy", "coursera", "skillshare", "masterclass",
            "linkedin learning", "pluralsight", "education",
            "textbook", "book", "kindle", "audible", "library",
            "tutoring", "tutor", "lesson", "class", "training",
            "workshop", "seminar", "conference", "certification"
        ]
    )

    public static let travel = Category(
        id: "travel",
        name: "Travel",
        icon: "\u{2708}\u{FE0F}",
        color: "#22B8CF",
        type: .expense,
        keywords: [
            "airline", "flight", "airbnb", "hotel", "hostel",
            "booking.com", "expedia", "kayak", "trivago",
            "marriott", "hilton", "hyatt", "motel", "resort",
            "cruise", "vacation", "holiday", "travel", "luggage",
            "suitcase", "passport", "visa", "airport", "rental car",
            "hertz", "avis", "enterprise", "sixt", "europcar",
            "ryanair", "easyjet", "lufthansa", "british airways",
            "delta", "united", "american airlines", "southwest"
        ]
    )

    public static let insurance = Category(
        id: "insurance",
        name: "Insurance",
        icon: "\u{1F6E1}\u{FE0F}",
        color: "#748FFC",
        type: .expense,
        keywords: [
            "insurance", "life insurance", "auto insurance",
            "car insurance", "health insurance", "renters insurance",
            "homeowners insurance", "geico", "progressive",
            "state farm", "allstate", "liberty mutual", "usaa",
            "travelers", "axa", "allianz", "zurich", "aviva",
            "policy", "premium", "deductible", "coverage", "claim"
        ]
    )

    public static let personalCare = Category(
        id: "personal-care",
        name: "Personal Care",
        icon: "\u{1F487}",
        color: "#DA77F2",
        type: .expense,
        keywords: [
            "haircut", "salon", "barber", "spa", "massage",
            "nail", "manicure", "pedicure", "skincare", "cosmetics",
            "makeup", "sephora", "ulta", "bath & body works",
            "perfume", "cologne", "grooming", "facial", "waxing",
            "beauty", "dermatologist", "gym", "fitness", "yoga",
            "pilates", "crossfit", "personal trainer"
        ]
    )

    public static let gifts = Category(
        id: "gifts",
        name: "Gifts",
        icon: "\u{1F381}",
        color: "#E64980",
        type: .expense,
        keywords: [
            "gift", "present", "birthday", "christmas", "holiday",
            "wedding", "anniversary", "donation", "charity",
            "gofundme", "patreon", "tip", "gratuity", "flowers",
            "florist", "hallmark", "card", "wrapping", "baby shower",
            "graduation", "valentine"
        ]
    )

    public static let subscriptions = Category(
        id: "subscriptions",
        name: "Subscriptions",
        icon: "\u{1F4F1}",
        color: "#15AABF",
        type: .expense,
        keywords: [
            "netflix", "spotify", "apple music", "youtube premium",
            "youtube", "hulu", "disney+", "disney plus", "hbo",
            "max", "paramount+", "peacock", "prime video",
            "amazon prime", "adobe", "microsoft 365", "office 365",
            "google one", "icloud", "dropbox", "notion", "figma",
            "slack", "zoom", "subscription", "membership",
            "patreon", "substack", "medium", "new york times",
            "wall street journal", "newspaper", "magazine",
            "crunchyroll", "dazn", "apple tv", "apple one"
        ]
    )

    // MARK: - Income Categories

    public static let salary = Category(
        id: "salary",
        name: "Salary",
        icon: "\u{1F4B0}",
        color: "#37B24D",
        type: .income,
        keywords: [
            "salary", "payroll", "paycheck", "wage", "direct deposit",
            "employer", "compensation", "pay", "earnings", "income"
        ]
    )

    public static let freelance = Category(
        id: "freelance",
        name: "Freelance",
        icon: "\u{1F4BB}",
        color: "#1C7ED6",
        type: .income,
        keywords: [
            "freelance", "contract", "consulting", "gig",
            "fiverr", "upwork", "toptal", "freelancer",
            "side hustle", "client payment", "invoice", "project"
        ]
    )

    public static let investment = Category(
        id: "investment",
        name: "Investment",
        icon: "\u{1F4C8}",
        color: "#AE3EC9",
        type: .income,
        keywords: [
            "dividend", "interest", "stock", "bond", "etf",
            "mutual fund", "capital gain", "return", "yield",
            "robinhood", "vanguard", "fidelity", "schwab",
            "e-trade", "td ameritrade", "investment", "portfolio",
            "crypto", "bitcoin", "ethereum", "coinbase", "binance"
        ]
    )

    public static let otherIncome = Category(
        id: "other-income",
        name: "Other Income",
        icon: "\u{1F4B5}",
        color: "#0CA678",
        type: .income,
        keywords: [
            "refund", "reimbursement", "cashback", "cash back",
            "rebate", "bonus", "award", "prize", "lottery",
            "inheritance", "rental income", "royalty", "alimony",
            "child support", "government", "stimulus", "tax refund",
            "venmo", "paypal", "zelle", "transfer received"
        ]
    )

    // MARK: - Both (Expense & Income)

    public static let other = Category(
        id: "other",
        name: "Other",
        icon: "\u{1F4E6}",
        color: "#868E96",
        type: .both,
        keywords: []
    )

    // MARK: - All Categories

    /// All built-in default categories.
    public static let all: [Category] = [
        // Expense
        foodAndDining,
        groceries,
        transport,
        housing,
        utilities,
        healthcare,
        entertainment,
        shopping,
        education,
        travel,
        insurance,
        personalCare,
        gifts,
        subscriptions,
        // Income
        salary,
        freelance,
        investment,
        otherIncome,
        // Both
        other
    ]

    /// All expense categories (type == .expense or .both).
    public static var expenseCategories: [Category] {
        all.filter { $0.type == .expense || $0.type == .both }
    }

    /// All income categories (type == .income or .both).
    public static var incomeCategories: [Category] {
        all.filter { $0.type == .income || $0.type == .both }
    }

    /// Attempts to auto-detect a category from a merchant name or description.
    /// Returns the "Other" category if no match is found.
    public static func detectCategory(from text: String, transactionType: TransactionType = .expense) -> Category {
        let candidates: [Category]
        switch transactionType {
        case .expense:
            candidates = expenseCategories
        case .income:
            candidates = incomeCategories
        }

        if let matched = candidates.first(where: { $0.matchesText(text) }) {
            return matched
        }
        return other
    }

    /// Finds a category by its ID, or returns the "Other" category if not found.
    public static func category(withId id: String) -> Category {
        all.first { $0.id == id } ?? other
    }
}
