(impl-trait .sip-010-trait.sip-010-trait)

;; Define fungible token
(define-fungible-token token-b)

;; Transfer tokens
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (ft-transfer? token-b amount sender recipient))

;; Mint tokens (for testing / admin use)
(define-public (mint (amount uint) (recipient principal))
  (ft-mint? token-b amount recipient))

;; Get balance of a principal
(define-read-only (get-balance (owner principal))
  (ok (ft-get-balance token-b owner)))

;; Get total supply
(define-read-only (get-total-supply)
  (ok (ft-get-supply token-b)))

;; Token metadata
(define-read-only (get-name)
  (ok "Token B"))

(define-read-only (get-symbol)
  (ok "TKNB"))

(define-read-only (get-decimals)
  (ok u6)) ;; 6 decimals
