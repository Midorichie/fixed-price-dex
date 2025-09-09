;; Import SIP-010 trait
(use-trait sip10-trait .sip-010-trait.sip-010-trait)

(define-constant fixed-rate u2)

(define-public (swap-a-for-b (amount uint))
  (let ((amount-b (* amount fixed-rate)))
    (begin
      (try! (contract-call? .token-a transfer amount tx-sender (as-contract tx-sender) none))
      (try! (contract-call? .token-b transfer amount-b (as-contract tx-sender) tx-sender none))
      (ok {swapped-a: amount, received-b: amount-b})
    )
  )
)

(define-public (swap-b-for-a (amount-b uint))
  (let ((amount-a (/ amount-b fixed-rate)))
    (begin
      (try! (contract-call? .token-b transfer amount-b tx-sender (as-contract tx-sender) none))
      (try! (contract-call? .token-a transfer amount-a (as-contract tx-sender) tx-sender none))
      (ok {swapped-b: amount-b, received-a: amount-a})
    )
  )
)
