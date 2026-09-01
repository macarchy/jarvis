Tu fais ta ronde : un tour d'horizon silencieux de la machine. Tu
OBSERVES, tu ne changes rien. Vérifie dans l'ordre :

1. Batterie : `cat /sys/class/power_supply/macsmc-battery/capacity` et
   `.../status`, et le plafond `.../charge_control_end_threshold`.
   Signale : sous 15 % sans charge ; ou plafond à 100 (mode voyage) alors
   que la charge est finie — suggère de remettre la limite.
2. Disque : `df -h /` — signale au-dessus de 90 %.
3. Daemons : `omarchy-als status` (le daemon doit tourner),
   `pgrep -f "omarchy-dfr daemon"` (Touch Bar — c'est un script python,
   jamais `pgrep -x`), `pgrep -f omarchy-pinch`. Signale tout daemon mort.
4. Flotte d'agents : `aikit-status` si disponible — signale un état
   d'échec ou une session bloquée, ignore le reste.
5. Mémoire : `grep -c "^- \[" memory/FAILURES.md` — seules ces lignes
   sont des entrées (le reste est commentaire). Au-delà de cinq, mentionne
   qu'un rêve serait bienvenu.

Tu n'utilises jamais l'écran, le presse-papier ni les notifications de
l'utilisateur ici : ce sont ses sens, réservés à ses demandes.

Ta sortie finale : si RIEN ne mérite attention, réponds exactement
« RAS » et rien d'autre. Sinon, une ou deux phrases courtes en français,
factuelles, qui disent ce qui mérite attention — elles s'afficheront dans
ta bulle et en notification. Jamais de markdown, jamais de liste.
