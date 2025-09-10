;; Price Oracle contract for external price feeds and TWAP calculations
(use-trait sip10-trait .sip-010-trait.sip-010-trait)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u300))
(define-constant err-invalid-price (err u301))
(define-constant err-stale-price (err u302))
(define-constant err-oracle-not-found (err u303))
(define-constant err-insufficient-observations (err u304))
(define-constant err-vault-call-failed (err u305))

;; Price feed validity window (in blocks)
(define-constant max-price-age u144) ;; ~24 hours assuming 10min blocks
(define-constant min-observations-for-twap u6) ;; Minimum observations for TWAP

;; Data variables
(define-data-var oracle-count uint u0)
(define-data-var vault-contract principal .vault) ;; Reference to vault contract

;; Oracle registry
(define-map oracles
  { oracle-id: uint }
  {
    oracle-address: principal,
    token-pair: (tuple (token-a principal) (token-b principal)),
    is-active: bool,
    last-update: uint,
    update-frequency: uint
  }
)

;; Price feeds from external oracles
(define-map price-feeds
  { token-a: principal, token-b: principal }
  {
    price: uint, ;; Price in fixed-point (multiply by 10^8)
    last-updated: uint,
    oracle-id: uint,
    confidence: uint ;; Confidence score 0-10000 (100%)
  }
)

;; Time-weighted average price observations
(define-map price-observations
  { token-a: principal, token-b: principal, timestamp: uint }
  {
    price: uint,
    cumulative-price: uint,
    block-height: uint
  }
)

;; TWAP calculation data
(define-map twap-data
  { token-a: principal, token-b: principal }
  {
    last-observation-timestamp: uint,
    cumulative-price: uint,
    observation-count: uint
  }
)

;; Authorized oracles (can update prices)
(define-map authorized-oracles
  { oracle: principal }
  { is-authorized: bool, reputation: uint }
)

;; Admin functions
(define-public (set-vault-contract (vault principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (var-set vault-contract vault)
    (ok true)
  )
)
