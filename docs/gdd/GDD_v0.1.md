# NEON MINING GAME - GDD v0.1

## 1) Oyun Kimligi
- Tur: 2D top-down roguelike mining survival
- Platform: PC (Steam), single-player
- Hedef: 2-3 ay playable prototype, 6-9 ay release
- Referans: Vampire Survivors, Nova Drift, Geometry Wars

## 2) Core Loop
1. Asteroid mine et
2. Material topla
3. Dusman baskisi artar
4. Chain/multiplier buyur
5. Perk sec
6. Mining/combat gucu artir
7. Yeni zone ac
8. Run sonuna kadar hayatta kal

## 3) Harita ve Zone
- 5x5 zone grid = 25 zone
- Her zone ~16 ekran
- Player merkezli kamera
- Zone tehdit/icerik yogunlugu farklilasir

## 4) Sistemler
- Mining: asteroid HP, resist, drop table, kritik kazma
- Combat: auto/semi fire, menzil, cooldown, projectile
- Enemy Director: sure + player gucune gore spawn
- Perk: ~30, 3 rarity, sinerji odakli
- Progression: 15-25 dk run

## 5) Icerik Hedefleri
- Zone: 25
- Enemy: 8-12
- Asteroid: 6-8
- Perk: ~30

## 6) Teknik Mimari
- Engine: Godot 2D, GDScript
- Ana birimler: World, Player, EnemyDirector, ZoneManager, MiningSystem, PerkUI, RunState
- Veri: Resource tabanli (perk/enemy/asteroid)

## 7) Denge Prensipleri
- 0-3 dk: ogrenme
- 3-10 dk: build kimligi
- 10+ dk: yuksek baski
- Multiplier: hizli oyunu odullendir, hatayi cezalandir
