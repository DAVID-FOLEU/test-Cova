 Test-Cova — Documentation Technique & Architecture

Ce projet propose une solution applicative multi-plateforme complète. Il se compose d'une application Web développée en React (TypeScript & Tailwind CSS), d'une application mobile native développée en Flutter (Dart), et d'une API REST centrale construite avec Java Spring Boot.

1. Architecture du Système

L'architecture suit un modèle client-serveur totalement découplé, où chaque client (Web et Mobile) communique indépendamment avec le backend Spring Boot via des requêtes HTTP/HTTPS au format JSON.

Composants et flux de l'architecture :

1.1 Client Web (React + TypeScript + Tailwind CSS) :
   - Application Web Single Page (SPA) typée avec TypeScript et mise en forme avec Tailwind CSS.
   - Consomme l'API REST backend pour les parcours web et la gestion d'administration.
   - Envoie les requêtes sécurisées en injectant le jeton JWT dans l'en-tête `Authorization: Bearer <token>`.

1.2 Client Mobile (Flutter + Dart) :
   - Application mobile multi-plateforme (Android & iOS) partageant une base de code unique en Dart.
   - Interagit directement avec la même API REST backend que la version Web.
   - Adapte dynamiquement l'URL de l'API selon la plateforme et le mode d'exécution (émulateur Android, appareil physique ou release).

1.3 Backend API (Spring Boot) :
   - Couche Sécurité (Spring Security) : Intercepte les requêtes, valide les jetons JWT stateless et gère le filtrage des origines autorisées via la politique CORS.
   - Couche Contrôleur (REST Controllers) : Expose les endpoints REST de l'application (`/api/auth`, etc.) et orchestre la sérialisation JSON.
   - Couche Service : Implémente la logique métier centrale commune aux clients Web et Mobile.
   - Couche Accès aux Données (Spring Data JPA) : Gère le mapping objet-relationnel (ORM) pour persister et requêter les données.

1.4 Base de Données :
   - Base relationnelle (MySQL) assurant la persistance des données utilisateurs, droits et entités métier.


2. Choix Techniques

* React + TypeScript + Tailwind CSS (Web) : Choisi pour la réactivité de l'interface, le typage strict garantissant la fiabilité du code en production, et la rapidité d'intégration UI offerte par Tailwind CSS.
* Flutter + Dart (Mobile) : Choisi pour déployer une application mobile fluide sur Android et iOS avec une maintenance simplifiée sur un seul codebase.
* Spring Boot (Java) : Choisi pour le backend en raison de sa sécurité robuste (Spring Security + JWT), sa maturité en environnement de production et la clarté de son organisation en couches (Controller - Service - Repository).


3. Évolution de l'Infrastructure (De GCP vers Railway, Vercel & Firebase)

 L'approche initiale sur GCP
Initialement, l'hébergement de l'intégralité du projet était prévu sur Google Cloud Platform (GCP), en exploitant Cloud Run pour l'API Spring Boot et Google Cloud Storage / App Engine pour la partie Web.

 Les difficultés rencontrées
Pendant la mise en œuvre, la gestion fine des rôles IAM, la configuration des comptes de service pour le pipeline CI/CD et la gestion des quotas GCP ont généré des blocages et de la complexité inutile. Les temps de démarrage à froid (*cold-start*) sur les petites instances ralentissaient également les itérations de test.

 La solution retenue
Afin de fluidifier le déploiement continu et accélérer les livraisons, l'infrastructure a été réorientée vers des services ciblés et agiles :

* Backend API (Railway) : Le service Spring Boot est déployé sur Railway. La plateforme gère automatiquement le build, les variables d'environnement et fournit un point d'accès HTTPS sécurisé sans surcouche de configuration IAM complexe.
* Frontend Web (Vercel & Firebase Hosting) : L'application React est hébergée sur Vercel , profitant d'un CDN mondial ultra-rapide et d'un déploiement automatisé à chaque `git push`.
* Mobile (Flutter) : Compilé et distribué pour  Firebase Hosting, pointant en production directement sur l'API Railway.


 4. Configuration Dynamique de l'URL d'API

Côté Mobile (Flutter / Dart)
L'URL de l'API bascule automatiquement sur l'instance de production Railway en mode release :

```dart
import 'package:flutter/foundation.dart';

String get apiBaseUrl {
  // Mode Production (Build compilé en release via GitHub Actions / CI)
  if (kReleaseMode) {
    return '[https://test-cova-production.up.railway.app/api](https://test-cova-production.up.railway.app/api)';
  }

  // Mode Développement Local
  if (kIsWeb) {
    return 'http://localhost:8080/api';
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return '[http://10.0.2.2:8080/api](http://10.0.2.2:8080/api)'; // IP loopback pour l'émulateur Android
  }
  return 'http://localhost:8080/api';
}
