# NOISE.md — ce qui n'est personne

<!-- La reconnaissance vocale ne rend jamais une chaîne vide sur du silence :
     elle rend le générique qu'elle a le plus lu pendant son entraînement.
     Whisper a été nourri de sous-titres, alors une pièce vide devient
     « Sous-titres réalisés par la communauté d'Amara.org » — neuf fois le
     2026-09-01, chacune parlée à voix haute, portée au journal, et payée
     d'un appel au cerveau.

     Un motif par ligne : une expression rationnelle étendue (ERE) comparée à
     la TOTALITÉ du transcript, sans tenir compte de la casse. Les lignes
     vides et celles qui commencent par # sont ignorées. Comme la comparaison
     porte sur le tout, « Trouve-moi les sous-titres de ce film » ne peut pas
     tomber dans un motif qui décrit un générique entier — c'est le point de
     l'ancrage, et ce que les tests négatifs de tests/run protègent.

     Édite librement : c'est ta copie. `omarchy-jarvis noise? "<texte>"`
     répond en code de sortie (0 = bruit) et ne demande aucun micro. -->

# — les génériques de sous-titres, la famille dont sortent presque toutes
#   les hallucinations françaises
sous-titres? r[ée]alis[ée]s par.*
.*amara\.org.*
.*soustitreur\.com.*
sous-titrage (de la )?soci[ée]t[ée] radio-canada.*
subtitles? by .*
subtitling by .*

# — les formules de fin de vidéo
merci d['’]avoir regard[ée].*
je vous invite [àa] vous abonner.*
abonnez-vous.*
n['’]oubliez pas de vous abonner.*
[àa] la prochaine[ !.…]*
thanks? for watching[ !.…]*
please subscribe[ !.…]*

# — les politesses seules. Dans une phrase elles passent : l'ancrage veut
#   que le transcript ENTIER se réduise à ça, et un transcript qui n'est
#   qu'un « merci » sort d'une pièce vide bien plus souvent que d'un humain.
merci[ !.…]*
merci beaucoup[ !.…]*
thank you[ !.…]*
thanks[ !.…]*
you[ !.…]*
bye[ !.…]*

# — et le silence que le modèle a bien voulu reconnaître comme tel
[ .!?…·,;:'’«»"-]*
