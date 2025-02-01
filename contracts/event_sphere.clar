;; EventSphere DAO Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101)) 
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-sold-out (err u104))
(define-constant err-already-claimed (err u105))

;; Define NFT for tickets
(define-non-fungible-token event-ticket uint)

;; Data Variables
(define-data-var next-event-id uint u0)
(define-data-var next-ticket-id uint u0)
(define-data-var next-proposal-id uint u0)

;; Data Maps
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
        claimed-revenue: bool
    }
)

(define-map proposals
    uint 
    {
        title: (string-ascii 100),
        description: (string-utf8 500),
        event-id: uint,
        deadline: uint,
        yes-votes: uint,
        no-votes: uint,
        status: (string-ascii 20)
    }
)

(define-map votes
    {proposal-id: uint, voter: principal}
    bool
)

(define-map tickets
    uint
    {
        event-id: uint,
        owner: principal,
        status: (string-ascii 20)
    }
)

(define-map stakeholders
    principal
    {
        staked-amount: uint,
        last-claim-height: uint
    }
)

;; Public Functions

;; Create Event with Revenue Sharing
(define-public (create-event (name (string-ascii 100)) 
                         (description (string-utf8 500))
                         (date uint)
                         (max-tickets uint)
                         (ticket-price uint)
                         (organizer-share uint)
                         (dao-share uint)
                         (stakeholder-share uint))
    (let ((event-id (var-get next-event-id)))
        (asserts! (is-eq (+ (+ organizer-share dao-share) stakeholder-share) u100) err-invalid-params)
        (map-insert events event-id {
            name: name,
            description: description,
            date: date,
            max-tickets: max-tickets,
            tickets-sold: u0,
            ticket-price: ticket-price,
            organizer: tx-sender,
            revenue-share: {
                organizer-share: organizer-share,
                dao-share: dao-share,
                stakeholder-share: stakeholder-share
            },
            total-revenue: u0,
            claimed-revenue: false
        })
        (var-set next-event-id (+ event-id u1))
        (ok event-id)
    )
)

;; Stake STX to become stakeholder
(define-public (stake-stx (amount uint))
    (let ((current-stake (default-to {staked-amount: u0, last-claim-height: u0} 
                        (map-get? stakeholders tx-sender))))
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set stakeholders tx-sender {
            staked-amount: (+ (get staked-amount current-stake) amount),
            last-claim-height: block-height
        })
        (ok true)
    )
)

;; Claim Revenue Share
(define-public (claim-revenue-share (event-id uint))
    (let (
        (event (unwrap! (map-get? events event-id) err-not-found))
        (stakeholder-info (unwrap! (map-get? stakeholders tx-sender) err-unauthorized))
    )
        (asserts! (>= block-height (get date event)) err-unauthorized)
        (asserts! (not (get claimed-revenue event)) err-already-claimed)
        
        (let (
            (total-revenue (get total-revenue event))
            (shares (get revenue-share event))
            (organizer-amount (* total-revenue (get organizer-share shares)))
            (dao-amount (* total-revenue (get dao-share shares)))
            (stakeholder-amount (* total-revenue (get stakeholder-share shares)))
        )
            ;; Transfer shares
            (try! (as-contract (stx-transfer? organizer-amount tx-sender (get organizer event))))
            (try! (as-contract (stx-transfer? stakeholder-amount tx-sender tx-sender)))
            
            ;; Update event status
            (map-set events event-id (merge event {claimed-revenue: true}))
            (ok true)
        )
    )
)

;; Buy Ticket
(define-public (buy-ticket (event-id uint))
    (let (
        (event (unwrap! (map-get? events event-id) err-not-found))
        (ticket-id (var-get next-ticket-id))
    )
        (asserts! (< (get tickets-sold event) (get max-tickets event)) err-sold-out)
        (try! (stx-transfer? (get ticket-price event) tx-sender (as-contract tx-sender)))
        (try! (nft-mint? event-ticket ticket-id tx-sender))
        (map-insert tickets ticket-id {
            event-id: event-id,
            owner: tx-sender,
            status: "valid"
        })
        (map-set events event-id (merge event {
            tickets-sold: (+ (get tickets-sold event) u1),
            total-revenue: (+ (get total-revenue event) (get ticket-price event))
        }))
        (var-set next-ticket-id (+ ticket-id u1))
        (ok ticket-id)
    )
)

;; [Rest of existing functions remain unchanged]
