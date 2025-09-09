(define-trait sip-010-trait
  (
    ;; balance-of
    (get-balance (principal) (response uint uint))
    ;; transfer
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    ;; total-supply
    (get-total-supply () (response uint uint))
    ;; name
    (get-name () (response (string-ascii 32) uint))
    ;; symbol
    (get-symbol () (response (string-ascii 32) uint))
    ;; decimals
    (get-decimals () (response uint uint))
  )
)
