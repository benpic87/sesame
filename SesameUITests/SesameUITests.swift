import XCTest

/// Parcours principaux de l'app, pilotés comme par un utilisateur.
/// L'app est lancée avec `-ui-testing` : état neuf et isolé à chaque test,
/// sans toucher aux données réelles du simulateur. Interface forcée en
/// français pour que les libellés ne dépendent pas de la langue du simulateur.
final class SesameUITests: XCTestCase {
    private var app: XCUIApplication!
    private let pin = "123456"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
    }

    // MARK: Parcours

    func testOnboardingLeadsToEmptyFreeVault() {
        completeOnboardingAndUnlock()

        XCTAssertTrue(staticText(containing: "0/3 documents").waitForExistence(timeout: 5))
    }

    /// Régression : un geste posé sur toute la fenêtre avalait le bouton retour.
    func testSettingsBackButtonReturnsToVault() {
        completeOnboardingAndUnlock()

        app.buttons["Réglages"].tap()
        XCTAssertTrue(app.navigationBars["Réglages"].waitForExistence(timeout: 5))

        app.navigationBars["Réglages"].buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.staticTexts["Coffre"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Réglages"].exists)
    }

    /// Régression : le scanner faisait planter l'app sans caméra compatible.
    func testCameraMethodsAreDisabledWithoutCamera() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Vérification propre au simulateur (pas de caméra)")
        #endif
        completeOnboardingAndUnlock()

        app.buttons["Ajouter"].tap()

        let scanner = button(startingWith: "Scanner un document")
        XCTAssertTrue(scanner.waitForExistence(timeout: 5))
        XCTAssertFalse(scanner.isEnabled)
        XCTAssertFalse(button(startingWith: "Prendre une photo").isEnabled)
        XCTAssertTrue(button(startingWith: "Nouvelle note").isEnabled)
    }

    /// Accueil en tuiles : une catégorie ouvre ses propres documents (jamais
    /// un document par erreur), le retour ramène aux tuiles, et « Tous les
    /// documents » liste tout le coffre. La photo de test, très haute,
    /// vérifie au passage que les vignettes ne débordent pas sur les tuiles.
    func testCategoryTilesOpenTheirDocuments() {
        app.terminate()
        app.launchArguments.append("-seed-portrait-document")
        app.launch()
        completeOnboardingAndUnlock()

        button(startingWith: "Identité").tap()
        let identity = app.navigationBars["Identité"]
        XCTAssertTrue(identity.waitForExistence(timeout: 5))
        XCTAssertTrue(staticText(containing: "Aucun document dans cette catégorie").exists)
        XCTAssertFalse(app.buttons["Modifier"].exists, "Aucun document ne doit s'ouvrir")

        identity.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Coffre"].waitForExistence(timeout: 5))

        button(startingWith: "Tous les documents").tap()
        XCTAssertTrue(app.navigationBars["Tous les documents"].waitForExistence(timeout: 5))
        XCTAssertTrue(staticText(containing: "Photo portrait").exists)
    }

    /// Un seul bouton « Partager », puis deux choix : archive chiffrée pour
    /// quelqu'un qui a Sésame, ou fichier original pour les autres.
    func testShareOffersEncryptedArchiveOrOriginalFile() {
        completeOnboardingAndUnlock()
        addNote(titled: "Passeport")

        button(startingWith: "Tous les documents").tap()
        app.staticTexts["Passeport"].firstMatch.tap()
        XCTAssertFalse(button(startingWith: "Exporter chiffré").exists)
        app.buttons["Partager"].firstMatch.tap()

        XCTAssertTrue(button(startingWith: "Chiffré, pour l'app Sésame").waitForExistence(timeout: 5))
        XCTAssertTrue(button(startingWith: "Fichier original (non chiffré)").exists)
    }

    /// De bout en bout : une archive .sesame reçue s'ouvre dans Sésame, refuse
    /// un mauvais mot de passe, puis ajoute le document avec le bon.
    func testOpeningReceivedArchiveImportsDocument() throws {
        let url = try ArchiveFixture.make(
            name: "Passeport reçu", text: "numéro 12AB34", passphrase: "corail-lampe-92-nuit"
        )

        // L'outil de test relance l'app pour ouvrir un fichier (un vrai envoi
        // AirDrop arrive dans l'app déjà ouverte) : l'archive est reçue au
        // lancement, puis proposée une fois le coffre créé et déverrouillé.
        app.open(url)
        completeOnboardingAndUnlock()

        XCTAssertTrue(app.staticTexts["Document chiffré reçu"].waitForExistence(timeout: 10))
        let field = app.textFields["Mot de passe"]
        field.tap()
        field.typeText("mauvais-mot-11-passe")
        app.buttons["Importer dans le coffre"].tap()
        XCTAssertTrue(app.staticTexts["Mot de passe incorrect"].waitForExistence(timeout: 5))

        // Curseur en fin de champ, sinon une partie de l'ancien texte resterait.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30))
        field.typeText("corail-lampe-92-nuit")
        app.buttons["Importer dans le coffre"].tap()

        XCTAssertTrue(app.staticTexts["Coffre"].waitForExistence(timeout: 10))
        XCTAssertTrue(staticText(containing: "1/3 documents").waitForExistence(timeout: 5))
        button(startingWith: "Tous les documents").tap()
        XCTAssertTrue(app.staticTexts["Passeport reçu"].waitForExistence(timeout: 5))
    }

    func testFourthDocumentOpensPaywall() {
        completeOnboardingAndUnlock()

        for index in 1...3 {
            addNote(titled: "Note \(index)")
        }
        XCTAssertTrue(staticText(containing: "3/3 documents").waitForExistence(timeout: 5))

        app.buttons["Ajouter"].tap()

        XCTAssertTrue(staticText(containing: "limité à 3 documents").waitForExistence(timeout: 5))
    }

    func testRestorePurchasesIsExplainedInSettings() {
        completeOnboardingAndUnlock()

        app.buttons["Réglages"].tap()

        let restore = button(startingWith: "Restaurer mes achats")
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        XCTAssertTrue(restore.isEnabled)
        XCTAssertTrue(staticText(containing: "Récupérez Premium sans repayer").exists)
    }

    // MARK: Étapes

    private func completeOnboardingAndUnlock() {
        let start = app.buttons["Commencer"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        enterPIN()      // choix
        enterPIN()      // confirmation

        let create = app.buttons["Créer mon coffre"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()

        // Pas de Face ID sur simulateur : le pavé PIN s'ouvre de lui-même.
        enterPIN()

        XCTAssertTrue(app.staticTexts["Coffre"].waitForExistence(timeout: 10))
    }

    private func enterPIN() {
        XCTAssertTrue(app.buttons["1"].waitForExistence(timeout: 10))
        for digit in pin {
            app.buttons[String(digit)].tap()
        }
    }

    private func addNote(titled title: String) {
        app.buttons["Ajouter"].tap()

        let newNote = button(startingWith: "Nouvelle note")
        XCTAssertTrue(newNote.waitForExistence(timeout: 5))
        newNote.tap()

        let titleField = app.textFields["Titre de la note"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)

        app.buttons["Enregistrer"].tap()
        XCTAssertTrue(app.staticTexts["Coffre"].waitForExistence(timeout: 10))
    }

    // MARK: Recherche d'éléments

    private func staticText(containing text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func button(startingWith text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }
}
