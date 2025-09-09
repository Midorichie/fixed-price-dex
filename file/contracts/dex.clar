(use-trait ft-trait .token-a.ft-trait)
(use-trait ft-trait .token-b.ft-trait)

(define-constant rate u2)

;; Swap Token A -> B
(define-public (swap-a-for-b (amount-a uint))
  (let ((amount-b (* amount-a rate)))
    (begin
      (try! (contract-call? .token-a transfer amount-a tx-sender contract-principal))
      (try! (contract-call? .token-b transfer amount-b contract-principal tx-sender))
      (ok {swapped-a: amount-a, received-b: amount-b})
    )
  )
)

;; Swap Token B -> A
(define-public (swap-b-for-a (amount-b uint))
  (let ((amount-a (/ amount-b rate)))
    (begin
      (try! (contract-call? .token-b transfer amount-b tx-sender contract-principal))
      (try! (contract-call? .token-a transfer amount-a contract-principal tx-sender))
      (ok {swapped-b: amount-b, received-a: amount-a})
    )
  )
)
