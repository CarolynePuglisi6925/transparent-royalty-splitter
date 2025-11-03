;; title: royalty-splitter-factory
;; version: 1.0.0
;; summary: Factory for deploying new instances and registries for royalty-splitter
;; description: This contract manages the deployment of royalty splitter instances,
;; maintains a registry of all splitters, and handles transparent distribution configurations.

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-shares (err u101))
(define-constant err-no-beneficiaries (err u102))
(define-constant err-splitter-not-found (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-distribution-failed (err u106))
(define-constant err-max-beneficiaries (err u107))
(define-constant max-beneficiaries u10)
(define-constant basis-points u10000)

;; data vars
(define-data-var splitter-nonce uint u0)
(define-data-var total-splitters-created uint u0)
(define-data-var factory-paused bool false)

;; data maps
(define-map splitters
  { splitter-id: uint }
  {
    creator: principal,
    created-at: uint,
    total-distributed: uint,
    active: bool,
    name: (string-ascii 50)
  }
)

(define-map splitter-beneficiaries
  { splitter-id: uint, beneficiary: principal }
  { share: uint }
)

(define-map beneficiary-count
  { splitter-id: uint }
  { count: uint }
)

(define-map user-splitters
  { user: principal, index: uint }
  { splitter-id: uint }
)

(define-map user-splitter-count
  { user: principal }
  { count: uint }
)

(define-map splitter-balances
  { splitter-id: uint }
  { balance: uint }
)

;; private functions
(define-private (validate-shares (beneficiaries (list 10 { beneficiary: principal, share: uint })))
  (let
    (
      (total-share (fold + (map get-share beneficiaries) u0))
    )
    (asserts! (is-eq total-share basis-points) err-invalid-shares)
    (ok true)
  )
)

(define-private (get-share (entry { beneficiary: principal, share: uint }))
  (get share entry)
)

(define-private (save-beneficiary-fold (entry { beneficiary: principal, share: uint }) (splitter-id uint))
  (begin
    (map-set splitter-beneficiaries
      { splitter-id: splitter-id, beneficiary: (get beneficiary entry) }
      { share: (get share entry) }
    )
    splitter-id
  )
)

(define-private (increment-user-splitter (user principal) (splitter-id uint))
  (begin
    (let
      (
        (current-count (default-to u0 (get count (map-get? user-splitter-count { user: user }))))
      )
      (map-set user-splitters
        { user: user, index: current-count }
        { splitter-id: splitter-id }
      )
      (map-set user-splitter-count
        { user: user }
        { count: (+ current-count u1) }
      )
    )
    true
  )
)

;; public functions
(define-public (create-splitter
    (name (string-ascii 50))
    (beneficiaries (list 10 { beneficiary: principal, share: uint }))
  )
  (let
    (
      (splitter-id (var-get splitter-nonce))
      (beneficiary-cnt (len beneficiaries))
    )
    (asserts! (not (var-get factory-paused)) (err u108))
    (asserts! (> beneficiary-cnt u0) err-no-beneficiaries)
    (asserts! (<= beneficiary-cnt max-beneficiaries) err-max-beneficiaries)
    (try! (validate-shares beneficiaries))
    
    ;; Create splitter record
    (map-set splitters
      { splitter-id: splitter-id }
      {
        creator: tx-sender,
        created-at: stacks-block-height,
        total-distributed: u0,
        active: true,
        name: name
      }
    )
    
    ;; Save beneficiaries
    (fold save-beneficiary-fold beneficiaries splitter-id)
    
    ;; Update beneficiary count
    (map-set beneficiary-count
      { splitter-id: splitter-id }
      { count: beneficiary-cnt }
    )
    
    ;; Initialize balance
    (map-set splitter-balances
      { splitter-id: splitter-id }
      { balance: u0 }
    )
    
    ;; Track user's splitters
    (increment-user-splitter tx-sender splitter-id)
    
    ;; Update counters
    (var-set splitter-nonce (+ splitter-id u1))
    (var-set total-splitters-created (+ (var-get total-splitters-created) u1))
    
    (ok splitter-id)
  )
)

(define-public (deposit-to-splitter (splitter-id uint) (amount uint))
  (let
    (
      (splitter-info (unwrap! (map-get? splitters { splitter-id: splitter-id }) err-splitter-not-found))
      (current-balance (default-to u0 (get balance (map-get? splitter-balances { splitter-id: splitter-id }))))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (get active splitter-info) (err u109))
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update balance
    (map-set splitter-balances
      { splitter-id: splitter-id }
      { balance: (+ current-balance amount) }
    )
    
    (ok true)
  )
)

(define-public (distribute-royalties (splitter-id uint) (beneficiary principal))
  (let
    (
      (splitter-info (unwrap! (map-get? splitters { splitter-id: splitter-id }) err-splitter-not-found))
      (beneficiary-info (unwrap! (map-get? splitter-beneficiaries { splitter-id: splitter-id, beneficiary: beneficiary }) err-splitter-not-found))
      (current-balance (default-to u0 (get balance (map-get? splitter-balances { splitter-id: splitter-id }))))
      (share (get share beneficiary-info))
      (distribution-amount (/ (* current-balance share) basis-points))
    )
    (asserts! (> distribution-amount u0) err-invalid-amount)
    (asserts! (get active splitter-info) (err u109))
    
    ;; Transfer from contract to beneficiary
    (try! (as-contract (stx-transfer? distribution-amount tx-sender beneficiary)))
    
    ;; Update balances
    (map-set splitter-balances
      { splitter-id: splitter-id }
      { balance: (- current-balance distribution-amount) }
    )
    
    (map-set splitters
      { splitter-id: splitter-id }
      (merge splitter-info { total-distributed: (+ (get total-distributed splitter-info) distribution-amount) })
    )
    
    (ok distribution-amount)
  )
)

(define-public (toggle-splitter-status (splitter-id uint))
  (let
    (
      (splitter-info (unwrap! (map-get? splitters { splitter-id: splitter-id }) err-splitter-not-found))
    )
    (asserts! (is-eq tx-sender (get creator splitter-info)) err-owner-only)
    
    (map-set splitters
      { splitter-id: splitter-id }
      (merge splitter-info { active: (not (get active splitter-info)) })
    )
    
    (ok true)
  )
)

(define-public (toggle-factory-pause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set factory-paused (not (var-get factory-paused)))
    (ok true)
  )
)

;; read only functions
(define-read-only (get-splitter-info (splitter-id uint))
  (map-get? splitters { splitter-id: splitter-id })
)

(define-read-only (get-beneficiary-share (splitter-id uint) (beneficiary principal))
  (map-get? splitter-beneficiaries { splitter-id: splitter-id, beneficiary: beneficiary })
)

(define-read-only (get-splitter-balance (splitter-id uint))
  (default-to u0 (get balance (map-get? splitter-balances { splitter-id: splitter-id })))
)

(define-read-only (get-total-splitters)
  (var-get total-splitters-created)
)

(define-read-only (get-user-splitter-count (user principal))
  (default-to u0 (get count (map-get? user-splitter-count { user: user })))
)

(define-read-only (get-user-splitter-at-index (user principal) (index uint))
  (map-get? user-splitters { user: user, index: index })
)

(define-read-only (is-factory-paused)
  (var-get factory-paused)
)

(define-read-only (get-beneficiary-count (splitter-id uint))
  (default-to u0 (get count (map-get? beneficiary-count { splitter-id: splitter-id })))
)

