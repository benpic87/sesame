import SwiftUI

/// Guide d'utilisation : l'essentiel de l'app en quelques rubriques,
/// traduit comme le reste de l'interface (Localizable.xcstrings).
struct GuideView: View {
    private struct Topic: Identifiable {
        let icon: String
        let title: LocalizedStringKey
        let text: LocalizedStringKey
        var id: String { icon }
    }

    private let topics: [Topic] = [
        Topic(
            icon: "plus.circle.fill",
            title: "Ajouter un document",
            text: "Touchez « Ajouter » sur l'écran du coffre, puis scannez un document, prenez une photo, importez une image ou un fichier, ou rédigez une note. Tout est chiffré dès l'ajout."
        ),
        Topic(
            icon: "tag.fill",
            title: "Classer par catégories",
            text: "Attribuez une ou plusieurs étiquettes à chaque document. Vous pouvez créer, renommer ou recolorer vos catégories à tout moment dans les Réglages."
        ),
        Topic(
            icon: "magnifyingglass",
            title: "Retrouver un document",
            text: "La loupe recherche par nom au fil de la saisie. Les filtres Images, PDF et Notes affinent les résultats."
        ),
        Topic(
            icon: "calendar.badge.exclamationmark",
            title: "Suivre les dates d'expiration",
            text: "Indiquez la date d'expiration lorsque vous ajoutez un passeport ou une carte : Sésame la signale lorsqu'elle approche."
        ),
        Topic(
            icon: "lock.fill",
            title: "Verrouillage du coffre",
            text: "Le coffre se verrouille dès que vous quittez l'app et après un délai d'inactivité, réglable dans les Réglages. Face ID ou votre code PIN le rouvre."
        ),
        Topic(
            icon: "square.and.arrow.up.fill",
            title: "Partager en sécurité",
            text: "Depuis un document, touchez « Partager ». L'envoi chiffré s'adresse à une personne qui utilise Sésame : transmettez-lui le mot de passe généré par un autre canal. Le fichier original, non chiffré, est à réserver aux personnes de confiance."
        ),
        Topic(
            icon: "externaldrive.fill",
            title: "Sauvegarder le coffre",
            text: "Vos documents n'existent que sur cet appareil et ne figurent pas dans les sauvegardes iCloud. Exportez régulièrement une sauvegarde chiffrée depuis les Réglages et conservez la phrase de récupération : sans elle, la sauvegarde est illisible."
        ),
        Topic(
            icon: "sparkles",
            title: "Premium et code promo",
            text: "La version gratuite accueille 3 documents. Sésame Premium, un achat unique, rend le coffre illimité. Si vous avez un code promo, saisissez-le dans les Réglages, section Sésame Premium."
        ),
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sésame garde vos documents chiffrés sur cet iPhone, et nulle part ailleurs. Voici l'essentiel pour bien l'utiliser.")
                        .appFont(15, .regular, relativeTo: .subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 6)

                    ForEach(topics) { topic in
                        GuideTopicCard(icon: topic.icon, title: topic.title, text: topic.text)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Guide d'utilisation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct GuideTopicCard: View {
    let icon: String
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.accentTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .appFont(15.5, .bold, relativeTo: .subheadline)
                    .foregroundStyle(Theme.textPrimary)
                Text(text)
                    .appFont(14, .regular, relativeTo: .footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .combine)
    }
}
