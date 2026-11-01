require "bigdecimal"
require "date"
require "net/http"
require "rexml/document"
require "uri"
require_relative "turkpin/version"

# Turkpin dealer (bayi) API client. Docs: https://dev.turkpin.com
module Turkpin
  LIVE_URL = "https://www.turkpin.com/api.php".freeze
  TEST_URL = "https://www.turkpin.net/api.php".freeze

  # Values of SIPARIS_DURUMU returned by siparisDurumu and siparisListesi.
  module OrderStatus
    PROCESSING = 1
    COMPLETED = 2
    CANCELLED = 3
    DELIVERING = 99
    PRE_ORDER_DELIVERING = 199
  end

  # API error code other than "000", or an HTTP / XML failure (code is then empty).
  class Error < StandardError
    attr_reader :code

    def initialize(message, code = "")
      super(message)
      @code = code
    end
  end

  Game = Struct.new(:id, :name, keyword_init: true)
  Epin = Struct.new(:code, :description, :id, keyword_init: true)
  Balance = Struct.new(:balance, :credit, :bonus, :spending, keyword_init: true)

  # max_order 0 means no upper limit; min_barem/max_barem/barem_step are set for tiered products only.
  Product = Struct.new(:id, :name, :stock, :min_order, :max_order, :price, :tax_type, :pre_order,
                       :min_barem, :max_barem, :barem_step, keyword_init: true) do
    def tiered?
      !min_barem.nil?
    end
  end

  # result is "Success" or "Pending" (pre-order / tiered: poll order_status for the codes).
  Order = Struct.new(:order_no, :result, :amount, :epins, keyword_init: true) do
    def pending?
      result != "Success"
    end
  end

  # state_code is "000" normally, "999" when Turkpin is handling a problem; extra holds the reason/note.
  OrderInfo = Struct.new(:order_no, :status, :description, :state_code, :checked_at, :amount, :extra, :epins,
                         keyword_init: true)

  # Every call is an HTTP POST to api.php with one form field, DATA, holding
  # <APIRequest><params>...</params></APIRequest>. Responses are XML.
  class Client
    attr_reader :url

    # transport: optional callable (url, body, timeout) -> response text, for tests or custom HTTP.
    def initialize(username:, password:, test: false, timeout: 30, base_url: nil, transport: nil)
      raise ArgumentError, "username and password are required" if username.to_s.empty? || password.to_s.empty?

      @username = username
      @password = password
      @url = base_url || (test ? TEST_URL : LIVE_URL)
      @timeout = timeout
      @transport = transport || method(:http_post)
    end

    def games
      p = call("epinOyunListesi")
      p.get_elements("oyunListesi/oyun").map { |g| Game.new(id: t(g, "id").to_i, name: t(g, "name")) }
    end

    def products(game_id, product_id = nil)
      params = { oyunKodu: game_id }
      params[:urunKodu] = product_id unless product_id.nil?
      call("epinUrunleri", params).get_elements("epinUrunListesi/urun").map do |u|
        Product.new(
          id: t(u, "id").to_i, name: t(u, "name"), stock: t(u, "stock").to_i,
          min_order: [1, t(u, "min_order").to_i].max, max_order: t(u, "max_order").to_i,
          price: dec(t(u, "price")), tax_type: t(u, "tax_type"), pre_order: t(u, "pre_order").casecmp?("true"),
          min_barem: dec_opt(t(u, "min_barem")), max_barem: dec_opt(t(u, "max_barem")),
          barem_step: dec_opt(t(u, "barem_step"))
        )
      end
    end

    # pre_order must be true for products listed with pre_order; barem is the amount for tiered products.
    def create_order(game_id:, product_id:, quantity: 1, character: nil, pre_order: false, barem: nil)
      params = { oyunKodu: game_id, urunKodu: product_id, adet: quantity }
      params[:character] = character unless character.nil?
      params[:pre_order] = "true" if pre_order
      params[:barem] = barem.is_a?(BigDecimal) ? barem.to_s("F") : barem unless barem.nil?
      p = call("epinSiparisYarat", params)
      Order.new(order_no: t(p, "siparisNo"), result: t(p, "siparisSonuc"), amount: dec(t(p, "siparisTutari")),
                epins: epins(p))
    end

    def order_status(order_no)
      order_info(call("siparisDurumu", siparisNo: order_no))
    end

    # Orders between two dates (Date or "YYYY-MM-DD", inclusive, at most 30 days apart).
    def orders(start_date, end_date)
      ymd = ->(d) { d.respond_to?(:strftime) ? d.strftime("%Y-%m-%d") : d.to_s }
      p = call("siparisListesi", baslangicTarihi: ymd.call(start_date), bitisTarihi: ymd.call(end_date))
      p.get_elements("SIPARISLER/SIPARIS").map { |s| order_info(s) }
    end

    def balance
      b = call("balance").elements["balanceInformation"]
      Balance.new(balance: dec(t(b, "balance")), credit: dec(t(b, "credit")), bonus: dec(t(b, "bonus")),
                  spending: dec(t(b, "spending")))
    end

    # Sends one command and returns the <params> element (REXML::Element).
    def call(cmd, params = {})
      fields = { cmd: cmd, username: @username, password: @password }.merge(params)
      doc = REXML::Document.new("<APIRequest><params/></APIRequest>")
      fields.each { |k, v| doc.root.elements["params"].add_element(k.to_s).text = v.to_s }
      body = URI.encode_www_form(DATA: doc.to_s)
      raw = @transport.call(@url, body, @timeout).to_s
      p = begin
        REXML::Document.new(raw.strip).root&.elements&.[]("params")
      rescue REXML::ParseException
        nil
      end
      raise Error, "Invalid response from Turkpin API: #{raw[0, 200]}" if p.nil?

      code = t(p, "error")
      code = t(p, "HATA_NO") if code.empty?
      unless code.empty? || code == "000"
        msg = [t(p, "error_desc"), t(p, "HATA_ACIKLAMA"), "Turkpin API error"].find { |m| !m.empty? }
        raise Error.new(msg, code)
      end
      p
    end

    private

    def http_post(url, body, timeout)
      uri = URI(url)
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                                open_timeout: timeout, read_timeout: timeout) do |http|
        http.post(uri.path, body, "Content-Type" => "application/x-www-form-urlencoded")
      end
      code = res.code.to_i
      raise Error, "HTTP #{code} from Turkpin API" if code >= 400 && code != 401

      res.body.to_s.force_encoding("UTF-8")
    rescue SystemCallError, IOError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError => e
      raise Error, "HTTP request failed: #{e.message}"
    end

    def t(el, name)
      c = el&.elements&.[](name)
      c ? c.text.to_s.strip : ""
    end

    def dec(s)
      BigDecimal(s)
    rescue ArgumentError
      BigDecimal("0")
    end

    def dec_opt(s)
      s.empty? ? nil : dec(s)
    end

    def epins(el)
      el.get_elements("epin_list/epin").map { |e| Epin.new(code: t(e, "code"), description: t(e, "desc"), id: t(e, "id")) }
    end

    def order_info(s)
      extra = t(s, "EKSTRA")
      extra = t(s, "EXTRA") if extra.empty?
      OrderInfo.new(order_no: t(s, "SIPARIS_NO"), status: t(s, "SIPARIS_DURUMU").to_i,
                    description: t(s, "SIPARIS_DURUMU_ACIKLAMA"), state_code: t(s, "DURUM_KODU"),
                    checked_at: t(s, "KONTROL_TARIHI"), amount: dec(t(s, "SIPARIS_TUTARI")), extra: extra,
                    epins: epins(s))
    end
  end
end
