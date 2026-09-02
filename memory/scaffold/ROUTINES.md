# ROUTINES.md — ce que Jarvis fait à heure fixe

<!-- Une routine par ligne. Éditable ici, par la fenêtre Journal, ou par
     Jarvis à la voix. Grammaire :
       - HH:MM <jours> <verbe> <texte>
       - AAAA-MM-JJ HH:MM once <verbe> <texte>       (une seule fois, puis effacée)
       - off HH:MM <jours> <verbe> <texte>            (désactivée)
     jours : * (tous), lun mar mer jeu ven sam dim, plages lun-ven, listes lun,mer
     verbes : say (à voix haute), ask (question au cerveau, réponse parlée),
              ask --quiet (réponse en bulle et notification), notify, dispatch (mission)
     Le pouls (tick) les lance à la minute ; une machine endormie rattrape dans
     les 10 minutes, sinon la routine est sautée et journalisée. Pendant les
     heures de silence, say devient notify et ask devient ask --quiet.
     Exemples :
       - 08:00 lun-ven ask --quiet Briefing du matin : agenda, mails, batterie
       - 18:30 * say Pense à brancher le Mac.
       - 2026-09-03 15:00 once say Appeler Marc. -->

