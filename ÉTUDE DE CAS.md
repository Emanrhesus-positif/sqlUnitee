  		 	 	 		  
			  
				  
					  
						

ÉTUDE DE CAS						

Veille automatisée des marchés publics,secteur bâtiment modulaire, bâtiment en kit et assemblage rapide

						

SQL avancé – procédures, fonctions, triggers, transactions, sauvegarde, automatisation.

M1 Data, Licence pro.									

Travail individuel ou en binôme

					  
														  
				![][image1]		

Important : ce document est volontairement rédigé sous forme d’étude de cas. Il décrit le contexte, les besoins, les contraintes, les données attendues et les travaux à réaliser, mais il ne fournit pas les réponses ni les scripts complets de solution.

[https://www.unit-ee.com/](https://www.unit-ee.com/)

								  
			

**1\. Présentation générale du cas**			

								

L’entreprise unitee conçoit, assemble et déploie des bâtiments modulaires, des structures préfabriquées, des bases vie de chantier, des classes temporaires et des extensions rapides pour des clients publics et parapublics. Son activité dépend fortement de sa capacité à détecter rapidement les appels d’offres et à qualifier les opportunités les plus pertinentes.				

Actuellement, la veille est effectuée manuellement par plusieurs collaborateurs qui consultent différents portails. Ce fonctionnement provoque des pertes de temps, des doublons, des oublis et une qualification irrégulière des marchés détectés.					

La direction souhaite donc mettre en place une solution de veille automatisée basée sur une base de données relationnelle capable de centraliser les annonces, de calculer un niveau de pertinence, de suivre les événements techniques, de déclencher des notifications et de produire un tableau de bord utile au pilotage.

					

**2\. Problématique métier**					

Vous êtes missionné(e) pour concevoir la partie données et automatisation de cette future plateforme. La direction ne souhaite pas un simple ensemble de tables, mais un système SQL robuste, industrialisable et supervisable.

Les annonces doivent être récupérées depuis plusieurs sources.  
Les doublons doivent être détectés et empêchés.  
Les marchés doivent être évalués selon des critères métier.	Les opportunités critiques doivent générer une alerte e-mail.  
Toutes les opérations importantes doivent laisser une trace exploitable  
Une stratégie de sauvegarde complète doit être prévue.  
Un dashboard doit permettre de lire les indicateurs clés de l’activité.

**3\. Objectifs pédagogiques**

 							  
Cette étude de cas vise à mobiliser des notions avancées de SQL et d’exploitation :  
 						  
 					  
 							  
concevoir un schéma relationnel cohérent et normalisé  
 						  
 							  
écrire des fonctions SQL de calcul métier  						  
 							  
concevoir des procédures stockées  						  
 							  
mettre en place des triggers pertinents  						  
 							  
gérer des transactions et des cas d’erreur  
 						  
 							  
automatiser des traitements récurrents ; 						  
 							  
mettre en place une stratégie de sauvegarde et de restauration   
 						  
 							  
préparer les données d’un tableau de bord avec graphiques.  
 							

**4\. Périmètre fonctionnel du système**  
 						

					 				  
			

| Volet | Objectif du système (fonction attendue) | Détails techniques / attentes concrètes |
| :---- | ----- | ----- |
| Collecte | Recevoir ou intégrer automatiquement de nouvelles annonces de marchés publics | \- Connexion à des sources (API, scraping, flux RSS)- Planification via CRON- Gestion des formats (JSON, XML, HTML)- Déduplication initiale |
| Qualification | Évaluer et prioriser les marchés selon leur pertinence | \- Calcul d’un score (mots-clés, montant, localisation)- Algorithme de scoring- Attribution d’un niveau (faible, moyen, élevé)- Stockage du score |
| Traçabilité | Assurer un suivi complet des actions techniques et métier | \- Logs techniques (erreurs, appels API)- Logs métier (qualification, modification)- Historisation des changements- Auditabilité |
| Sauvegarde | Garantir la sécurité et la restauration des données | \- Sauvegardes automatiques (quotidiennes / hebdomadaires)- Export SQL ou dump- Versionning des sauvegardes- Stockage externe possible |
| Pilotage | Permettre l’analyse et le suivi des données via des indicateurs | \- Dashboard (graphiques, KPI)- Statistiques (nombre de marchés, taux de pertinence)- Filtres dynamiques- Historique et tendances |

			  
				  
					

**5\. Contraintes métier à prendre en compte**

Une même annonce peut être publiée ou relayée par plusieurs sources.  
 						

Certaines annonces sont pertinentes uniquement si elles concernent le modulaire, le préfabriqué, l’assemblage rapide ou des usages comparables.  
 						

Le délai entre la publication d’une annonce et son traitement peut être critique.  
 						

Les responsables métier ont besoin d’indicateurs simples et lisibles, pas seulement d’une liste brute.  
 						

Une panne serveur ou une erreur de manipulation ne doit pas faire perdre les données.  
 						

Le système doit être suffisamment structuré pour évoluer ensuite vers une application web complète.

 							  
**6\. Données disponibles et attendues**  
 							  
Les sources externes ne sont pas imposées techniquement dans cette étude de cas. Vous pouvez travailler à partir d’imports simulés, de fichiers d’exemple ou de scripts applicatifs qui injectent les données dans la base.  
 							  
Chaque annonce de marché peut contenir tout ou partie des informations suivantes :  
 						

| Champ potentiel | Description fonctionnelle | Type de donnée (SQL conseillé) | Contraintes / remarques techniques |
| ----- | ----- | ----- | ----- |
| Identifiant externe | Identifiant unique fourni par la plateforme source | VARCHAR(100) | Pas forcément unique globalement utiliser avec la source (clé composite) |
| Source | Nom du portail (BOAMP, TED, etc.) | VARCHAR(100) | Table référentiel recommandée (source) |
| Titre | Intitulé du marché | VARCHAR(255) | Index pour recherche rapide |
| Résumé | Description courte | TEXT | Peut être NULL |
| Description détaillée | Contenu complet ou enrichi | LONGTEXT | Utile pour NLP / extraction mots-clés |
| Acheteur public | Organisme émetteur (mairie, ministère…) | VARCHAR(255) | Normalisation possible (acheteur table) |
| Localisation | Zone géographique | VARCHAR(150) | Peut être découpé (ville, département, région) |
| Date de publication | Date de mise en ligne | DATETIME | Index important |
| Date limite réponse | Date limite de dépôt | DATETIME | Permet alertes |
| Budget estimatif | Montant estimé | DECIMAL(15,2) | Peut être NULL |
| Lien source | URL d’origine | TEXT | Doit être unique si possible |
| Mots-clés détectés | Liste de mots-clés extraits automatiquement | TEXT ou table liée |  Idéalement table mot\_cle \+ relation N:N |
| Statut de traitement | État du marché dans le système | ENUM ou VARCHAR(50) | Ex : NEW, QUALIFIED, IGNORED, RESPONDED |

			  
				  
					

**7\. Attentes techniques générales**

				  
Le responsable technique vous demande explicitement d’exploiter les mécanismes SQL suivants :  
					

procédures stockées.  
 

fonctions.

 								  
triggers . 	

					

transactions . 	

					

journalisation technique .

 						

sauvegarde complète.  
 						

restitution analytique pour graphiques.

**8\. Partie modélisation**  
 							  
À partir du contexte fourni, concevoir le modèle de données du système.  
 						

					 					  
Identifier les entités nécessaires.  
 						  
 							  
Proposer les tables principales et les tables de support.  
 						  
 							  
Définir les clés primaires et étrangères.  
 						  
 							  
Préciser les contraintes d’unicité pertinentes.  
 						  
 							  
Proposer une stratégie d’indexation minimale.  
 						  
 							  
Justifier les tables techniques de logs, notifications et sauvegardes.  
 						  
					 					

Le schéma doit permettre à la fois l’exploitation métier et la supervision technique.

					

**9\. Partie fonctions SQL**

					

Proposer au moins deux fonctions SQL ayant une vraie utilité dans le système.

					

* Une fonction de calcul ou d’aide à la qualification métier.  
   						  
* Une fonction de transformation ou d’interprétation d’un résultat.  
   						  
* Éventuellement une fonction d’aide à la mise en forme ou à la catégorisation.  
   							  
  Pour chaque fonction, vous devrez expliquer : son rôle, ses paramètres, sa valeur de retour, les hypothèses prises et les cas limites à gérer.

 							  
**10\. Partie procédures stockées**  
 							  
Proposer plusieurs procédures stockées structurantes pour le système.  
 						

					 					

* Une procédure d’insertion ou d’intégration d’un marché.  
   						  
* Une procédure de traitement d’un lot de marchés.  
   						  
* Une procédure d’alimentation ou de rafraîchissement du dashboard.  
   						  
* Éventuellement une procédure de maintenance ou de purge.  
   							  
  Vous ne devez pas livrer une simple suite d’INSERT. La logique de contrôle, de calcul, d’échec et de traçabilité doit être pensée dès la conception.  
   						

					 					  
il ne s’agit pas uniquement de prouver que vous connaissez la syntaxe. Il faut démontrer que chaque mécanisme répond à un vrai besoin du cas d’entreprise.  
					  
				  
			  
		  
		  
					  
**11\. Partie triggers**  
				  
			  
Identifier les événements de base qui justifient un traitement automatique au niveau SQL.  
					

* Quels contrôles doivent avoir lieu avant une écriture ?  
   						  
* Quelles traces doivent être écrites après certaines opérations ?  
   						  
* Dans quels cas un trigger peut-il préparer une notification ?  
   						  
* Quels risques ou limites faut-il garder à l’esprit avec ce mécanisme ?  
   							

**12\. Transactions et gestion d’erreur**  
 							  
Le système devra être capable de traiter des insertions unitaires et des traitements en lot. Vous devrez donc prévoir des scénarios transactionnels réalistes.  
 						

					 					

Définir au moins un scénario nécessitant un COMMIT / ROLLBACK.  
 						

Décrire un cas d’échec qui doit annuler tout le lot.  
 						

Préciser la journalisation attendue en cas de succès et d’erreur.  
 						

Expliquer l’intérêt métier d’une gestion transactionnelle correcte.

 							  
**13\.  Sauvegarde complète ** 

							  
La direction demande une stratégie de sauvegarde complète et exploitable. La sauvegarde doit inclure non seulement les données, mais aussi la logique SQL avancée associée au système.  
 						

					 					

Définir la fréquence de sauvegarde.  
 						

		  
Préciser ce qui doit impérativement être sauvegardé.  
 						

		  
Prévoir une rotation ou une conservation limitée des dumps.  
 						

Journaliser les sauvegardes réussies et échouées.  
 						

Décrire un test minimal de restauration.  
 						

Préciser comment vérifier que les objets avancés 

(procédures, triggers, événements) sont bien restaurés.  
 							  
					 				

**15\. Dashboard et graphiques**  
 							  
Les responsables métier ont besoin d’un tableau de bord synthétique et visuel. Vous devrez donc concevoir les données analytiques nécessaires à son alimentation.  
 							  
Le dashboard devra au minimum proposer :  
 						

					 					

* un indicateur du nombre total de marchés détectés  
   						  
* un indicateur du nombre de marchés pertinents  						  
* une répartition par priorité  
   						  
* une évolution temporelle des détections  						  
* une répartition géographique  						

 							  
**16\. Productions attendues**  
 							  
À la fin de l’étude de cas, l’étudiant ou le groupe devra fournir :  
 						

					 					

* le schéma de données   
   						  
* les scripts de création des tables   
  		  
* les scripts des fonctions, procédures et triggers  	  
  					  
* la logique transactionnelle retenue    
  						  
* la stratégie de sauvegarde documentée    
  						  
* les requêtes ou vues d’alimentation du dashboard  						

					 				  
			  
		  
		  
			 							  
		  
**17\. Critères d’évaluation proposés**  
 						

| Critère | Ce qui sera observé | Indicateurs d’évaluation précis  |
| ----- | ----- | ----- |
| Compréhension du besoin | Capacité à traduire le contexte métier en besoins SQL clairs | \- Reformulation correcte du besoin- Identification des entités clés- Cohérence entre besoin métier et solution |
| Modélisation | Qualité du schéma de base de données | \- Normalisation (3FN minimum)- Clés primaires/étrangères pertinentes- Contraintes d’unicité- Index justifiés |
| Fonctions SQL | Conception et utilité des fonctions métier | \- Paramètres cohérents- Valeur de retour pertinente- Réutilisabilité- Performance |
| Procédures stockées | Qualité de la logique métier implémentée | \- Gestion des cas métiers- Contrôle des données- Gestion des erreurs- Lisibilité |
| Triggers | Pertinence et maîtrise des déclencheurs | \- Utilité réelle (logs, automatisation)- Absence d’effets de bord- Bonne granularité (BEFORE/AFTER) |
| Transactions | Gestion des opérations critiques | \- Utilisation de BEGIN / COMMIT / ROLLBACK- Cohérence des scénarios- Gestion des erreurs |
| Sauvegarde | Stratégie de sauvegarde et restauration | \- Automatisation (planification)- Complétude (données \+ structure)- Procédure de restauration prévue |
| Dashboard | Qualité de l’analyse et du pilotage | \- KPI pertinents- Requêtes optimisées- Lisibilité des résultats- Cohérence métier |
|  |  |  |

			  
					  


[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAN4AAADeCAYAAABSZ763AAAioElEQVR4Xu1diX8UVdb9/rjvGyH7QsKijoCAOosz6owLOySQkIUEEAYFBBVHARkBZRlkEZBF/anIgIgLBATHgci+hSz3q3Nfverq1x2ozuuGxDmnPYZ0ql+9qr6n7n33bf/zPwRBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEARBEESBMaKtVka0jSDJflgrNfNrxbUbwhNV7RQeeW+6dkN4gsIjk9C1G8ITFB6ZhK7dEJ6g8MgkdO2G8ASFRyahazeEJyg8MglduyE8QeGRSejaDeGJqvbMm0ySLl27ITxB4ZFJ6NoN4QkKj0xC124IT1B4ZBK6dkN4gsIjk9C1G8ITFB6ZhK7dEJ6g8MgkdO2G8ASFRyahazeEJyg8MglduyE8QeGRSejaDeEJCo9MQtduCE9QeGQSunZDeILCI5PQtRvCExRe4Vkz39B9fyjRtRvCE78m4eFaajKmObm/F5DtVYbh7zXNVVJdXyWvHVwhS3YtlnFt46Vsdpn+TesKMcaOH8x07YbwxFAWXtWCKjVga8Q1zcG/51VJWX2plM8pk4q5FfpeurcpjBBT58ByeCOkaEqRbP76A+kKXr1i0C09cl2uSVVdVfSAGCqe0LUbwhNDVXjWcCsbKmV002hper9JNh7dJB3dHXJBOuV88P/TPT/KntN75fnXX5DK2ZWBGCsKZuhV86uleoFZg3Lue3MDgV2X3t5u6evrC9gT/jSEGFftWyVF04uzeOjBSdduCE8MduFFQglCstrASGGoZfMqZVzLeDly/rgacWDWaYadjT3Bq1vuyM3gNXbeWClrLFWPmfVcCVnZVi01C8y/S+pKpGV9s9wKXr3Byz1/NqJGnX2/SNHMkix1GVyCdO2G8MSQEV7A2oUjNYz8/NznKriuvmQGbtnba4I+CPD4+aNSU1crla2mXeYaflJCeGPmPKwCgpAgcNfD3Y3dQZ2uBw+Dvy57XkrnlklN28DqUWi6dkN4YrALr2p+jfkZCOPhhjHy3ZVvQ+MODDfQkTFga+z9Md3YpRcl9Kh4Pzz6oRTXF2UkRu5FhJZlDRXy51eeVS8X1Sks3z3n3Wjqclt+uPy9jA6uEWLO1fsWmq7dEJ4Y7MJDaFkyo0zePbguDCutUceNW9/tl66hW0GiDYawsONGh4yfPy4IYctVUG4dshHZyS/PHQ58Z1esLtmFnpTdfd16jc8sfjrwfpnh54OkazeEJwaj8PSJHwgObZ+Ve1emeZNC8lbgdT44ttEkYdpHmbqo50m1t3C/Ji55XM7cPB1IxIaWqTKktz+xJyc+D0Hv/OEjTQrZBIzN4Lr3637QtRvCEw/qi+yP8DjIVP552Z/kmlzVNlkQuWn7zDXQfNK2/4BTd07JqIaRUtNsuga0XrH7hAdDyZxSeXbps0Edr2QVn1t+rtS2aFAneECE2NVN1YKlGFEfU5f7m3xx7YbwxGARHgSnYWUQwn11+asgAOzR0KsnsEENGftse65wVMGE7UYkYD46uUcqZpRq/TQJ49QZiZBh04er98PxrgAHwpS3TJUFT7zv7MdSOr1MRrbWPhCv59oN4YkH8SVmIzq+xzQ/LOeDF570rvEVkikPBddq3+vR9h8SJ480PSyVjeWp+oZJGDwocP+K6obLrLdmy43gBfF5ebxA+PYhEy8HQF2W714h5UFb9H5nP127ITzxYIQXjtoIQraKlkp5c88bQUCFzOCdTEMcBISY7gReZ/1n66VsRrkKz+34tityD5/8UBB8XlehQEBeIuyHqMu2w1vUA2be28LQtRvCE/dTeDactKn7YVOKZN/JfQLf4hrX4KHxuhAQgl50wJdPKZfqFiM+m4QxDxMjvpIZJbJwc7seC2SWOXCajhDz83bwWr59WeJMrA9duyE8cT+FB8JIhs8YLku2LtbQCW2jlGHdn9AyF5o2VywE1ZCvSzZ8tklKgvZdFHbG+t2MIIP26rRi2fndjry0/cB4OagX2sC9wR1EXySGn7n3Op907YbwRKGEZ0Mvm463nq50ekkWwQ2MKgrbiY62USgS/G46sWMGj+OiDnd/oiPhduDRGtY1RqNf3PBTr795hCzbtVyvGZ8zAo4LyF+Uti26dMtSKZ5drA83M/Ag5YV96doN4YlCCQ+0osM4xmeWPys3AuOQMGuXrxBMwy6b8QyFZcIxKzx/w+6XvaabA+3Ttvfbtd8x2+gXFUJbpYyYWSknrn6rosXnXREOlKhDz507+hOvNZ+u1Qccxnvm6/t17YbwRL6+mP44fNpw+bHrjAou16FUSYk2oo7dDARw4vwJWXtgrby9923ZfmS7dFw7pckIjKNUw8x3f2AodvQCXpYr8vQrf5Ta1vQ2l05ZAheMkNLGUnn/i02CLgKEiQNJvgAqtu4e6erqMtcUdkPi73joIMPatKFJimeVZvXEudK1G8IThRJe6cxSmb1mZtQJnj6sKtOYcmdqtsHy7Sukps7MEChvrtDzw8grWyukaG6xFE8tllmr6+X4+W/CYWduWQNjKkw0CQ909CPghcEjwZI++gU/wxEogQesra+RrzuPBddwO6Pc/gihWbHdvn1brl27JnfupEJ2K2KNAvRR0yMXg1fJtFLvsZ+u3RCeyIfwUIZ9qta2jdJxj/jCtdWVxYByoWYT0zylMSm0aVbufF0nnOrUHDvIOZbsiE8p0vZl4G3KppbLpcA3deWpwzsbUe7l4CzjWx/X/skok2vvFfrg2iukoqFUfrfodzo8DCGiPhBCDxrvzLdCA2/evKmCu3r1asZ5+yNC/GnvTJXqpsqsoXASunZDeMJHeDofDUa1qEan68x4Y6Z+yUnno+VKjI08cvGwZgsxN8/W3c0o4mf1whGaaFi+41VZ98laDbns35F4KKsvlwntE+TH7h+NR+5OhWr5oPU6d4L78dTCp6SyyXjieMLDdoKXN1bLI/Mek075BTXQ9hoEZgmhXblyRS5duiQXL17MONe9iLrA+319/Rupasz8HpPQtRvCEz7Cs/zDy79XDwdPZDwSPInnCI4YUd7Jmyflsdax6kFwTrvsg+vVQIzs+OOSPwYPgWuC6TbGQ94M6vlHqQw9kDL4LJaIeOeTNYIugrwKDwkf67GC15EL/5Ki6Ub8caIOmLmOf+PhVbemTrr7uuSGiu1SJLbz58+rlxtIHcNvRB+KaHO7dUhC124IT+QiPDVyGzK1VUpVc7VMXjU5HHWSn7DNhlg244cw7Lllz0r13P47idGWsnUrmjFcvjj7efA5uLD0oWco65PTn0jJnGKT/reiba2Rilll2uem3Rw95nO2Lej/ADGmryn/ba+YzvdoyFd64gN1evpvT8tPt36Szs5O6Tz/s5w7dy62jMTAiGu4E7yq6qznzY2u3RCeyEV48fYBDAcpdBhzvkRnaMpCyNXRdVqqZ1fJqAUjNbR062PFVhk8BDCXbmzjeG1buaGuFRAIYf1w7aTU1o/U5As+ryNq4HlaRkjFzCq5Ho65TAnPPgh8aK4L3m/Cq+MCsZsHSbb7j+vFfD+Mfjn17w7j5Tz6IFF//EQmtaYh83xJ6NoN4YlsX/zdaQQw8+/TVRzmi838snOlBcJCTHpFVhRLPZgkSWp6Tpy1Qd2xktjfP1mtbZi4wPpjPPMHD9SwvkGn3NjVwfAT96RkWrns+36fes4k5d6NEDvONfm1lzShkjUBFCPqM7b5MbkahMruQ8SHqINdXjBXunZDeCI34aW8zvGrRzV97n65A6Wde7biwxWp9lp4LjsKJk6IEQOWD547EHrcnowQ0TL+u132Qd/Tvq8+2fCvjdr+smMeK+abdiB+H9s8Tg3WdnrnSuQq1x5ao90LeJCkQtzMawIRhm746j0T8kbtZZQ1sPOD9v5gacGy2SUZ50xC124IT+QmPEMkNm4EX6MaVh46pGH/nX2X5JGmR7XtCMPMVi+blkeCYPGHi+WmJk76vMIwEEDyBcvywTBTA59HmGTNtDJtG5plHuznsgvBhHVGMBjEvHDzQhVT+kDmMKup/Xq12h2CUBri3HJ8q3as3+0cidhrh9AZoj5v7H8zq4dNQtduCE9kM/B7Md/Cu37ruvy+7Q9Rn5c1DtfT4bxIy6MfzvZ7Wbpl5kIdBdKDvrRuuRKUbSecRp4veBigY35S64So/eeWEScyqXt/2KPdHqi3O3Ik3fhrNZv5wqoXNAtrw3cwXyN9kJi5FtQcDyy3Lknp2g3hiYEKD2GL+wXnSoy6QMbuwoULcqHzP3L19lX1LEjxZ+3oRZgGzxC0vw5fPKICMMLPj4FCwCrCQIIYEdO+YYGUzjIZUDPQ23jCiQueCNpfN5zPmgzsluObpbLBtBkz6h+jLh9RVyIN6+ZqtlFHWfamhpD5PkxQDro0UKeJCybqYG3bfnXrkoSu3RCeyPWLsMef6euIjCTX5AqA/ikIDj8vX76sHcQ6IuP6Nem4dloea3xMR/3r4OJs9Qi849Ov/CnwUHYERyq5ci+PlJRmyfXrUjWzOqhLeO5WM2gA03Be379SQ1QkhDq6z8johkfC8DGzvqB6zwVYYr5Ypq2aEpR8NRZW5s70+5/qNzUPjy75ovNLGTknFjZ70LUbwhO5CM+m72FAf131F81BDiQcQv8UxAbeuHFDR2fcunVLh0b1dPdpkgTh2s6vdwVhX//9Tqg71jw513NG/U3cGPNFACNmdh7fY7ogohEopo02ck6tNG6co94rasfhHoX9dKij7Qqpai6Xqlnl8otcNMmT2MDmgTB+ranvoUf+Iz/LpMUTo8EG+aBrN4QnchFenDCi5XuXC0b+36udZ4Hj4OHsUCiIDUz7fCxRAg+GjGLt7NqgjRXushNLUth1JzH8a/rb03VANrydjzH3R9QFWVeEwhh+huFyuHdWYKZtmhoRo55Rx2RW6RqZmBK0/V/b9Hp8w0iXtjyElft/OqDLE6a6R/JD124IT+QivHgaPOqDCgxsyQdLBUOu+gvx0JaLe7V7CTWTZszjm5+8KcPDhEV6ncIQODBydAsgPBxo+t9lXCRwUPbnraBGRy8dlRdff1GTMegfwwNAiX/PKNcpQujuMKNoUg8f26HtS9QN9xzh9rimcbogE8RuPWx//YQDoWs3hCdyEV5/xFMeo/53HNuhRqbtjbDjF9NYILzcxZZJGBrmmWF4l21rZavL8BlB+2vXG9rdkNaxnieDt9QEhpikCup17vZZOXPzlLb74B3zMTujP5p+z9vy+bkvpbgeXSCm39G9H/miazeEJ/IlPHzp5a2V8tu5j0Ydzjo/LZ9tLnU5yNTd1jC3ZGaRDq9y62MJr4MNToz3s8xS7gDZ38Ta+HvZ/j5ghg8OpE46eztlUtskHSqHazXLPVB4Qwb5EF6cGJ2BZcc/PLZLkxL5HPJkPZfpnjazrF9a+UL/mUR0fjdWypqP1wgGcudbeCqEUAzxkFT/HftbvohrRlJm5upZOuXJDKnr59rzTNduCE/kW3hxIgOIMYcIu7RtE7aRbPrbGFOmgeVCfP5mIMDGd+dJ0cxwUmyWulQ1V8qYOaPl5K3vTT0cUURiyXKOB8Zes4w7BIeO+7+uel7bkO613Q+6dkN4olDCQ7nIOmoYOqtSdn2/U9t/2uJKM3B/L2T6rbp1ZgLm4UXdHk5iQUf915fKP09sV2886ITWZ9uNfdECTujMx1Av9Bui/tnatfeDrt0QniiU8KJREqEAMHLikcaH5WzP2TC9B0PL72RZGCxCsYa355qEQ+T9Ulk+/RnUZXT9GDlz+7QadronfvDU2yNYsu+mtGyeb7op8pSdHChduyE8UTjhZRLGg47mXad2h9nPvrx7HXg/iA8z4rHlcrT4UTggWf8deA2k3Cvqy+SZV58JPfHgEJ5JHnXJ9m+26yJF2jWQbfjcfaZrN4Qn7qfw4kTSY2LrhCA4xJIRdzKM3v19oETK/clFT0nlnNB4sxix1mX++KAmFzRkvd8eEE7Xdkv88/h23Z/djhBy6/qg6NoN4YkHITwsNoTVyPDvYbOK5MjPh1UgvomW/ggP+FXnV7rnOWaZZ9bHpOKxJXP92/UqgEJ0P/RH1O9CIPsJbZN0TCgig0J2DQyErt0QnngQwgPjoyrK5lXKE21PaXgYhaCeTIk4lT3FYj8rPnstoy5p9Qq8zPjm8XL2BnZ8vR15v0IQXg6B8fyNC6S4rix6GEVt0QfcrovTtRvCEw9KeBkMQquSuiJpXNOgHkAze/h/FoNNxLAfzZZzOyhz4eaXpbwuMx2fGnaWSgjpsvMvPxuOrfSoRxbafkgMbXv+ledTU3WwDovNxsYGWg8GunZDeGLQCC8klrpDyn/K6sk65y8aepZDGGrHQuIzmOs2Zt7D0bZa/U0zykYd8Bxw7Pxxugx9ajsxE4bm2gbE8cChnw7psLfBkjhJQtduCE8MNuFZwuCx4NHqQ28lHP1ivZKZnQCRHA7ajhhFo+V5eI/aBaN1i2gMiMais+iA0CwoHgs5DAnD6Jn1X7yre7zbsgdTOHk3unZDeGLwCc+m/U3YB8Ns29wWmOyNuwow3qbDMgfPrfyrrtCsmcHQqwz0Ws2uO6YvDVOC1n25VsNE0wN47zYgwtXNX28xexjoTPA4B0/m8m507YbwxECN8X7Srii289tdJuPYA5M3IowPP4MwLwY+CYvaFjIriMwopv48ueQpWfv5Op0HiIHbSMagfghv0fn9zbVvZMmOJVIxsyJrNnUo0bUbwhNDQnjh7IfahTXax4Xl8rA4Kwgzx/ooi7Ys0p1m9TOhhyt0P5id+IqhcRXzK6Sipdww+LcuMY+JukOkDXcvunZDeGIoCM/S1hWrf/3vtP+Tx9vGy+8W/14emvKQJmUK6eXuThOGxmlDyKF0f+9G124ITww1w0CSxApM98AL1+FMP66wni4ivNmvxKPdi67dEJ4YasIjHwxduyE8QeGRSejaDeEJCo9MQtduCE9QeGQSunZDeILCI5PQtRvCExQemYSu3RCeoPDIJHTthvAEhUcmoWs3hCcoPDIJXbshPEHhkUno2g3hCQovRZ85e792unZDeILCM4yvAUNm0rUbwhP/zcLDjrPRRNn21O6zhZ5ONBTp2g3hiUEtvPsw8h97EVyUS7oCWWfwmvTyExnHkBRe3pFv4cFbVDdV6xIHYKKZ16HAarHnXfS5Qk65CT1acL51X61LW0gJOxBVtqa2W7b3J7USWfj7f1l70LUbwhP5Fh4WhcUuqAfO7pePzx6U/Rf2J2o7VbRUyhuHVsn+Hz+WfWc/loMXDslvF47NOC4ftMvnlc8pk1O9p6M1Wwy7paypNHub779o/p1L124IT+RLeNZIsfyCXQAIhoxFika01mQcHyeWSMAGi4dOfqLrpuCFdUseb5mYcWw+aPcmR73ePfIPXePSejwsKYiJtinR1UpVc7WueGaJ390yf+107YbwRL6EZxkXHogl7e4lPLC0pUwO/nAgEgG20Xq85fGsyznoWiax3yPvFHqkXHfXmb2hTtZ8+bZMWzdd91Gw9wQ/wdYN87U+WDIQKz9PWzVFqhfaY5IkYuLH1MbC1HAB3Yzj+6Hjbe2mlLlc60Dp2g3hiZy++AR0PV5+hZdu5PG6p7fBwuMShoX62aC9hyynCsMRU9t77WlLy09dOTUUfxLRpQQSnQv/1gdE5rF3Yzz8ja49fNC4x+abrt0QnhhKwkNddTUvZZWutwLD04WOwpW+0D4rnVcs5c1l+vdoc8xsnjN8z+zfblYHw+8wbnQt4HzwbK0bW8KNTMxSgpNfm5JaQSxhuw/nwApkqB9oRD5CP4stld3jXerDILyPqGdJc1BOY7GUNpamvG+Wa8wXXbshPDGUhFfeWikr9q2ULV9tkQ+ObJP3jrwnZQ0VMmz6QzJ51WTZemSrfHvpW+m4dko+/fFTWfrh0qx7JcQ5qmW0bD68OShzW/BzqzRsbjSZ2ZYR0r5tgSzdslS2f7odVxTt0vqP3e/K37Yslle3LNG/I0Ttz+ugrFFzH5blO1bI5z9+Iaevd8h3V76XHcd2yIy3ZsjwaeGShAmIzTYfnz9Bdh/bJd9d+kY3Vjlx6bgs3rxEu0UiMReArt0Qniik8OAdsIpyrsKDYBHaucLDU/5o59daPnC5+4rMfqceS9tGYWC8awDs7e3WLCtWgNZNQdrSQ7/RTaP1MxYbj25STwdDxr7j9jri+yS459hzao/UNsXblSZc/W3Lo3JVrumK0zguKiPc2wFAq3Hrd1v0vmULPXH9RdNL5fCFL/VYe363DqgjHnJYQFf3ZMDn5yffJ+JedO2G8MRQFJ41tu5eZD9hjCbtYTa9gsfsUcHZfQ3wt23f/VP7BnG9rvBQji0TwsP72DgFokGZqJFuOBIKB+cwOxrhZ4/sPvOR6X/UpI5JmDyx+EldaNeWa7w/VpjGatMmUWPFiPqd7PpOKupT/YeW8Lw3bDndweHdOCuuGzVAieG+8tF5uqWmLgyVce8ShMFJ6NoN4YmhJrwj549FRhYJMPhEp1yQtQfWSvs/FsrBU5+oUca9Asob3Tgq8AaZwrPHWY+H9yvnVcnLO5fIsn++Krs/32muKfRUm/Zu1PeXbVsur2x/VWb+Y4aMbDWig7crnVmuHfFW+Dj3z93/kRdfe1HGzBkt41rG6+exzLsVDULZtz99S4VmkzvYLGXioifThIWyXt60SH7bNFZG1o2UJ4LQ8xe5qDK0x1wNzl00syinnZHuRdduCE8MbeEZjzP1jWlSMqdYj8H1YKn38mllavzqH3rN9so7ftip4eY9hRd5CZO0adswX3Ame16b1YxnFqNrCco/fOVLFRLqh9fqvW+qB9UkSHu4tHtwbNGUokAyl6Nz417V1ptEC8RXMqMk8Lk3zT5/wSFdwWvGm9N1IV97X1AmRLb1X5sFmzn3dBtv3L6xzZwrT9+vazeEJ/L1xdhy8iE8+2Qf33p34eHYQ6f2Z6T/LbFFF4zVHo8dfpBsuafwwr/ZvRHQnaChYejxkNV0Qzh7/djbIbWrUY+KP9oHLwuLpherd7be8cgvR0yms22UrP50tZaB94Mj5PEFE2TkolHms2i/xcsKfl974J3o/t0OXmXo7M/T9+vaDeGJfH0xthw8fePCQzsnifAgqgPf708THjJ47jHpwuuSSW2TMsqKjp9dFoRdV6LjsaMP2lG5CA8/kwgPRBg7bOow6e1JXf/Wg1v0nP3RPBxuR2Uj/NSRPPXlcur2qeh9PEAeeu43UlWHz1VllFM+J7iul0Zoqw/tRvx8esmfKbzBinx9Mf0JL6nHg6gOnTwYCQ8hJNpC7jFx4cEYsX0XvCLOHyeOR3jX0XU6EhYSGzDcQgkP78FLm2swITMCP3gf1BXD4OIvvIcXPKRN3OBd9D9iGzBs/2Xr1q3ht/3Erehf6e+gnZcK1ZvWNmeM8hkoXbshPJEv4RnWStGsYTCjNHFY4cVHXsSJ90oaSuRE5zdGAPrE7oraO5ZZhRcYqFueJQZBd3Sdih1/K/AwyUNNSys8/GeF5xo0OvErgrbXUwufMudDuyxs59nz90uUGxIyrQjKRkh8PRAe/h7fdVaRYAtotPMWffByxrUMlK7dEJ7Iq/CCJz5GZ6T2CkeqvCcQR0m/7TAQRvybl36jXsAaKrxEtN9dyHwIL5c2nmUS4ekomeBeVtePSBPAwWMH5YXlLyXmlDde0uQJ6nlBfkkT0nMLn9HMqPuZDK54QV5a+ZI81v4YQ83Binx9MRED8SGhkBJer0xcYGYZ9OvxAkNrWd8cpcQRLB2/dEJnLMSPG8zCsxw+8yGtvzkn2rjXzUiYheYBE2f8vejfYTIJ3RO7Tu3UOlnhjWsbb0LpQOQQepy2HPwbZdkHgVu/gdK1G8IT+fpyMErfjtTfcnxrZOzgZbkkwyc/pKLLdj6k1SEKG6KirVL397qMsYcPTHhhd4IN8Wa/OStTeLbNF/xE1zrCRtM53i1lU8uzenz73qS/TYgm/ur40/DvmA0fH5VzXn4OIoNh4cMrVl6Y2ayaVyUTlk4I9w2s1vDXPedA6doN4YlsQvDlmHmjNRFgn9YwbCyrMK5lrPZNVTdV6iz1yoZqKZ5arGl+9RKhR8HvmPfmzvJ+UMJ77pVnVHg2DP6s4zMpnm36DdFVUFJXpH2HavyBIHed2q1ladssuCbM8Xti4ZOaZa1tqYk8f0ldiTzS9KgmoDDUy52tj8zmT8FL669txh75d+85fVChHPQZ4vyVTRWaTd3+zXYd5WLrlk3sA6VrN4QnCiE8Nay6Wg05rfhAM8G1WwVjcnDd+p79OwADR9+WjneMCQR8UMKDsG5qosMID8enMomQDZI2KU+Fh8rqQ2+JGc6WGleJ7g/zwidv6cNJM5oQafA6LSeDh1FlmmAwxhRH23PDiyLsTZ05VY49BuKrmFsRjk3Nj/hcuyE8UQjhgegAHjPvYcEiQtbwjWHY9k8mMYpx4Ycvq+Flaws+COFpPQJP9pdlz6qB2+vAy4aewBsHXpeReOCol67VCbWv7F6u59TPhN7chqC2TjoGNAAeUrhf7hQm/D5+/rhoFE76PTNdB1pmXyq6eHXnq1EZ2e7jQOjaDeGJQgnPsmRGmVwMwkx4NwPzZMbAZNgLDAWJg+M3TsjYwMBcLxcn5rF93XlMy8BnzeiM4qzGhfYmOpVP9/wYnRfeAZ3P8eNg7D36V8MNxyA8M9DZUttLQRj44usvGi8eExwMHn78o592qbdKeWpDhJLXg/NqcsYi/Lw5Z5+2idEfme06QIST+Pv6w+uDsm5qEUb6qVLRlsRsihV7XkvUb5orXbshPFFo4eGJje6ER5sf0XbMRx275djl43L00lGdroOBwRhNXzE3XOMySxmWqOuM9dOk6f1GadrUIk3bmqWquf+BwEhYzNw4Kzi+yXBbazQ1yBLZQ/v35g+a5S/v/CWjHD134EFGtY+WYdOHy7I9y2THDx/Kx2f2yaYjG/XakNiICyf+b7Rrn1z0hCzdvUS2nNgiezv2yqav35cF2xfIY61jzcDo0LO657XnVg/WatZ+mbepUeciftSxR5D5XLFvhfx52Z80RL/bg8uHrt0Qnii08OK0xhh5kygzmMxYUnUN1yoJDTXbNaRn/szPbMe5TDsmixDiaftsf7e0CRTzuzm/htBOwih+Tfe6D2mfbQ+FHmY04+cpBF27ITyRxBgHynShpQwr/lS2509UD0dod/tMZPThZzKNNDvj3QT9dRlEokcWsz1dEPa86cI314z34u03+wDqL8TMRpxLGd3P1EMoOuc9rnEgdO2G8MTdjJckLV27ITxB4ZFJ6NoN4QkKj0xC124IT1B4ZBK6dkN4gsIjk9C1G8ITFB6ZhK7dEJ6g8MgkdO2G8ASFRyahazeEJyg8MglduyE8QeGRSejaDeEJCo9MQtduCE9QeGQSunZDeILCI5PQtRvCExQemYSu3RCeoPDIJHTthvAEhUcmoWs3hCcoPDIJXbshPEHhkUno2g3hCQqPTELXbghPUHhkErp2Q3iCwiOT0LUbwhMUHpmErt0QnqDwyCR07YbwBIVHJqFrN4Qn3BtMktno2g3hiUIu+03+eujaDeGJQm1yQf56CBtx7YYgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCIIgCILIN/4fE/ht58Lb9LsAAAAASUVORK5CYII=>