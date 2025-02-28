;; EventSphere DAO Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101)) 
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-sold-out (err u104))
(define-constant err-already-claimed (err u105))
(define-constant err-contract-paused (err u106))
(define-constant err-timelock-active (err u107))
(define-constant err-insufficient-stake (err u108))

;; Contract Status
(define-data-var contract-paused bool false)

;; Define NFT for tickets
(define-non-fungible-token event-ticket uint)

;; Data Variables
(define-data-var next-event-id uint u0)
(define-data-var next-ticket-id uint u0)
(define-data-var next-proposal-id uint u0)

;; Enhanced Data Maps
(define-map events 
    uint 
    {
        name: (string-ascii 100),
        description: (string-utf8 500),
        date: uint,
        max-tickets: uint,
        tickets-sold: uint,
        ticket-price: uint,
        organizer: principal,
        revenue-share: {
          organizer-share: uint,
          dao-share: uint,
          stakeholder-share: uint
        },
        total-revenue: uint,
        claimed-revenue: bool,
        status: (string-ascii 20)
    }
)

(define-map stakeholders
    principal
    {
        staked-amount: uint,
        last-claim-height: uint,
        lock-until: uint
    }
)

;; Admin Functions
(define-public (toggle-contract-pause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set contract-paused (not (var-get contract-paused))))
    )
)

;; Enhanced Stake Management
(define-public (stake-stx (amount uint))
    (begin
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (let ((current-stake (default-to {staked-amount: u0, last-claim-height: u0, lock-until: u0} 
                        (map-get? stakeholders tx-sender))))
            (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
            (map-set stakeholders tx-sender {
                staked-amount: (+ (get staked-amount current-stake) amount),
                last-claim-height: block-height,
                lock-until: (+ block-height u144) ;; 24-hour timelock
            })
            (ok true)
        )
    )
)

(define-public (withdraw-stake (amount uint))
    (let ((stake-info (unwrap! (map-get? stakeholders tx-sender) err-not-found)))
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (>= block-height (get lock-until stake-info)) err-timelock-active)
        (asserts! (>= (get staked-amount stake-info) amount) err-insufficient-stake)
        
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-set stakeholders tx-sender 
            (merge stake-info {staked-amount: (- (get staked-amount stake-info) amount)}))
        (ok true)
    )
)

;; Enhanced Event Management
(define-public (cancel-event (event-id uint))
    (let ((event (unwrap! (map-get? events event-id) err-not-found)))
        (asserts! (is-eq tx-sender (get organizer event)) err-unauthorized)
        (asserts! (< block-height (get date event)) err-unauthorized)
        
        (map-set events event-id (merge event {status: "cancelled"}))
        (ok true)
    )
)

;; [Previous functions remain unchanged]
