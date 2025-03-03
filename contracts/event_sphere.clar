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
(define-constant err-event-not-completed (err u109))
(define-constant err-revenue-already-distributed (err u110))

;; Contract Status
(define-data-var contract-paused bool false)
(define-data-var last-distribution-height uint u0)

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
        revenue-distributed: bool,
        status: (string-ascii 20)
    }
)

(define-map stakeholders
    principal
    {
        staked-amount: uint,
        last-claim-height: uint,
        lock-until: uint,
        pending-claims: uint
    }
)

(define-map revenue-claims
    { event-id: uint, claimer: principal }
    { claimed: bool }
)

;; Reentrancy Protection
(define-data-var executing-stake bool false)

;; Getter Functions
(define-read-only (get-event (event-id uint))
    (map-get? events event-id)
)

(define-read-only (get-stakeholder-info (stakeholder principal))
    (map-get? stakeholders stakeholder)
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
        (asserts! (not (var-get executing-stake)) err-unauthorized)
        (var-set executing-stake true)
        (let ((current-stake (default-to {staked-amount: u0, last-claim-height: u0, lock-until: u0, pending-claims: u0} 
                    (map-get? stakeholders tx-sender))))
            (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
            (map-set stakeholders tx-sender {
                staked-amount: (+ (get staked-amount current-stake) amount),
                last-claim-height: block-height,
                lock-until: (+ block-height u144),
                pending-claims: u0
            })
            (var-set executing-stake false)
            (ok true)
        )
    )
)

;; Enhanced Event Management
(define-public (complete-event (event-id uint))
    (let ((event (unwrap! (map-get? events event-id) err-not-found)))
        (asserts! (is-eq tx-sender (get organizer event)) err-unauthorized)
        (asserts! (>= block-height (get date event)) err-invalid-params)
        (asserts! (is-eq (get status event) "active") err-invalid-params)
        
        (map-set events event-id (merge event {
            status: "completed",
            revenue-distributed: false
        }))
        (ok true)
    )
)

(define-public (distribute-event-revenue (event-id uint))
    (let ((event (unwrap! (map-get? events event-id) err-not-found)))
        (asserts! (is-eq (get status event) "completed") err-event-not-completed)
        (asserts! (not (get revenue-distributed event)) err-revenue-already-distributed)
        
        ;; Calculate shares
        (let ((total-revenue (get total-revenue event))
              (shares (get revenue-share event)))
            
            ;; Transfer organizer share
            (try! (as-contract (stx-transfer? 
                (/ (* total-revenue (get organizer-share shares)) u100)
                tx-sender 
                (get organizer event)
            )))
            
            ;; Update event status
            (map-set events event-id (merge event {
                revenue-distributed: true
            }))
            (ok true)
        )
    )
)
