# turkpin-ruby

[![test](https://github.com/buluterol/turkpin-ruby/actions/workflows/test.yml/badge.svg)](https://github.com/buluterol/turkpin-ruby/actions/workflows/test.yml)

Turkpin bayi API'si için Ruby istemcisi: e-pin oyun ve ürün listesi, sipariş verme, sipariş durumu, sipariş listesi ve bakiye.

> Bu paket topluluk tarafından yazılmıştır; Turkpin'in resmi paketi değildir. API'nin güncel ve bağlayıcı tanımı için [dev.turkpin.com](https://dev.turkpin.com) dokümanına bakın.

Diğer diller / Other languages: [PHP](https://github.com/buluterol/turkpin-php) · [Node.js](https://github.com/buluterol/turkpin-node) · [Python](https://github.com/buluterol/turkpin-python) · [Go](https://github.com/buluterol/turkpin-go) · [Java](https://github.com/buluterol/turkpin-java) · [.NET](https://github.com/buluterol/turkpin-dotnet) · [Ruby](https://github.com/buluterol/turkpin-ruby)

## Gereksinimler

Ruby 2.6+, yalnız standart kütüphane (net/http, rexml)

## Kurulum

```ruby
gem "turkpin", git: "https://github.com/buluterol/turkpin-ruby"
```

Paket RubyGems'te yayınlı değil; `Gemfile` içine yukarıdaki satırı ekleyin.

## Kullanım

```ruby
require "turkpin"

tp = Turkpin::Client.new(username: ENV["TURKPIN_USER"], password: ENV["TURKPIN_PASS"], test: true)

games = tp.games
products = tp.products(games.first.id)

begin
  order = tp.create_order(game_id: games.first.id, product_id: products.first.id, quantity: 1)
  if order.pending?
    info = tp.order_status(order.order_no) # info.status == Turkpin::OrderStatus::COMPLETED olunca kodlar gelir
  end
  order.epins.each { |e| puts e.code }
rescue Turkpin::Error => e
  puts "Hata #{e.code}: #{e.message}"
end

puts tp.balance.balance # BigDecimal
```

## Desteklenen komutlar

| API komutu | Açıklama |
|---|---|
| `epinOyunListesi` | Oyun listesi |
| `epinUrunleri` | Bir oyunun e-pin ürünleri (stok, fiyat, min/max adet, ön sipariş, barem) |
| `epinSiparisYarat` | Sipariş verme (karakter adı, ön sipariş ve barem tutarı isteğe bağlı) |
| `siparisDurumu` | Sipariş durumu ve teslim edilen kodlar |
| `siparisListesi` | İki tarih arasındaki siparişler (en çok 30 gün) |
| `balance` | Bakiye, kredi, bonus ve harcama |

Listede olmayan komutlar için istemcideki genel `call` metodu kullanılabilir.

**Sipariş durumları (`SIPARIS_DURUMU`):** 1 işleniyor, 2 tamamlandı, 3 iptal, 99 teslimatta, 199 ön sipariş teslimatta. `DURUM_KODU` 999 ise Turkpin siparişle ilgili bir sorunu inceliyor demektir; iptal sebebi ya da not `EKSTRA` alanında gelir.

**Ön sipariş ve barem:** Ürünün `pre_order` alanı `true` ise sipariş ön sipariş olarak verilmelidir. Barem tutarlı ürünlerde tutar `min_barem` ile `max_barem` arasında, `barem_step` adımlarıyla seçilir. Bu siparişlerin sonucu `Pending` döner; kodlar için sipariş durumunu sorgulayın.

**Hatalar:** API `000` dışında bir hata kodu döndürdüğünde istemci, kodu ve açıklamayı taşıyan bir hata fırlatır. HTTP ya da XML hatalarında kod boştur.

## Test ortamı

- Test: `https://www.turkpin.net/api.php`, canlı: `https://www.turkpin.com/api.php`.
- Test ortamına erişmek için sunucu IP adresinizin Turkpin'e tanıtılması gerekir; tanıtılmamış IP'ler 403 alır. Test hesabı ve IP tanımı için [dev.turkpin.com](https://dev.turkpin.com) adresindeki iletişim bilgilerini kullanın.
- Kullanıcı adı ve şifreyi koda yazmayın; ortam değişkeni ya da gizli anahtar deposundan okuyun.

## Geliştirme

Testler gerçek API'ye bağlanmaz; örnek XML cevaplarıyla çalışır.

```sh
bundle install
bundle exec rake test
```

## English

Ruby client for the Turkpin dealer API (e-pin games, products, orders, order status, order history, balance). Community-maintained, not an official Turkpin package; see [dev.turkpin.com](https://dev.turkpin.com) for the authoritative API reference. The sandbox (`turkpin.net`) only accepts requests from IP addresses registered with Turkpin. Install and usage are shown above; method names are in English, while API command and field names follow the original Turkish API.

## Lisans

MIT
