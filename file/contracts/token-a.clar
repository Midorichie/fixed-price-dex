;; Mock Token A (SIP-010 compliant)
(impl-trait 'ST000000000000000000002AMW42H.token-ft-trait)

(define-fungible-token token-a)

(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (ft-transfer? token-a amount sender recipient)
)

(define-public (mint (amount uint) (recipient principal))
  (ft-mint? token-a amount recipient)
)

(define-public (get-balance (owner principal))
  (ok (ft-get-balance token-a owner))
)
