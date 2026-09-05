# REFLEXES.md — ce que la machine sait déjà

<!-- Un modèle qui n'a pas d'horloge n'en dit pas moins l'heure. Mesuré le
     2026-09-05 sur le modèle local : « Quelle heure est-il » a reçu « Il est
     14h37 » à 23 h passées, avec aplomb, dans le format parlé exact de
     Jarvis. Rien dans la réponse ne trahissait l'invention — c'est ça le
     danger : une valeur plausible et fausse est pire qu'un refus, parce
     qu'on la croit, et que le journal la relit ensuite comme un fait.

     Chaque rangée existe pour cette raison-là et pas pour la vitesse : ce
     que `date`, `wpctl` ou un fichier de /sys peuvent répondre exactement,
     le cerveau n'a plus le droit de le deviner. La table sert aussi en
     ligne — elle est plus rapide et plus juste — mais elle est vitale hors
     ligne, quand le réseau est mort et que la machine, elle, ne l'est pas.

     Quatre colonnes séparées par des TABULATIONS :

         motif <TAB> commande <TAB> slot <TAB> phrase-fr | phrase-en

     Le motif est une expression rationnelle étendue (ERE) comparée sans
     casse à la TOTALITÉ du transcript. Le code l'ancre lui-même en
     ^(motif)$ — n'écris jamais les ancres ici. C'est la même mécanique que
     NOISE.md, et c'est elle qui garde « pourquoi le son est-il si fort ? »
     loin de la commande de volume, et « quelle est la date de sortie du
     film » loin de la date du jour.

     La commande est un one-liner shell ; `{n}` y est remplacé par le slot.
     Le slot vaut `-` (aucun) ou `num` (le premier entier du transcript,
     BORNÉ 0–100 avant substitution). Il n'existe pas de slot `texte` :
     faire passer du texte de reconnaissance vocale dans une commande est
     une surface d'injection qu'on refuse, et l'entendre de travers une fois
     suffirait.

     La phrase est lue à voix haute : français et anglais séparés par ` | `,
     pas de markdown, pas de symboles (`·`, `→`, `*`) — il les prononce.
     `{}` y est remplacé par la SORTIE de la commande, `{n}` par le slot.
     Écris `{}` dès que la commande peut poser autre chose que ce qui a été
     demandé ; sinon la phrase ment sans le savoir.

     La table est lue DANS L'ORDRE, premier motif qui couvre tout gagne :
     le plus spécifique se met en haut. Une commande qui échoue rend la main
     au cerveau plutôt que de prononcer une phrase toute faite au-dessus
     d'un échec — c'est pourquoi les rangées d'état sortent en erreur sur un
     état inconnu au lieu de répondre « inactif ».

     Ce qui n'est PAS ici, et pourquoi : les quatre rangées de luminosité
     (le démon macarchy-als réécrit le backlight en continu — vérifié
     running aujourd'hui, « curve target 7% » — donc « Luminosité à 50 pour
     cent » redevient faux quelques secondes plus tard, et une phrase qui
     ment en différé est pire que pas de rangée) ; le centre de
     notifications (la seule preuve invoquée venait de wake/train-verifier,
     pas du corpus, et la seule vraie demande observée était « Parfait,
     referme-le », qu'aucun motif ancré n'attrapera) ; la météo (sortie non
     parlable — `·` et `→` seraient prononcés — et morte hors ligne) ; le
     fuseau horaire (mur de permission système, une rangée ne l'ouvre pas) ;
     les salutations (aucune preuve organique, les douze « salut » du corpus
     sont un fanout de test) ; l'identité — c'est précisément ce que le
     cerveau doit répondre avec sa personnalité.

     Vérifié à l'écriture : aucune rangée n'en masque une autre (chaque
     transcript positif ne tombe que dans une seule). Le seul chevauchement
     possible était « mets le son à 30 », qui doit rester au-dessus de
     « monte le son » — d'où l'ordre de la section son. Plafond connu et
     assumé : le slot est numérique, donc « mets le son à trente pour cent »
     écrit en toutes lettres part au cerveau ; un slot texte serait une
     surface d'injection, on préfère le faux négatif.

     Édite librement : c'est ta copie. `omarchy-jarvis reflexe? "<texte>"`
     dit quelle rangée matche, `--run` l'exécute, et aucun micro n'est
     ouvert. -->

# — le temps. La machine le lit, le modèle l'invente.
(alors +)?((dis|donne)[- ]moi +|(est[- ]ce que +)?(tu +peux|peux[- ]tu|tu +pourrais|pourrais[- ]tu) +(me +)?dire +)?((quel(le)?|qu['’]?elle) +(heures?|heur|oeuf|œuf|leur) +((est|et)[- ]?(il|t[- ]il)|(il|qu['’]?il) +(est|et))|(il est|c['’]est) +(quel(le)?|qu['’]?elle) +(heures?|heur|oeuf|leur)|(quel(le)?|qu['’]?elle) +est +l['’]? *(heures?|heur|oeuf|leur)( +du[.…]*)?|(tu +as|t['’]?as|vous +avez) +l['’]? *(heures?|heur)|l['’] *(heures?|heur))( +(s['’]?il te pla[îi]t|stp))?[ ?!.…]*	date '+%-H heures %-M' | sed 's/ 0$//; s/^0 heures/minuit/; s/^1 heures/1 heure/'	-	Il est {}. | It's {}.
((dis|donne)[- ]moi +|rappelle[- ]moi +)?((on +est|nous +sommes) +(quel +jour|quelle +date|le +combien)( +(d['’])?aujourd['’]?hui)?|(quel +jour|quelle +date) +(on +est|sommes[- ]nous|est[- ]on|c['’]est)( +(d['’])?aujourd['’]?hui)?|(c['’]est +)?quel +jour( +on +est)? +(d['’])?aujourd['’]?hui|(c['’]est +)?quoi +la +date( +du +jour| +(d['’])?aujourd['’]?hui)?|quelle +est +la +date( +du +jour| +(d['’])?aujourd['’]?hui)?|(dis|donne)[- ]moi +la +date|la +date +(du +jour|(d['’])?aujourd['’]?hui))[ ?!.…]*	date '+%u %-d %m' | awk '{split("lundi mardi mercredi jeudi vendredi samedi dimanche",j," ");split("janvier février mars avril mai juin juillet août septembre octobre novembre décembre",m," ");print j[$1], ($2==1?"premier":$2), m[$3+0]}'	-	On est {}. | It's {}.

# — l'état de la machine. Deux lectures, et un état inconnu doit
#   ÉCHOUER : le cerveau dira « je ne sais pas », la table ne le peut pas.
(quel(le)? est (l['’]|le |la )?(pourcentage|niveau|[ée]tat) (de |d['’])(la )?batteries?|(il (me )?reste |j['’]ai )?combien de batteries?|combien (il (me )?reste )?de batteries?|combien de batteries? (il )?(me )?reste([- ]t[- ]il)?|la batterie est [àa] combien|niveau de batteries?|battery level|how much battery( is)? left|what['’]?s the battery( level)?)[ ?!.…]*	cat /sys/class/power_supply/macsmc-battery/capacity	-	La batterie est à {} pour cent. | Battery is at {} percent.
(est-ce que )?(le |mon )?(mode )?ne pas d[ée]ranger,? (est|et)([- ]il)? (actif|activ[ée]|allum[ée]|en marche)[ ?!.…]*	case "$(omarchy-shell notifications dndState)" in on) echo actif;; off) echo inactif;; *) exit 1;; esac	-	Le mode ne pas déranger est {}. | Do not disturb is {}.

# — quel cerveau répond. Le modèle ne peut pas le savoir : il n'a pas
#   accès à son propre routage, et interrogé là-dessus il répond de
#   mémoire. Il a eu juste une fois ; c'est la même faute que l'heure.
(est-ce que )?((quel|quelle) (cerveau|mod[èe]le|ia|llm|l\\.?l\\.?m) (tu utilises|utilises[- ]tu|est[- ]ce que tu utilises)|tu (utilises|tournes (sur|avec)) (quel|quelle) (cerveau|mod[èe]le|ia|llm|l\\.?l\\.?m)|(sur )?(quel|quelle) (cerveau|mod[èe]le|ia|llm|l\\.?l\\.?m) (tu tournes|tournes[- ]tu|tu es)|tu (es|penses) (en )?(local|hors ligne|en ligne)|(which|what) (brain|model|llm) (are you|do you) (using|use|run on))[ ?!.…]*	r=$(omarchy-jarvis status); case "$(sed -n 's/^route=//p' <<<"$r")" in nuage) echo Claude;; local) sed -n 's/^cerveau_modele=//p' <<<"$r";; *) exit 1;; esac	-	Je pense avec {}, en ce moment. | I'm thinking with {} right now.

# — le son. La rangée à chiffre passe AVANT les rangées ± : « mets le
#   son à 30 » ne doit pas tomber dans « monte le son ».
((est-ce que )?(tu peux|peux-tu) )?((mets|met|mais|mettre|r[èe]gl(e|er)|pass(e|er)|mont(e|er)|baiss(e|er))[- ]?(moi )?)?(le )?(son|volume) (a|à|sur) [0-9]{1,3}( ?%| pour ?cents?| pourcents?)?( s['’]?il te pla[iî]t)?[ !.…]*	wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ {n}%	num	Son à {n} pour cent. | Volume at {n} percent.
((est-ce que )?(tu peux|peux-tu) )?(((mets|met|mais|mettre) )?(le (son|volume) )?(un peu )?plus fort|(mont(e|er)|augment(e|er)|remont(e|er))( un peu)? (le son|le volume)( un peu)?)( s['’]?il te pla[iî]t)?[ !.…]*	omarchy audio output volume raise	-	Plus fort. | Louder.
((est-ce que )?(tu peux|peux-tu) )?(((mets|met|mais|mettre) )?(le (son|volume) )?(un peu )?moins fort|(baiss(e|er)|diminu(e|er)|r[ée]dui(s|re))( un peu)? (le son|le volume)( un peu)?)( s['’]?il te pla[iî]t)?[ !.…]*	omarchy audio output volume lower	-	Moins fort. | Quieter.
((est-ce que )?(tu peux|peux-tu) )?((coup(e|er)|[ée]tein(s|dre))[- ]?(moi )?(le son|le volume|la musique)|(mets|met|mais|mettre) (le son |[çc]a )?en sourdine|mute)( s['’]?il te pla[iî]t)?[ !.…]*	wpctl set-mute @DEFAULT_AUDIO_SINK@ 1	-	Son coupé. | Sound off.
((est-ce que )?(tu peux|peux-tu) )?((remets|remet|remettre|r[ée]tabli(s|r)|r[ée]activ(e|er)|redonn(e|er))[- ]?(moi )?(le son|le volume)|(enl[èe]v(e|er)|coup(e|er)) la sourdine)( s['’]?il te pla[iî]t)?[ !.…]*	wpctl set-mute @DEFAULT_AUDIO_SINK@ 0	-	Son rétabli. | Sound back.

# — les bascules du bureau. Chaque paire est complète : allumer sans
#   pouvoir éteindre est un piège quand le cerveau est hors ligne.
(est-ce que )?((tu peux|peux-tu) (mettre|passer|basculer|activer)|mets?|met|mais|passe|bascule|active|remets)?(-| )?(moi )?(le |en |au |sur le |dans le )?(mode|th[èe]me) clair( s['’]il te pla[îi]t)?[ ?!.…]*	omarchy theme set apple-glass-light	-	Thème clair activé, ça change ! | Light theme on.
(est-ce que )?((tu peux|peux-tu) (mettre|passer|basculer|activer)|mets?|met|mais|passe|bascule|active|remets)?(-| )?(moi )?(le |en |au |sur le |dans le )?(mode|th[èe]me) (sombre|fonc[ée])( s['’]il te pla[îi]t)?[ ?!.…]*	omarchy theme set apple-glass	-	Thème sombre activé, c'est plus reposant. | Dark theme on.
(est-ce que )?((tu peux|peux-tu) (lancer|relancer|d[ée]marrer|allumer|activer|remettre|ouvrir)|r?allume|(re)?lance|red[ée]marre|d[ée]marre|active|remets|mets|ouvre)(-| )?(moi )?(l['’])?aquarium( s['’]il te pla[îi]t)?[ ?!.…]*|aquarium (on|en marche)[ ?!.…]*	omarchy-aquarium-toggle on	-	L'aquarium est lancé. | The aquarium is running.
(est-ce que )?((tu peux|peux-tu) (couper|arr[êe]ter|[ée]teindre|d[ée]sactiver|fermer|stopper|enlever)|coupe|arr[êe]te|stoppe|[ée]teins|d[ée]sactive|ferme|enl[èe]ve)(-| )?(moi )?(l['’])?aquarium( s['’]il te pla[îi]t)?[ ?!.…]*|aquarium (of|off)[ ?!.…]*	omarchy-aquarium-toggle off	-	Aquarium coupé. | Aquarium off.

# — la seule demande du corpus que la permission avait refusée.
((est-ce que )?(tu peux|peux-tu) (verrouiller|v[ée]rouiller)|verrouille|verrouilles|v[ée]rouille)(-| )?(moi )?(l['’]|le |la |mon |ma )([ée]cran|ordi|ordinateur|mac|machine|session|portable)( s['’]il te pla[îi]t)?[ ?!.…]*	omarchy-system-lock	-	Je verrouille, à tout de suite. | Locking, see you soon.
