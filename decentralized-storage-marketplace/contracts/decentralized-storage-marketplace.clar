
;; title: decentralized-storage-marketplace

;; This contract enables users to rent decentralized storage with secure payments,
;; dispute resolution, and reputation management

;; Define the contract owner
(define-constant contract-owner 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Define error codes
(define-constant err-owner-only (err u100))
(define-constant err-not-listed (err u101))
(define-constant err-already-listed (err u102))
(define-constant err-insufficient-payment (err u103))
(define-constant err-not-renter (err u104))
(define-constant err-already-rented (err u105))
(define-constant err-invalid-duration (err u106))
(define-constant err-not-expired (err u107))
(define-constant err-already-resolved (err u108))
(define-constant err-invalid-rating (err u109))
(define-constant err-unauthorized (err u110))
(define-constant err-unauthorized-token (err u111))
(define-constant err-fee-too-high (err u112))
(define-constant err-rate-limit-exceeded (err u113))
(define-constant err-not-rentable (err u114))
(define-constant err-cannot-cancel (err u115))
(define-constant err-no-extension (err u116))
(define-constant err-already-reviewed (err u117))
(define-constant err-invalid-location (err u118))

;; Define contract variables
(define-data-var platform-fee uint u50) ;; 5.0% (stored as 50 = 5.0%)
(define-data-var platform-fee-recipient principal contract-owner)
(define-data-var contract-enabled bool true)
(define-data-var total-listings uint u0)
(define-data-var total-payments uint u0)
(define-data-var total-disputes uint u0)

(define-map user-stats
  { user: principal }
  { total-rentals: uint, 
    total-listings: uint, 
    avg-rating: uint,
    rating-count: uint,
    last-activity: uint
  }
)

;; Contract control functions
(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-fee-too-high) ;; Max 100% (1000 = 100.0%)
    (var-set platform-fee new-fee)
    (ok new-fee)))

(define-public (set-fee-recipient (new-recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set platform-fee-recipient new-recipient)
    (ok true)))

(define-public (toggle-contract-enabled)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-enabled (not (var-get contract-enabled)))
    (ok (var-get contract-enabled))))

;; Update a user's average rating
(define-private (update-user-rating (user principal) (new-rating uint))
  (match (map-get? user-stats { user: user })
    existing-stats 
      (let (
        (current-avg (get avg-rating existing-stats))
        (current-count (get rating-count existing-stats))
        (new-count (+ current-count u1))
        (new-avg (if (is-eq current-count u0)
                   new-rating
                   (/ (+ (* current-avg current-count) new-rating) new-count)))
      )
        (map-set user-stats 
          { user: user }
          (merge existing-stats { 
            avg-rating: new-avg,
            rating-count: new-count,
            last-activity: stacks-block-height
          })))
    false))

(define-private (is-listing-available (listing {
    id: uint, 
    owner: principal, 
    price: uint, 
    size: uint, 
    duration: uint, 
    rented: bool, 
    renter: (optional principal), 
    start-time: (optional uint), 
    end-time: (optional uint),
    proof: (optional (string-utf8 256)), 
    rating: (optional uint),
    location: (string-utf8 64),
    availability: bool,
    description: (string-utf8 256),
    cancel-period: uint
  }))
  (and (not (get rented listing)) (get availability listing)))

(define-private (is-review-for-listing (listing-id uint) (review {
    id: uint,
    listing-id: uint,
    reviewer: principal,
    rating: uint,
    comment: (string-utf8 256),
    timestamp: uint
  }))
  (is-eq (get listing-id review) listing-id))

  ;; Get user statistics
(define-read-only (get-user-stats (user principal))
  (default-to 
    { 
      total-rentals: u0,
      total-listings: u0,
      avg-rating: u0,
      rating-count: u0,
      last-activity: u0
    }
    (map-get? user-stats { user: user })))

;; Get contract status and metrics
(define-read-only (get-contract-status)
  {
    enabled: (var-get contract-enabled),
    fee-percentage: (/ (var-get platform-fee) u10),
    fee-recipient: (var-get platform-fee-recipient),
    total-listings: (var-get total-listings),
    total-payments: (var-get total-payments),
    total-disputes: (var-get total-disputes)
  })


  ;; Storage Listing Data Structure
(define-map storage-listings
  { id: uint }
  { 
    owner: principal, 
    price: uint, 
    size: uint, 
    duration: uint, 
    rented: bool, 
    renter: (optional principal), 
    start-time: (optional uint), 
    end-time: (optional uint),
    proof: (optional (string-utf8 256)), 
    rating: (optional uint),
    location: (string-utf8 64),
    availability: bool,
    description: (string-utf8 256),
    cancel-period: uint,
    created-at: uint,
    encryption-supported: bool,
    bandwidth-limit: uint,
    storage-type: (string-utf8 32)
  }
)

;; Reviews Data Structure
(define-map reviews
  { id: uint }
  {
    listing-id: uint,
    reviewer: principal,
    rating: uint,
    comment: (string-utf8 256),
    timestamp: uint,
    response: (optional (string-utf8 256)),
    response-timestamp: (optional uint)
  }
)

;; Dispute Resolution System
(define-map disputes
  { id: uint }
  {
    listing-id: uint,
    initiator: principal,
    respondent: principal,
    status: (string-utf8 32), ;; "pending", "resolved", "canceled"
    reason: (string-utf8 256),
    evidence: (optional (string-utf8 512)),
    resolution: (optional (string-utf8 256)),
    mediator: (optional principal),
    created-at: uint,
    resolved-at: (optional uint)
  }
)

;; 6. Cancel Listing Function
(define-public (cancel-listing (listing-id uint))
  (let
    ((listing (unwrap! (map-get? storage-listings { id: listing-id }) err-not-listed)))
    
    (asserts! (var-get contract-enabled) err-unauthorized)
    (asserts! (is-eq tx-sender (get owner listing)) err-unauthorized)
    (asserts! (not (get rented listing)) err-cannot-cancel)
    
    (map-set storage-listings
      { id: listing-id }
      (merge listing {
        availability: false
      }))
    (ok true)))

;; 10. Respond to Review Function
(define-public (respond-to-review (review-id uint) (response (string-utf8 256)))
  (let
    ((review (unwrap! (map-get? reviews { id: review-id }) err-not-listed))
     (listing (unwrap! (map-get? storage-listings { id: (get listing-id review) }) err-not-listed)))
    
    (asserts! (var-get contract-enabled) err-unauthorized)
    (asserts! (is-eq tx-sender (get owner listing)) err-unauthorized)
    (asserts! (is-none (get response review)) err-already-reviewed)
    
    (map-set reviews
      { id: review-id }
      (merge review {
        response: (some response),
        response-timestamp: (some stacks-block-height)
      }))
    
    (ok true)))

;; Referral System
(define-map referrals
  { referrer: principal, referee: principal }
  { 
    active: bool,
    reward-claimed: bool,
    created-at: uint
  }
)

;; 18. Emergency Shutdown Function
(define-public (emergency-shutdown)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-enabled false)
    (ok true)))


;; 19. Reinitialize Contract Function
(define-public (reinitialize-contract (new-fee uint) (new-fee-recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-fee-too-high)
    
    (var-set platform-fee new-fee)
    (var-set platform-fee-recipient new-fee-recipient)
    (var-set contract-enabled true)
    
    (ok true)))

;; 21. Pricing Models
(define-map pricing-tiers
  { owner: principal, tier: uint }
  { 
    name: (string-utf8 32),
    base-price: uint,
    size-multiplier: uint,
    duration-multiplier: uint,
    min-duration: uint,
    max-duration: uint,
    encryption-fee: uint,
    bandwidth-fee: uint,
    active: bool
  }
)

(define-public (create-pricing-tier 
    (tier uint)
    (name (string-utf8 32))
    (base-price uint)
    (size-multiplier uint)
    (duration-multiplier uint)
    (min-duration uint)
    (max-duration uint)
    (encryption-fee uint)
    (bandwidth-fee uint))
  (begin
    (asserts! (var-get contract-enabled) err-unauthorized)
    
    (map-set pricing-tiers
      { owner: tx-sender, tier: tier }
      { 
        name: name,
        base-price: base-price,
        size-multiplier: size-multiplier,
        duration-multiplier: duration-multiplier,
        min-duration: min-duration,
        max-duration: max-duration,
        encryption-fee: encryption-fee,
        bandwidth-fee: bandwidth-fee,
        active: true
      })
    (ok true)))