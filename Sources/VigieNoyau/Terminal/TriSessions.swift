import Foundation

/// Ordre d'affichage des sessions tmux.
///
/// Les attachées d'abord — quelqu'un les regarde depuis un autre terminal, donc
/// c'est probablement la plus vivante — puis les plus récemment créées.
public enum TriSessions {
    public static func triees(_ sessions: [SessionTmuxApi]) -> [SessionTmuxApi] {
        sessions.sorted { gauche, droite in
            if gauche.attached != droite.attached { return gauche.attached && !droite.attached }
            return gauche.created > droite.created
        }
    }
}
