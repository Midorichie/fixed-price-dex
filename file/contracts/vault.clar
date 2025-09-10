;; Enhanced Vault contract with liquidity pool integration
(use-trait sip10-trait .sip-010-trait.sip-010-trait)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-invalid-amount (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-pool-not-found (err u103))
(define-constant err-insufficient-liquidity (err u104))
(define-constant err-slippage-too-high (err u105))
(define-constant err-already-paused (err u106))
(define-constant err-not-paused (err u107))

;; Data variables
(define-data-var contract-paused bool false)
(define-data-var total-fees-collected uint u0)
(define-data-var fee-rate uint u30) ;; 0.3% = 30/10000

;; User deposits: key = {user, token}, value = balance
(define-map deposits
  { user: principal, token: principal }
  { balance: uint }
)

;; Liquidity pools: key = {token-a, token-b}, value = {reserve-a, reserve-b, total-shares}
(define-map liquidity-pools
  { token-a: principal, token-b: principal }
  { reserve-a: uint, reserve-b: uint, total-shares: uint }
)

;; LP token shares: key = {user, token-a, token-b}, value = shares
(define-map lp-shares
  { user: principal, token-a: principal, token-b: principal }
  { shares: uint }
)

;; Security: Track failed transactions per user
(define-map failed-tx-count
  { user: principal }
  { count: uint, last-attempt: uint }
)

;; Helper function to compare principals for consistent ordering
(define-private (principal-to-string (p principal))
  (if (is-eq p 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) "A" "B")
)

(define-private (order-tokens (token-a principal) (token-b principal))
  (if (is-eq (principal-to-string token-a) "A")
    {token-a: token-a, token-b: token-b}
    {token-a: token-b, token-b: token-a}
  )
)

;; Admin functions
(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (not (var-get contract-paused)) err-already-paused)
    (var-set contract-paused true)
    (ok true)
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (var-get contract-paused) err-not-paused)
    (var-set contract-paused false)
    (ok true)
  )
)

(define-public (set-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (<= new-rate u1000) err-invalid-amount) ;; Max 10%
    (var-set fee-rate new-rate)
    (ok true)
  )
)

;; Security helper functions
(define-private (is-contract-active)
  (not (var-get contract-paused))
)

(define-private (record-failed-tx)
  (let (
    (user tx-sender)
    (current-block block-height)
    (current-data (default-to {count: u0, last-attempt: u0} 
                    (map-get? failed-tx-count {user: user})))
  )
    (map-set failed-tx-count 
      {user: user}
      {count: (+ (get count current-data) u1), last-attempt: current-block}
    )
  )
)

;; Enhanced deposit with security checks
(define-public (deposit (amount uint) (token <sip10-trait>))
  (begin
    (asserts! (is-contract-active) err-unauthorized)
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Transfer tokens to vault
    (match (contract-call? token transfer amount tx-sender (as-contract tx-sender) none)
      success (let (
        (key {user: tx-sender, token: (contract-of token)})
        (current-balance (default-to u0 (get balance (map-get? deposits key))))
      )
        (map-set deposits key {balance: (+ current-balance amount)})
        (ok {deposited: amount, token: (contract-of token), new-balance: (+ current-balance amount)})
      )
      error (begin
        (record-failed-tx)
        (err error)
      )
    )
  )
)

;; Enhanced withdraw with security checks
(define-public (withdraw (amount uint) (token <sip10-trait>))
  (let (
    (key {user: tx-sender, token: (contract-of token)})
    (current-balance (default-to u0 (get balance (map-get? deposits key))))
  )
    (begin
      (asserts! (is-contract-active) err-unauthorized)
      (asserts! (> amount u0) err-invalid-amount)
      (asserts! (>= current-balance amount) err-insufficient-balance)
      
      (match (as-contract (contract-call? token transfer amount tx-sender tx-sender none))
        success (begin
          (map-set deposits key {balance: (- current-balance amount)})
          (ok {withdrawn: amount, token: (contract-of token), remaining-balance: (- current-balance amount)})
        )
        error (begin
          (record-failed-tx)
          (err error)
        )
      )
    )
  )
)

;; Create liquidity pool
(define-public (create-pool (token-a <sip10-trait>) (token-b <sip10-trait>) 
                           (amount-a uint) (amount-b uint))
  (let (
    (token-a-addr (contract-of token-a))
    (token-b-addr (contract-of token-b))
    (pool-key (order-tokens token-a-addr token-b-addr))
  )
    (begin
      (asserts! (is-contract-active) err-unauthorized)
      (asserts! (> amount-a u0) err-invalid-amount)
      (asserts! (> amount-b u0) err-invalid-amount)
      (asserts! (is-none (map-get? liquidity-pools pool-key)) err-invalid-amount)
      
      ;; Transfer tokens to contract
      (try! (contract-call? token-a transfer amount-a tx-sender (as-contract tx-sender) none))
      (try! (contract-call? token-b transfer amount-b tx-sender (as-contract tx-sender) none))
      
      ;; Calculate initial LP shares (geometric mean)
      (let ((initial-shares (sqrti (* amount-a amount-b))))
        ;; Create pool
        (map-set liquidity-pools pool-key 
          {reserve-a: amount-a, reserve-b: amount-b, total-shares: initial-shares})
        
        ;; Mint LP shares to user
        (map-set lp-shares 
          {user: tx-sender, token-a: (get token-a pool-key), token-b: (get token-b pool-key)}
          {shares: initial-shares})
        
        (ok {pool-created: pool-key, lp-shares: initial-shares})
      )
    )
  )
)

;; Add liquidity to existing pool
(define-public (add-liquidity (token-a <sip10-trait>) (token-b <sip10-trait>)
                             (amount-a uint) (amount-b uint) (min-shares uint))
  (let (
    (token-a-addr (contract-of token-a))
    (token-b-addr (contract-of token-b))
    (pool-key (order-tokens token-a-addr token-b-addr))
  )
    (match (map-get? liquidity-pools pool-key)
      pool (let (
        (reserve-a (get reserve-a pool))
        (reserve-b (get reserve-b pool))
        (total-shares (get total-shares pool))
        ;; Calculate proportional amounts
        (required-b (/ (* amount-a reserve-b) reserve-a))
        (shares-to-mint (/ (* amount-a total-shares) reserve-a))
      )
        (begin
          (asserts! (is-contract-active) err-unauthorized)
          (asserts! (>= amount-b required-b) err-insufficient-liquidity)
          (asserts! (>= shares-to-mint min-shares) err-slippage-too-high)
          
          ;; Transfer tokens
          (try! (contract-call? token-a transfer amount-a tx-sender (as-contract tx-sender) none))
          (try! (contract-call? token-b transfer required-b tx-sender (as-contract tx-sender) none))
          
          ;; Update pool
          (map-set liquidity-pools pool-key
            {reserve-a: (+ reserve-a amount-a),
             reserve-b: (+ reserve-b required-b),
             total-shares: (+ total-shares shares-to-mint)})
          
          ;; Update user LP shares
          (let ((current-shares (default-to u0 (get shares (map-get? lp-shares 
                {user: tx-sender, token-a: (get token-a pool-key), token-b: (get token-b pool-key)})))))
            (map-set lp-shares 
              {user: tx-sender, token-a: (get token-a pool-key), token-b: (get token-b pool-key)}
              {shares: (+ current-shares shares-to-mint)})
            
            (ok {added-a: amount-a, added-b: required-b, lp-shares: shares-to-mint})
          )
        )
      )
      err-pool-not-found
    )
  )
)

;; Enhanced swap with AMM pricing and fees
(define-public (swap-exact-tokens (token-in <sip10-trait>) (token-out <sip10-trait>)
                                 (amount-in uint) (min-amount-out uint))
  (let (
    (token-in-addr (contract-of token-in))
    (token-out-addr (contract-of token-out))
    (pool-key (order-tokens token-in-addr token-out-addr))
  )
    (match (map-get? liquidity-pools pool-key)
      pool (let (
        (is-a-to-b (is-eq token-in-addr (get token-a pool-key)))
        (reserve-in (if is-a-to-b (get reserve-a pool) (get reserve-b pool)))
        (reserve-out (if is-a-to-b (get reserve-b pool) (get reserve-a pool)))
        ;; Calculate output with 0.3% fee
        (amount-in-with-fee (* amount-in (- u10000 (var-get fee-rate))))
        (numerator (* amount-in-with-fee reserve-out))
        (denominator (+ (* reserve-in u10000) amount-in-with-fee))
        (amount-out (/ numerator denominator))
        (fee-amount (/ (* amount-in (var-get fee-rate)) u10000))
      )
        (begin
          (asserts! (is-contract-active) err-unauthorized)
          (asserts! (> amount-in u0) err-invalid-amount)
          (asserts! (>= amount-out min-amount-out) err-slippage-too-high)
          
          ;; Transfer input token
          (try! (contract-call? token-in transfer amount-in tx-sender (as-contract tx-sender) none))
          
          ;; Transfer output token
          (try! (as-contract (contract-call? token-out transfer amount-out tx-sender tx-sender none)))
          
          ;; Update pool reserves
          (if is-a-to-b
            (map-set liquidity-pools pool-key
              {reserve-a: (+ reserve-in amount-in),
               reserve-b: (- reserve-out amount-out),
               total-shares: (get total-shares pool)})
            (map-set liquidity-pools pool-key
              {reserve-a: (- reserve-out amount-out),
               reserve-b: (+ reserve-in amount-in),
               total-shares: (get total-shares pool)})
          )
          
          ;; Update total fees collected
          (var-set total-fees-collected (+ (var-get total-fees-collected) fee-amount))
          
          (ok {amount-in: amount-in, amount-out: amount-out, fee-paid: fee-amount})
        )
      )
      err-pool-not-found
    )
  )
)

;; View functions
(define-read-only (get-balance (user principal) (token principal))
  (default-to u0 (get balance (map-get? deposits {user: user, token: token})))
)

(define-read-only (get-pool-info (token-a principal) (token-b principal))
  (let ((pool-key (order-tokens token-a token-b)))
    (map-get? liquidity-pools pool-key)
  )
)

(define-read-only (get-lp-shares (user principal) (token-a principal) (token-b principal))
  (let ((pool-key (order-tokens token-a token-b)))
    (default-to u0 (get shares (map-get? lp-shares 
      {user: user, token-a: (get token-a pool-key), token-b: (get token-b pool-key)})))
  )
)

(define-read-only (get-swap-quote (token-in principal) (token-out principal) (amount-in uint))
  (let (
    (pool-key (order-tokens token-in token-out))
  )
    (match (map-get? liquidity-pools pool-key)
      pool (let (
        (is-a-to-b (is-eq token-in (get token-a pool-key)))
        (reserve-in (if is-a-to-b (get reserve-a pool) (get reserve-b pool)))
        (reserve-out (if is-a-to-b (get reserve-b pool) (get reserve-a pool)))
        (amount-in-with-fee (* amount-in (- u10000 (var-get fee-rate))))
        (numerator (* amount-in-with-fee reserve-out))
        (denominator (+ (* reserve-in u10000) amount-in-with-fee))
        (amount-out (/ numerator denominator))
      )
        (ok {amount-out: amount-out, 
             price-impact: (/ (* amount-out u10000) reserve-out),
             fee: (/ (* amount-in (var-get fee-rate)) u10000)})
      )
      err-pool-not-found
    )
  )
)

(define-read-only (is-paused)
  (var-get contract-paused)
)

(define-read-only (get-total-fees)
  (var-get total-fees-collected)
)

(define-read-only (get-failed-tx-count (user principal))
  (default-to {count: u0, last-attempt: u0} (map-get? failed-tx-count {user: user}))
)
