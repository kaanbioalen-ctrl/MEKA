# Current Status and Daily Plan

## 1. Mevcut Durum

Bu durum tespiti 2026-03-09 tarihinde mevcut Godot proje dosyalari okunarak cikarildi.

### Calisan kisimlar
- World scene aciliyor ve `res://scenes/world/world.tscn` ana sahne olarak ayarli.
- Player hareketi calisiyor.
- Player enerji sistemi calisiyor.
- Enerji sifirlandiginda olum akisi ve retry ekrani calisiyor.
- Asteroid benzeri dusman spawn akisi calisiyor.
- Dusmanlar damage aura icinde hasar alip yok olabiliyor.
- Dusman yok olunca enerji pickup'i dusuyor.
- HUD uzerinde enerji yuzdesi gosteriliyor.

### Kismen hazir kisimlar
- `ZoneManager` var, dunya boyutunu kuruyor ve debug grid cizimine destek veriyor.
- `RunState` autoload baglandi.
- Asteroid spawner aktif ama henuz GDD'deki `EnemyDirector` mantigini temsil etmiyor.

### Henuz baslanmamis veya bos iskelet durumda olan kisimlar
- `MiningSystem` bos.
- `EnemyDirector` bos.
- `PerkSystem` bos.
- Material ekonomisi yok.
- Multiplier/chain sistemi yok.
- Zone unlock ve zone progression yok.
- Run ici perk secim UI yok.
- Combat build progression yok.
- Veri odakli `Resource` setleri henuz kurulmamis.
- Test otomasyonu veya dogrulama checklist'i henuz yok.

### GDD ile mevcut proje arasindaki net farklar
- Grid hedefi artik `5x5` ve kodla uyumlu.
- GDD'de `mine -> drop -> combat -> perk -> zone unlock` loop'u hedefleniyor, mevcut build daha cok `move -> survive -> aura ile hasar -> enerji topla` durumunda.
- `RunState` autoload baglandi, ama henuz material ve multiplier gercek gameplay sistemleriyle beslenmiyor.

## 2. Genel Durum Ozeti

Proje su anda "foundation prototipi" asamasinda.

Tamamlanan seyler:
- Hareket hissi
- Basit hayatta kalma baskisi
- Temel enemy/pickup dongusu
- Olum ve yeniden baslatma akisi

Eksik olan kritik seyler:
- Asil mining loop
- Run ekonomisi
- Perk secimi
- Zone ilerlemesi
- Dengeleme icin veri yapisi

Sonuc:
- Oynanabilir bir teknik prototip var.
- GDD'deki asil oyun kimligi henuz uygulanmis degil.
- En dogru sonraki adim, yeni icerik eklemek degil; once core loop'u tamamlamak.

## 3. Her Gun Yapilacak Liste

Asagidaki plan, mevcut durumdan hareketle yaklasik 3 haftalik kisa tamamlanma plani olarak hazirlandi. Her gunun sonunda calisan bir cikti alinmasi hedeflenmeli.

### Gun 1 - Scope sabitleme
- GDD icin tek bir "prototype scope" karari ver.
- Zone grid hedefini sabitle: `5x5` / `25` ekran.
- Prototype icin kesin minimum listeyi sabitle:
  - 2x2 aktif zone
  - 3 asteroid tipi
  - 2-4 enemy davranisi
  - 10 perk
- `CURRENT_STATUS_AND_DAILY_PLAN.md` dosyasini ekip referansi olarak kabul et.

Done kriteri:
- Prototype kapsaminda neyin var neyin yok oldugu tek sayfada net.

### Gun 2 - Teknik duzeltme gunu
- `RunState` autoload baglantisini tamamla.
- `ZoneManager` grid kararini GDD ile uyumlu hale getir.
- `World` scene node yapisini hedef mimariye gore temizle.
- Debug bilgiler icin gecici HUD alanlari ekle:
  - run time
  - material
  - multiplier
  - aktif zone

Done kriteri:
- Projede temel state tek yerden okunuyor ve debug ekraninda gorunuyor.

### Gun 3 - Mining temel v1
- Asteroid kavramini enemy kavramindan ayir.
- Kazilabilir asteroid entity olustur:
  - HP
  - mining resist
  - drop amount
- Player'in mining etkileşimini tanimla.
- `MiningSystem` icine ilk gercek akisi koy.

Done kriteri:
- Oyuncu en az bir asteroid tipini kirip material dusurebiliyor.

### Gun 4 - Material ekonomisi v1
- Toplanan drop'lari `RunState.materials` icine bagla.
- Material pickup davranisini netlestir.
- HUD'da material sayacini goster.
- Mining ve material toplama arasindaki akisi test et.

Done kriteri:
- "Mine -> drop -> collect -> material artisi" zinciri kesintisiz calisiyor.

### Gun 5 - Multiplier/chain sistemi v1
- Ardarda mining veya hizli kill ile artan multiplier tasarla.
- Hata, bekleme veya hasar durumunda multiplier reset/azalma kuralini ekle.
- HUD'da multiplier'i okunur goster.

Done kriteri:
- Oyuncu hizli oynayinca odul artisini hissedebiliyor.

### Gun 6 - EnemyDirector v1
- Mevcut `asteroid_spawner` mantigini `EnemyDirector` ile degistir veya onun altina al.
- Zamana gore spawn baskisi ekle.
- Oyuncu gucune gore daha sonra genisletilecek hook'lari koy.

Done kriteri:
- Run suresi arttikca dusman baskisi belirgin sekilde artiyor.

### Gun 7 - Combat netlestirme
- Aura damage gecici cozum ise bunu bilincli prototip karari olarak sabitle ya da ilk auto-fire sistemini ekle.
- Combat ile mining rollerini ayir.
- Dusman hasar geri bildirimi ve olum okunurlugunu iyilestir.

Done kriteri:
- Oyuncu dusmanla savasiyor mu, asteroid mi kiriyor, ikisi ekranda net ayriliyor.

### Gun 8 - Zone progression v1
- En az `2x2` aktif zone akisini kur.
- Komsu zone unlock mantigini ekle.
- Zone bazli spawn ve asteroid yogunlugu farklarini veriye bagla.

Done kriteri:
- Oyuncu haritada ilerledigini ve yeni bolge actigini hissediyor.

### Gun 9 - Perk system v1
- `PerkSystem.roll_perk_choices()` icini gercek veriyle doldur.
- 3 secenekten 1 perk secim UI'si yap.
- Ilk 6-10 perk'u sadece sayisal etkilerle ekle.

Done kriteri:
- Run sirasinda perk seciliyor ve oynanisa etkisi aninda hissediliyor.

### Gun 10 - Core loop baglama gunu
- Tum akisi birlestir:
  - mine
  - drop
  - collect
  - survive/combat
  - perk
  - zone unlock
- Olumden sonra state resetini kontrol et.

Done kriteri:
- En az 8-10 dakikalik tam run akisi kirilmadan oynanabiliyor.

### Gun 11 - Icerik ekleme gunu
- 3 asteroid tipi tamamla.
- 2 yeni enemy varyanti ekle.
- Farkli drop/Hp/hiz degerlerini `Resource` veya veri tablosuna tasi.

Done kriteri:
- Ekranda tekrar hissi dusuyor, oyuncu farkli hedefler goruyor.

### Gun 12 - UI ve readability
- HUD'i duzenle:
  - HP/energy
  - material
  - multiplier
  - timer
  - zone
- Perk secim ekranini okunur hale getir.
- Kritik hit, collect ve death feedback'lerini belirginlestir.

Done kriteri:
- Oyuncu ekrana bakip ne olup bittigini rahat anliyor.

### Gun 13 - Balance pass 1
- Spawn, asteroid HP, drop miktari, enerji kazanimi degerlerini ayarla.
- Ilk 3 dakika ogrenme, 3-10 dakika build olusumu, 10+ dakika baski hedeflerine gore test et.
- Not tut:
  - fazla zor
  - fazla kolay
  - sikici bekleme
  - anlamsiz oduller

Done kriteri:
- En az bir run "potansiyel olarak eglenceli" hissettiriyor.

### Gun 14 - Bug fixing ve stabilite
- Crash, null reference, reset bug, spawn tasmasi, UI kopmasi gibi temel sorunlari temizle.
- 20 dakikalik uzun test yap.
- Olum -> restart -> yeni run akisini tekrar tekrar dene.

Done kriteri:
- Bariz teknik kirilmalar olmadan arka arkaya run oynanabiliyor.

### Gun 15 - Dis test hazirligi
- Kisa test checklist'i yaz.
- Test oyunculari icin tek paragraf aciklama hazirla.
- Geri bildirim formu icin sorulari cikar:
  - en keyifli kisim neydi
  - en sikici kisim neydi
  - perk farki hissedildi mi
  - mining ile combat dengesi nasil

Done kriteri:
- Dis test icin hazir bir vertical slice build tanimi var.

## 4. Gunluk Calisma Ritmi

Her gun ayni kisa rutin kullanilmali:

1. 15 dk: onceki gunden kalan bug ve notlari oku.
2. 90-120 dk: gunun tek ana sistem gorevini bitir.
3. 30 dk: playable test yap.
4. 15 dk: ne bozuk, ne eksik, ne ertelendi yaz.
5. 10 dk: ertesi gunun ilk gorevini netlestir.

Kural:
- Bir gunde birden fazla buyuk sistemi yarim birakma.
- Once calisan minimum versiyon, sonra polish.
- Yeni icerik eklemeden once core loop'u ayakta tut.

## 5. En Yakin Oncelik Sirasi

Bugun hemen yapilmasi gereken sira:

1. Grid hedefini sabitle (`5x5` / `25` ekran).
2. `RunState` autoload baglantisini tamamla.
3. Gercek `MiningSystem v1` uygula.
4. Material ve multiplier'i HUD'a bagla.
5. `EnemyDirector v1` ile zaman bazli baski kur.
6. `PerkSystem v1` ve 3 secenekli perk UI ekle.

Bu alti madde tamamlanmadan proje hala "teknik temel prototip" seviyesinde kalir.
