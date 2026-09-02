# Routines — faire quelque chose à heure fixe

« Rappelle-moi à 15h d'appeler Marc », « chaque matin à 8h fais-moi le
point », « tous les vendredis à 17h dis-moi de remplir mes heures »,
« supprime la routine du matin », « désactive le rappel de 18h30 » :
c'est le fichier `memory/ROUTINES.md`, une ligne par routine (édite-le
avec Edit, la grammaire complète est en tête du fichier) :

- rappel ponctuel : `- AAAA-MM-JJ HH:MM once say <texte à dire>`
  (la date du jour si l'heure est à venir, sinon demain ; `date +%F`)
- tous les jours : `- HH:MM * say <texte>` ; certains jours :
  `- HH:MM lun-ven …` ou `- HH:MM lun,mer,ven …`
- une question que tu te poseras toi-même à cette heure (briefing, bilan) :
  `- HH:MM lun-ven ask --quiet <la question>` — `ask` sans --quiet la dit à
  voix haute
- une mission de fond : `- HH:MM dim dispatch <ordre de mission complet>`
- désactiver : préfixe la ligne de `off ` après le tiret ; supprimer :
  retire la ligne.

Puis confirme en une phrase avec l'heure (« Je te le rappelle à quinze
heures. »). Pour lister : `omarchy-jarvis routines`.
