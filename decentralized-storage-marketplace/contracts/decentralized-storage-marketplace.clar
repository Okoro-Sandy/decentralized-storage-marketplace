
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
