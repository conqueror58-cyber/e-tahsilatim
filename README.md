# e-Tahsilatım — ilk çalışan başlangıç sürümü

Bu proje React + Vite + Supabase ile hazırlanmış başlangıç uygulamasıdır. Cari hesap, tahsilat/ödeme, Excel dışa aktarma ve XML/UBL dosyalarını önizleyip inceleme listesine kaydetme ekranlarını içerir.

## 1) Ön koşullar
- Node.js 20 veya üzeri
- Mevcut Supabase projeniz
- Mevcut Vercel/GitHub projenizi değiştirmeden önce yedek/ayrı branch

## 2) Supabase kurulumu
1. Supabase Dashboard → SQL Editor bölümünü açın.
2. `supabase/schema.sql` dosyasını gözden geçirin ve önce mevcut projenin yedeğini alın.
3. ÖNEMLİ: Eski tablolarınızda cari/makbuz verisi varsa bu SQL `company_id` alanları ekler ancak eski satırları otomatik şirkete atamaz. RLS açılınca `company_id` NULL eski satırlar kullanıcıya görünmez. Önce eski kayıtların hangi şirkete ait olduğu netleştirilmeli; canlı veri üzerinde gelişigüzel çalıştırmayın.
4. SQL'i test projesinde çalıştırıp sonuçları kontrol edin.
5. Supabase Authentication → URL Configuration içinde uygulama adresinizi ekleyin. İlk testte e-posta doğrulama ayarını ihtiyacınıza göre kontrol edin.

## 3) Yerel çalıştırma
Proje klasöründe terminal açın:

```bash
npm install
```

`.env.example` dosyasını `.env` olarak kopyalayın ve değerleri doldurun:

```env
VITE_SUPABASE_URL=https://PROJE_ID.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Sonra:

```bash
npm run dev
```

## 4) Vercel'e dağıtım
- Dosyaları ayrı bir GitHub dalına veya yeni test reposuna gönderin.
- Vercel'de projeyi bağlayın.
- Project Settings → Environment Variables içine `VITE_SUPABASE_URL` ve `VITE_SUPABASE_PUBLISHABLE_KEY` ekleyin.
- Build command `npm run build`, output directory `dist`.

## Güvenlik ve kapsam notları
- Tarayıcıda yalnızca publishable/anon key kullanılır. `service_role` veya secret key asla istemciye konmaz.
- SQL, şirket bazlı RLS politikaları için başlangıçtır; mevcut üretim verisiyle uygulanmadan önce test edilmeli ve eski satırlar güvenli biçimde şirkete bağlanmalıdır.
- İlk kayıt tetikleyicisi şirket ve yönetici profili oluşturur. Mevcut kullanıcıların profilleri otomatik olarak doğru şirkete bağlanmaz.
- Bu sürümde abonelik tabloları başlangıç olarak bulunur; yönetici ödeme onay ekranı, paket yönetimi, personel daveti/limit zorlaması henüz tamamlanmış değildir.
- XML/UBL içe aktarma ilk sürümünde dosya metni tarayıcıda okunur ve temel alanlar çıkarılır. GİB'e bağlanmaz, e-Fatura portalına giriş yapmaz ve her UBL varyantını tam çözümlediği garanti edilmez. İnceleme ve muhasebe doğrulaması gerektirir.
- Excel dışa aktarma gerçek `.xlsx` dosyası oluşturur. Cari bakiye hesaplama, tahsilat iptali/düzeltme geçmişi, yetki matrisi ve abonelik sunucu tarafı kontrolleri sonraki geliştirme adımlarıdır.
