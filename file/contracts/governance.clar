;; Governance contract for decentralized protocol management
(use-trait sip10-trait .sip-010-trait.sip-010-trait)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u200))
(define-constant err-invalid-proposal (err u201))
(define-constant err-proposal-not-found (err u202))
(define-constant err-already-voted (err u203))
(define-constant err-voting-ended (err u204))
(define-constant err-voting-not-ended (err u205))
(define-constant err-insufficient-voting-power (err u206))
(define-constant err-proposal-not-passed (err u207))
(define-constant err-execution-failed (err u208))

;; Voting periods and thresholds
(define-constant voting-period u2016) ;; ~2 weeks in blocks (assuming 10min blocks)
(define-constant min-voting-power u1000) ;; Minimum tokens needed to create proposal
(define-constant quorum-threshold u5000) ;; 50% of total voting power needed
(define-constant passing-threshold u6000) ;; 60% approval needed

;; Data variables
(define-data-var proposal-id-counter uint u0)
(define-data-var governance-token principal tx-sender) ;; Will be set to token-a by default
(define-data-var vault-contract principal .vault) ;; Reference to vault contract

;; Proposal types
(define-constant proposal-type-fee-change u1)
(define-constant proposal-type-pause-contract u2)
(define-constant proposal-type-unpause-contract u3)
(define-constant proposal-type-upgrade-contract u4)

;; Maps
(define-map proposals
  { id: uint }
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    proposal-type: uint,
    parameter: uint,
    start-block: uint,
    end-block: uint,
    votes-for: uint,
    votes-against: uint,
    total-voting-power: uint,
    executed: bool,
    passed: bool
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { 
    voting-power: uint,
    vote-for: bool,
    block-voted: uint
  }
)

(define-map voting-power
  { user: principal }
  { power: uint, last-updated: uint }
)

;; Delegate voting power
(define-map delegations
  { delegator: principal }
  { delegate: principal, amount: uint }
)

;; Admin functions
(define-public (set-governance-token (token principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (var-set governance-token token)
    (ok true)
  )
)

(define-public (set-vault-contract (vault principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (var-set vault-contract vault)
    (ok true)
  )
)

;; Update voting power based on token balance
(define-public (update-voting-power (token <sip10-trait>))
  (let (
    (user tx-sender)
    (token-balance (unwrap-panic (contract-call? token get-balance user)))
  )
    (begin
      (asserts! (is-eq (contract-of token) (var-get governance-token)) err-unauthorized)
      (map-set voting-power 
        {user: user}
        {power: token-balance, last-updated: block-height})
      (ok token-balance)
    )
  )
)

;; Delegate voting power
(define-public (delegate-votes (delegate principal) (amount uint))
  (let (
    (user-power (get-user-voting-power tx-sender))
  )
    (begin
      (asserts! (>= user-power amount) err-insufficient-voting-power)
      (map-set delegations 
        {delegator: tx-sender}
        {delegate: delegate, amount: amount})
      (ok true)
    )
  )
)

;; Create proposal
(define-public (create-proposal 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (proposal-type uint)
  (parameter uint))
  (let (
    (proposal-id (+ (var-get proposal-id-counter) u1))
    (user-voting-power (get-user-voting-power tx-sender))
    (start-block block-height)
    (end-block (+ block-height voting-period))
  )
    (begin
      (asserts! (>= user-voting-power min-voting-power) err-insufficient-voting-power)
      (asserts! (<= proposal-type u4) err-invalid-proposal)
      
      (map-set proposals
        {id: proposal-id}
        {
          proposer: tx-sender,
          title: title,
          description: description,
          proposal-type: proposal-type,
          parameter: parameter,
          start-block: start-block,
          end-block: end-block,
          votes-for: u0,
          votes-against: u0,
          total-voting-power: u0,
          executed: false,
          passed: false
        })
      
      (var-set proposal-id-counter proposal-id)
      (ok proposal-id)
    )
  )
)

;; Vote on proposal
(define-public (vote (proposal-id uint) (vote-for bool))
  (let (
    (user-voting-power (get-user-voting-power tx-sender))
    (delegated-power (get-delegated-power tx-sender))
    (total-power (+ user-voting-power delegated-power))
  )
    (match (map-get? proposals {id: proposal-id})
      proposal (begin
        (asserts! (> total-power u0) err-insufficient-voting-power)
        (asserts! (>= block-height (get start-block proposal)) err-invalid-proposal)
        (asserts! (< block-height (get end-block proposal)) err-voting-ended)
        (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: tx-sender})) err-already-voted)
        
        ;; Record vote
        (map-set votes
          {proposal-id: proposal-id, voter: tx-sender}
          {
            voting-power: total-power,
            vote-for: vote-for,
            block-voted: block-height
          })
        
        ;; Update proposal vote counts
        (let (
          (new-votes-for (if vote-for (+ (get votes-for proposal) total-power) (get votes-for proposal)))
          (new-votes-against (if vote-for (get votes-against proposal) (+ (get votes-against proposal) total-power)))
          (new-total-power (+ (get total-voting-power proposal) total-power))
        )
          (map-set proposals
            {id: proposal-id}
            (merge proposal {
              votes-for: new-votes-for,
              votes-against: new-votes-against,
              total-voting-power: new-total-power
            }))
          
          (ok {voted: vote-for, power-used: total-power})
        )
      )
      err-proposal-not-found
    )
  )
)

;; Execute proposal
(define-public (execute-proposal (proposal-id uint))
  (match (map-get? proposals {id: proposal-id})
    proposal (begin
      (asserts! (>= block-height (get end-block proposal)) err-voting-not-ended)
      (asserts! (not (get executed proposal)) err-invalid-proposal)
      
      ;; Check if proposal passed
      (let (
        (votes-for (get votes-for proposal))
        (votes-against (get votes-against proposal))
        (total-votes (+ votes-for votes-against))
        (approval-rate (if (> total-votes u0) (/ (* votes-for u10000) total-votes) u0))
        (quorum-met (>= total-votes quorum-threshold))
        (approval-met (>= approval-rate passing-threshold))
        (proposal-passed (and quorum-met approval-met))
      )
        ;; Mark as executed
        (map-set proposals
          {id: proposal-id}
          (merge proposal {executed: true, passed: proposal-passed}))
        
        ;; Execute the action if proposal passed and return result
        (if proposal-passed
          (let (
            (action-result (execute-proposal-action (get proposal-type proposal) (get parameter proposal)))
          )
            (match action-result
              success (ok {
                executed: true,
                passed: proposal-passed,
                action: (get action success)
              })
              error (ok {
                executed: true,
                passed: proposal-passed,
                action: "execution-failed"
              })
            )
          )
          (ok {
            executed: true,
            passed: proposal-passed,
            action: "none"
          })
        )
      )
    )
    err-proposal-not-found
  )
)

;; Helper function to execute proposal actions
(define-private (execute-proposal-action (proposal-type uint) (parameter uint))
  (if (is-eq proposal-type u1)
    ;; Fee change - could fail in real implementation
    (if (> parameter u10000) ;; Example validation
      err-execution-failed
      (ok {executed: true, action: "fee-changed"}))
    (if (is-eq proposal-type u2)
      ;; Pause contract
      (ok {executed: true, action: "contract-paused"})
      (if (is-eq proposal-type u3)
        ;; Unpause contract
        (ok {executed: true, action: "contract-unpaused"})
        (if (is-eq proposal-type u4)
          ;; Upgrade contract - could fail in real implementation
          (ok {executed: true, action: "contract-upgraded"})
          ;; Unknown proposal type
          err-execution-failed
        )
      )
    )
  )
)

;; Helper functions
(define-private (get-user-voting-power (user principal))
  (default-to u0 (get power (map-get? voting-power {user: user})))
)

(define-private (get-delegated-power (delegate principal))
  ;; This would need to iterate through all delegations - simplified for now
  u0
)

;; Read-only functions
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals {id: proposal-id})
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-voting-power-info (user principal))
  (map-get? voting-power {user: user})
)

(define-read-only (get-proposal-count)
  (var-get proposal-id-counter)
)

(define-read-only (get-governance-token)
  (var-get governance-token)
)

(define-read-only (get-vault-contract)
  (var-get vault-contract)
)

;; Get proposal status
(define-read-only (get-proposal-status (proposal-id uint))
  (match (map-get? proposals {id: proposal-id})
    proposal (let (
      (current-block block-height)
      (start-block (get start-block proposal))
      (end-block (get end-block proposal))
      (votes-for (get votes-for proposal))
      (votes-against (get votes-against proposal))
      (total-votes (+ votes-for votes-against))
      (approval-rate (if (> total-votes u0) (/ (* votes-for u10000) total-votes) u0))
    )
      (ok {
        status: (if (< current-block start-block) "pending"
                (if (< current-block end-block) "active"
                (if (get executed proposal) "executed" "ready-for-execution"))),
        votes-for: votes-for,
        votes-against: votes-against,
        approval-rate: approval-rate,
        quorum-met: (>= total-votes quorum-threshold),
        blocks-remaining: (if (< current-block end-block) (- end-block current-block) u0)
      })
    )
    err-proposal-not-found
  )
)
