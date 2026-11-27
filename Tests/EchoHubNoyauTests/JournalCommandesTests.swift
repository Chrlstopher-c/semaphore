import Testing
@testable import EchoHubNoyau

@Suite("Terminal de l'agent")
struct JournalCommandesTests {
    @Test func relitLesCommandesShellSeulement() {
        let contenu = "Je lance.<outil><entree>executer_commande(commande : ls -la)</entree><sortie>total 0</sortie></outil>"
            + "<outil><entree>lire_fichier(chemin : a.py)</entree><sortie>x</sortie></outil>"
        let journal = JournalCommandes.lire([contenu])
        #expect(journal.count == 1)
        #expect(journal.first?.sortie == "total 0")
        #expect(journal.first?.commande.contains("ls -la") == true)
    }
}
