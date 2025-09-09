;; Vault contract
(use-trait sip10-trait .sip-010-trait.sip-010-trait)

;; deposits: key = {user, token}, value = balance
(define-map deposits
  { user: principal, token: principal }
  { balance: uint }
)

(define-constant contract-owner tx-sender)

;; Deposit SIP-010 tokens into the vault
(define-public (deposit (amount uint) (token <sip10-trait>))
  (begin
    (asserts! (> amount u0) (err u100)) ;; invalid amount
    (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))

    (let (
      (key {user: tx-sender, token: (contract-of token)})
      (current-balance (default-to u0 (get balance (map-get? deposits {user: tx-sender, token: (contract-of token)}))))
    )
      (map-set deposits key {balance: (+ current-balance amount)})
      (ok {deposited: amount, token: (contract-of token)})
    )
  )
)

;; Withdraw SIP-010 tokens from the vault
(define-public (withdraw (amount uint) (token <sip10-trait>))
  (let (
    (key {user: tx-sender, token: (contract-of token)})
    (current-balance (default-to u0 (get balance (map-get? deposits key))))
  )
    (begin
      (asserts! (> amount u0) (err u101)) ;; invalid amount
      (asserts! (>= current-balance amount) (err u102)) ;; insufficient balance
      (try! (contract-call? token transfer amount (as-contract tx-sender) tx-sender none))
      (map-set deposits key {balance: (- current-balance amount)})
      (ok {withdrawn: amount, token: (contract-of token)})
    )
  )
)

;; View user balance
(define-read-only (get-balance (user principal) (token principal))
  (default-to u0 (get balance (map-get? deposits {user: user, token: token})))
)
