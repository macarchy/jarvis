<!-- Une table jetable : elle teste le MÉCANISME, pas la politique. Les
     rangées réellement livrées vivent dans memory/REFLEXES.md et sont
     tenues par leurs propres cas, plus bas dans tests/run. -->

# une rangée sans slot
quelle heure est[- ]il ?[ ?!.]*	echo 14:00	-	Il est {}. | It is {}.

# une rangée avec slot numérique
(mets|r[ée]gle) le son [aà] [0-9]{1,3} ?%?[ .!]*	echo vol={n}	num	Son à {n} pour cent. | Volume at {n} percent.

# une commande interdite : doit être refusée AU CHARGEMENT
formate le disque	rm -rf /tmp/jamais	-	fait | done

# une commande qui échoue : doit rendre la main au cerveau
teste un [ée]chec	false	-	jamais dit | never said
