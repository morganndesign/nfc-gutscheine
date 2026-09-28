-- 1) card balance == SUM(signed ledger amounts)
SELECT 'balance<>ledger' AS check_name, COUNT(*) AS violations FROM (
  SELECT c.id FROM gift_cards c LEFT JOIN gift_card_transactions t ON t.gift_card_id=c.id
  GROUP BY c.id, c.balance HAVING c.balance <> COALESCE(SUM(t.amount),0)) x
UNION ALL
-- 2) each row: balance_after = balance_before + amount
SELECT 'row arithmetic', COUNT(*) FROM gift_card_transactions WHERE balance_after <> balance_before + amount
UNION ALL
-- 3) chain: balance_before == previous balance_after (0 for the first row)
SELECT 'chain break', COUNT(*) FROM (
  SELECT balance_before, LAG(balance_after,1,0) OVER (PARTITION BY gift_card_id ORDER BY created_at, id) prev
  FROM gift_card_transactions) y WHERE balance_before <> prev
UNION ALL
-- 4) last balance_after == card balance
SELECT 'last<>card', COUNT(*) FROM gift_cards c JOIN (
  SELECT gift_card_id, balance_after, ROW_NUMBER() OVER (PARTITION BY gift_card_id ORDER BY created_at DESC, id DESC) rn
  FROM gift_card_transactions) z ON z.gift_card_id=c.id AND z.rn=1 WHERE z.balance_after <> c.balance
UNION ALL
-- 5) an original reversed more than once
SELECT 'multi-reversal', COUNT(*) FROM (SELECT related_transaction_id FROM gift_card_transactions WHERE type='reversal'
  GROUP BY related_transaction_id HAVING COUNT(*)>1) r
UNION ALL
SELECT 'negative balance', COUNT(*) FROM gift_cards WHERE balance < 0
UNION ALL
SELECT 'balance > max_card_balance', COUNT(*) FROM gift_cards c JOIN restaurant_settings s ON s.restaurant_id=c.restaurant_id WHERE c.balance > s.max_card_balance
UNION ALL
SELECT 'cards / transactions total', CONCAT((SELECT COUNT(*) FROM gift_cards),' / ',(SELECT COUNT(*) FROM gift_card_transactions));
