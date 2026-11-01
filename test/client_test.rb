require "minitest/autorun"
require "turkpin"

class ClientTest < Minitest::Test
  FIX = File.join(__dir__, "fixtures")

  def client(fixture, test: true)
    body = fixture.start_with?("<") ? fixture : File.read(File.join(FIX, fixture), encoding: "UTF-8")
    @sent = []
    Turkpin::Client.new(username: "dealer@example.com", password: "s3cr<et", test: test,
                        transport: ->(url, data, _timeout) { @sent << [url, data]; body })
  end

  def params
    form = URI.decode_www_form(@sent.last[1]).to_h
    REXML::Document.new(form["DATA"]).root.elements["params"]
  end

  def pt(name)
    params.elements[name]&.text
  end

  def test_request_format
    client("games.xml").games
    assert_equal Turkpin::TEST_URL, @sent[0][0]
    assert_equal "epinOyunListesi", pt("cmd")
    assert_equal "s3cr<et", pt("password")
  end

  def test_live_by_default
    client("balance.xml", test: false).balance
    assert_equal Turkpin::LIVE_URL, @sent[0][0]
  end

  def test_games
    games = client("games.xml").games
    assert_equal [[1, "Game 1"], [2, "Game 2"]], games.map { |g| [g.id, g.name] }
  end

  def test_products
    a, b = client("products.xml").products(1)
    assert_equal "1", pt("oyunKodu")
    assert_equal [26_278, 0, BigDecimal("0.001"), false], [a.stock, a.max_order, a.price, a.pre_order]
    refute a.tiered?
    assert b.pre_order && b.tiered?
    assert_equal [BigDecimal(25), BigDecimal(1250), BigDecimal("0.01")], [b.min_barem, b.max_barem, b.barem_step]
    assert_equal 5, b.max_order
  end

  def test_create_order
    o = client("order_success.xml").create_order(game_id: 1, product_id: 4, quantity: 2, character: "Player1")
    assert_equal %w[2 Player1], [pt("adet"), pt("character")]
    assert_nil pt("pre_order")
    assert_equal "25031013105101", o.order_no
    refute o.pending?
    assert_equal "S3XS-EEDY-APAE-62EM", o.epins[0].code
    assert_equal "Test Ürün", o.epins[0].description
  end

  def test_pre_order_with_barem
    o = client("order_pending.xml").create_order(game_id: 1, product_id: 4, pre_order: true, barem: BigDecimal("30.5"))
    assert_equal %w[true 30.5], [pt("pre_order"), pt("barem")]
    assert o.pending?
    assert_empty o.epins
  end

  def test_api_errors
    e = assert_raises(Turkpin::Error) { client("order_out_of_stock.xml").create_order(game_id: 1, product_id: 2) }
    assert_equal ["012", "Urun stok yetersiz."], [e.code, e.message]
    e = assert_raises(Turkpin::Error) { client("error_auth.xml").games }
    assert_equal "001", e.code
  end

  def test_invalid_response
    assert_raises(Turkpin::Error) { client("<html>blocked</html").balance }
  end

  def test_order_status
    s = client("status_completed.xml").order_status("25031013105101")
    assert_equal Turkpin::OrderStatus::COMPLETED, s.status
    assert_equal BigDecimal("0.001"), s.amount
    assert_equal "S3XS-EEDY-APAE-62EM", s.epins[0].code
    c = client("status_cancelled.xml").order_status("25030620073001")
    assert_equal [Turkpin::OrderStatus::CANCELLED, "Stok yok"], [c.status, c.extra]
  end

  def test_orders
    list = client("orders.xml").orders(Date.new(2026, 1, 1), "2026-01-30")
    assert_equal %w[2026-01-01 2026-01-30], [pt("baslangicTarihi"), pt("bitisTarihi")]
    assert_equal 2, list.size
    assert_equal Turkpin::OrderStatus::PROCESSING, list[0].status
    assert_equal ["999", "CANCELLATION REASON"], [list[1].state_code, list[1].extra]
  end

  def test_balance
    b = client("balance.xml").balance
    assert_equal [BigDecimal("98689"), BigDecimal("1311")], [b.balance, b.spending]
  end
end
