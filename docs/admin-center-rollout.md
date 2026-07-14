# Marino Yönetim Merkezi rollout runbook

## Güvenlik sınırı

`marino_admin_memberships` tek canonical otoritedir. Eski `marino_admin_roles` ve
`content_admin_users` tabloları yalnız private uyumluluk aynasıdır; istemci rolleri
bu tablolara doğrudan erişemez. Frontend, `marino_admin_me()` olumlu cevap vermeden
Yönetim Merkezi girişini göstermez. DOM görünürlüğü hiçbir RPC yetkisi sağlamaz.

Owner Telegram ID kaynak koda veya frontend artifactına yazılmaz. Migration sonrası
owner ataması yalnız service-role oturumunda aşağıdaki RPC ile yapılır:

```sql
select public.marino_bootstrap_owner('<VERIFIED_NUMERIC_TELEGRAM_ID>');
```

Fonksiyon, son 24 saatte doğrulanmış `marino_identity_links` kaydı yoksa fail-closed
olur. Sahte Auth kullanıcısı oluşturmaz ve mevcut owner yerine başka kullanıcı seçmez.
Çağrı idempotenttir; farklı ikinci owner reddedilir. Bu komutu SQL Editor'de sıradan
authenticated kullanıcıyla çalıştırmayın ve numeric ID'yi Git geçmişine koymayın.

## Uygulama sırası ve durma kriterleri

1. Geri yüklenebilir production backup veya PITR noktası doğrulanır. Yoksa durulur.
2. `supabase migration list --linked` yalnız `008`, `009`, `010` dosyalarını pending
   göstermelidir. Başka dosya varsa durulur.
3. `supabase db push --linked --dry-run` aynı üç dosyayı göstermelidir.
4. Migration'lar forward-only uygulanır. Herhangi bir hata olursa UI deploy edilmez.
5. `supabase db lint --linked --level error` sıfır hata vermelidir.
6. ACL/RLS negatif testlerinde anon ve authenticated doğrudan yazma reddedilmelidir.
7. Doğrulanmış owner numeric Telegram ID güvenli operasyon kanalından alınır ve
   `marino_bootstrap_owner` yalnız bir kez service-role ile çağrılır.
8. `marino_admin_me()` owner oturumunda `is_admin=true`, `role=super_admin`,
   `is_owner=true` dönmeden frontend production deploy edilmez.

## Duyuru teslimatı

Realtime yalnız `announcement_id`, `version`, `refresh|stop` içeren steril sinyal
tablosunu taşır. Başlık, hedef kuralı, Telegram ID veya admin UUID Realtime payload'ına
girmez. İstemci sinyal aldığında hedeflemeyi `auth.uid()` ile yapan oyuncu RPC'sinden
yeniden okur. Bağlantı koparsa sınırlı exponential-backoff polling devreye girer.

## Geri alma

Frontend değişikliği önceki Pages artifact/commit yeniden deploy edilerek geri alınır.
Migration'lar veri kaybına yol açacak otomatik down migration içermez. Acil durumda
yeni gateway fonksiyonlarının authenticated EXECUTE yetkileri revoke edilir ve
duyurular durdurulur. Tablo/fonksiyon silme ancak doğrulanmış backup sonrasında ayrı,
incelenmiş forward migration ile yapılır.

## Bilinen sınırlar

- Reddedilen admin denemeleri transaction içinden immutable audit tablosuna yazılamaz;
  PostgREST/Edge logları ayrıca saklanmalıdır.
- `event_participants` hedefi şema hazır olana dek fail-closed davranır.
- Telegram Bot kampanya gönderimi bu değişikliğin parçası değildir; açık onay ve ayrı
  rate-limit olmadan bot mesajı gönderilmez.
- Harici duyuru URL'leri desteklenmez. Yalnız internal action allowlist aktiftir.
