;; Mock Token B (SIP-010 compliant)
(impl-trait 'ST000000000000000000002AMW42H.token-ft-trait)

(define-fungible-token token-b)

(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (ft-transfer? token-b amount sender recipient)
)

(define-public (mint (amount uint) (recipient principal))
  (ft-mint? token-b amount recipient)
)

(define-public (get-balance (owner principal))
  (ok (ft-get-balance token-b owner))
)
