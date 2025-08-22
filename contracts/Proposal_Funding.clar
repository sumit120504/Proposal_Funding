;; Proposal Funding Contract
;; Automatic funding system for approved proposals

;; Define the fungible token for funding
(define-fungible-token funding-token)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-proposal-not-found (err u101))
(define-constant err-proposal-not-approved (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-proposal-already-funded (err u105))

;; Data variables
(define-data-var total-pool uint u0)
(define-data-var next-proposal-id uint u1)

;; Proposal structure
(define-map proposals
  uint
  {
    proposer: principal,
    title: (string-ascii 64),
    funding-amount: uint,
    approved: bool,
    funded: bool
  }
)

;; Pool contributions tracking
(define-map contributions principal uint)

;; Submit and approve a proposal for funding
(define-public (submit-and-approve-proposal (title (string-ascii 64)) (funding-amount uint))
  (let
    ((proposal-id (var-get next-proposal-id)))
    (begin
      ;; Validate inputs
      (asserts! (> funding-amount u0) err-invalid-amount)
      (asserts! (> (len title) u0) err-invalid-amount)
      
      ;; Create and store the proposal
      (map-set proposals proposal-id
        {
          proposer: tx-sender,
          title: title,
          funding-amount: funding-amount,
          approved: true,  ;; Auto-approve for this simplified version
          funded: false
        })
      
      ;; Increment proposal counter
      (var-set next-proposal-id (+ proposal-id u1))
      
      ;; Return proposal ID
      (ok proposal-id))))

;; Execute automatic funding for an approved proposal
(define-public (execute-funding (proposal-id uint))
  (let
    ((proposal-data (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
     (funding-amount (get funding-amount proposal-data))
     (proposer (get proposer proposal-data)))
    (begin
      ;; Check if proposal is approved
      (asserts! (get approved proposal-data) err-proposal-not-approved)
      
      ;; Check if proposal hasn't been funded yet
      (asserts! (not (get funded proposal-data)) err-proposal-already-funded)
      
      ;; Check if pool has sufficient funds
      (asserts! (>= (var-get total-pool) funding-amount) err-insufficient-funds)
      
      ;; Transfer funding tokens to proposer
      (try! (ft-mint? funding-token funding-amount proposer))
      
      ;; Update proposal status to funded
      (map-set proposals proposal-id
        (merge proposal-data { funded: true }))
      
      ;; Reduce total pool
      (var-set total-pool (- (var-get total-pool) funding-amount))
      
      ;; Return success with funding details
      (ok { 
        proposal-id: proposal-id, 
        funded-amount: funding-amount, 
        recipient: proposer 
      }))))

;; Read-only functions for querying

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id))

;; Get total funding pool
(define-read-only (get-total-pool)
  (ok (var-get total-pool)))

;; Get next proposal ID
(define-read-only (get-next-proposal-id)
  (ok (var-get next-proposal-id)))

;; Helper function to add funds to the pool (for testing/demo purposes)
(define-public (add-to-pool (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (var-set total-pool (+ (var-get total-pool) amount))
    (ok (var-get total-pool))))