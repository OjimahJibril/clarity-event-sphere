;; EventSphere DAO Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-sold-out (err u104))

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
        organizer: principal
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

;; Public Functions

;; Create Event
(define-public (create-event (name (string-ascii 100)) 
                           (description (string-utf8 500))
                           (date uint)
                           (max-tickets uint)
                           (ticket-price uint))
    (let ((event-id (var-get next-event-id)))
        (map-insert events event-id {
            name: name,
            description: description,
            date: date,
            max-tickets: max-tickets,
            tickets-sold: u0,
            ticket-price: ticket-price,
            organizer: tx-sender
        })
        (var-set next-event-id (+ event-id u1))
        (ok event-id)
    )
)

;; Buy Ticket
(define-public (buy-ticket (event-id uint))
    (let (
        (event (unwrap! (map-get? events event-id) err-not-found))
        (ticket-id (var-get next-ticket-id))
    )
        (asserts! (< (get tickets-sold event) (get max-tickets event)) err-sold-out)
        (try! (stx-transfer? (get ticket-price event) tx-sender (get organizer event)))
        (try! (nft-mint? event-ticket ticket-id tx-sender))
        (map-insert tickets ticket-id {
            event-id: event-id,
            owner: tx-sender,
            status: "valid"
        })
        (map-set events event-id (merge event {tickets-sold: (+ (get tickets-sold event) u1)}))
        (var-set next-ticket-id (+ ticket-id u1))
        (ok ticket-id)
    )
)

;; Create Proposal
(define-public (create-proposal (title (string-ascii 100))
                              (description (string-utf8 500))
                              (event-id uint)
                              (deadline uint))
    (let (
        (proposal-id (var-get next-proposal-id))
        (event (unwrap! (map-get? events event-id) err-not-found))
    )
        (asserts! (is-eq tx-sender (get organizer event)) err-unauthorized)
        (map-insert proposals proposal-id {
            title: title,
            description: description,
            event-id: event-id,
            deadline: deadline,
            yes-votes: u0,
            no-votes: u0,
            status: "active"
        })
        (var-set next-proposal-id (+ proposal-id u1))
        (ok proposal-id)
    )
)

;; Vote on Proposal
(define-public (vote-on-proposal (proposal-id uint) (vote bool))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) err-not-found))
        (has-voted (map-get? votes {proposal-id: proposal-id, voter: tx-sender}))
    )
        (asserts! (not has-voted) err-unauthorized)
        (asserts! (is-eq (get status proposal) "active") err-unauthorized)
        (asserts! (< block-height (get deadline proposal)) err-unauthorized)
        
        (map-set votes {proposal-id: proposal-id, voter: tx-sender} true)
        (if vote
            (map-set proposals proposal-id (merge proposal {yes-votes: (+ (get yes-votes proposal) u1)}))
            (map-set proposals proposal-id (merge proposal {no-votes: (+ (get no-votes proposal) u1)}))
        )
        (ok true)
    )
)

;; Read-only functions

(define-read-only (get-event (event-id uint))
    (map-get? events event-id)
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-ticket (ticket-id uint))
    (map-get? tickets ticket-id)
)